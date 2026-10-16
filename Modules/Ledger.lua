local addonName, GuildUtils = ...
GuildUtils.Ledger = {}
GuildUtils.Ledger.Rows = {}

-- ============================================================================
-- THE TAINT-FREE OFFICER ADJUSTMENT MODAL
-- ============================================================================
function GuildUtils.Ledger:ShowOfficerAdjustmentModal(memberName, memberGuid, actionType)
    if not self.Modal then
        self.Modal = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsLCModal", UIParent, 340, 200)
        self.Modal:SetPoint("CENTER")
        self.Modal:SetFrameStrata("DIALOG")
        
        self.Modal.title = self.Modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        self.Modal.title:SetPoint("TOP", 0, -15)
        
        self.Modal.input = CreateFrame("EditBox", nil, self.Modal, "InputBoxTemplate")
        self.Modal.input:SetSize(140, 30)
        self.Modal.input:SetPoint("CENTER", 0, 10)
        self.Modal.input:SetAutoFocus(true)
        self.Modal.input:SetNumeric(true)
        self.Modal.input:SetScript("OnEscapePressed", function(selfEb) selfEb:ClearFocus(); GuildUtils.Ledger.Modal:Hide() end)
        
        self.Modal.confirmBtn = CreateFrame("Button", nil, self.Modal, "UIPanelButtonTemplate")
        self.Modal.confirmBtn:SetSize(120, 26)
        self.Modal.confirmBtn:SetPoint("BOTTOM", 0, 20)
        
        GuildUtils.UI:ApplyTheme()
    end
    
    local m = self.Modal
    m.title:SetText(string.format("%s LC for %s", actionType, memberName))
    m.input:SetText("")
    m.input:SetFocus()
    m.confirmBtn:SetText("Confirm " .. actionType)
    
    m.confirmBtn:SetScript("OnClick", function()
        local amount = tonumber(m.input:GetText())
        if amount and amount > 0 then
            local actualAmount = actionType == "Add" and amount or -amount
            if GuildUtils.LootCoin then 
                GuildUtils.LootCoin:ProcessTransaction(memberGuid, memberName, actualAmount, "Manual Officer Adjustment") 
            end
            m:Hide()
        else
            GuildUtils:Print("Invalid LC amount entered.", true)
        end
    end)
    
    m:Show()
end

-- ============================================================================
-- MAIN LEDGER UI TOGGLE & INITIALIZATION
-- ============================================================================
function GuildUtils.Ledger:Toggle()
    if not self.Frame then
        local currentFont = (GU_CharDB and GU_CharDB.LedgerFontSize) or 12
        local sizeDiff = currentFont - 12
        local dynamicWidth = 260 + math.max(0, sizeDiff * 25)
        
        -- USING THE CUSTOM TAINT-FREE LIBRARY
        self.Frame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsLedgerFrame", UIParent, dynamicWidth, 460)
        self.Frame:Hide()
        self.Frame:SetPoint("CENTER")
        
        local f = self.Frame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -12)
        f.title:SetText("GuildUtils: Ledger")

        f.currentView = "BALANCES"
        
        f.tabBalances = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.tabBalances:SetSize(75, 22)
        f.tabBalances:SetPoint("TOPLEFT", 10, -35)
        f.tabBalances:SetText("Balances")
        f.tabBalances:SetScript("OnClick", function()
            f.currentView = "BALANCES"; f.searchBox:Show(); GuildUtils.Ledger:UpdateDisplay(f.searchBox:GetText())
        end)
        
        f.tabAudit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.tabAudit:SetSize(75, 22)
        f.tabAudit:SetPoint("LEFT", f.tabBalances, "RIGHT", 4, 0)
        f.tabAudit:SetText("Audit")
        f.tabAudit:SetScript("OnClick", function()
            f.currentView = "AUDIT"; f.searchBox:Hide(); GuildUtils.Ledger:UpdateDisplay()
        end)

        f.searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.searchBox:SetSize(180 + math.max(0, sizeDiff * 20), 20)
        f.searchBox:SetPoint("TOPLEFT", 15, -62)
        f.searchBox:SetAutoFocus(false)
        f.searchBox:SetScript("OnTextChanged", function(selfEb) GuildUtils.Ledger:UpdateDisplay(selfEb:GetText()) end)

        f.searchPlaceholder = f.searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        f.searchPlaceholder:SetPoint("LEFT", f.searchBox, "LEFT", 4, 0)
        f.searchPlaceholder:SetText("Search player...")
        f.searchBox:SetScript("OnEditFocusGained", function() f.searchPlaceholder:Hide() end)
        f.searchBox:SetScript("OnEditFocusLost", function(selfEb) if selfEb:GetText() == "" then f.searchPlaceholder:Show() end end)

        f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.scrollFrame:SetPoint("TOPLEFT", 10, -90)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 15)
        
        f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
        f.scrollChild:SetSize(210 + math.max(0, sizeDiff * 25), 1)
        f.scrollFrame:SetScrollChild(f.scrollChild)

        f.hostLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.hostLabel:SetPoint("BOTTOMLEFT", 12, 12)
        f.hostLabel:SetText("Host: None")
    end

    if self.Frame:IsShown() then self.Frame:Hide() else self.Frame:Show(); self:UpdateDisplay() end
end

-- ============================================================================
-- DYNAMIC SCALING & RENDER ENGINE
-- ============================================================================
function GuildUtils.Ledger:UpdateDisplay(searchQuery)
    if not self.Frame or not self.Frame:IsShown() then return end
    
    local hostName = GuildUtils.Host or "None"
    if GuildUtils.SoloMode then hostName = UnitName("player") .. " (Solo)" end
    self.Frame.hostLabel:SetText("Host: " .. hostName)
    
    local scrollChild = self.Frame.scrollChild
    for _, row in ipairs(self.Rows) do row:Hide() end
    if self.AuditBox then self.AuditBox:Hide() end
    
    searchQuery = searchQuery and searchQuery:lower() or ""
    local themeIdx = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = GuildUtils.Styles[themeIdx] or GuildUtils.Styles[1]
    
    local fontSize = GU_CharDB.LedgerFontSize or 12
    local rowHeight = fontSize + 14
    local sizeDiff = fontSize - 12
    
    local dynamicWidth = 260 + math.max(0, sizeDiff * 25)
    local dynamicRowWidth = 210 + math.max(0, sizeDiff * 25)
    
    self.Frame:SetWidth(dynamicWidth)
    self.Frame.searchBox:SetWidth(180 + math.max(0, sizeDiff * 20))
    scrollChild:SetWidth(dynamicRowWidth)
    
    self.Frame.title:SetTextColor(unpack(style.titleColor))
    self.Frame.hostLabel:SetTextColor(unpack(style.nameColor))
    
    if self.Frame.currentView == "BALANCES" then
        if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.balances then return end
        
        local sortedList = {}
        for guid, bal in pairs(GU_GlobalDB.Ledger.balances) do
            local name = GU_GlobalDB.Ledger.roster[guid] or "Unknown"
            table.insert(sortedList, {guid = guid, name = name, balance = bal})
        end
        
        table.sort(sortedList, function(a, b)
            if a.balance ~= b.balance then return a.balance > b.balance end
            return a.name < b.name
        end)
        
        local rowIndex, yOffset = 1, -5
        for _, data in ipairs(sortedList) do
            if searchQuery == "" or data.name:lower():find(searchQuery) then
                local row = self.Rows[rowIndex]
                if not row then
                    row = CreateFrame("Frame", nil, scrollChild)
                    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.nameText:SetPoint("LEFT", 2, 0)
                    row.nameText:SetJustifyH("LEFT")
                    
                    row.balText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.balText:SetPoint("RIGHT", -5, 0) 
                    
                    row:EnableMouse(true)
                    row:SetScript("OnMouseDown", function(selfRow, button)
                        if button == "RightButton" and GuildUtils:IsAuthoritativeHost() then
                            MenuUtil.CreateContextMenu(selfRow, function(owner, rootDescription)
                                rootDescription:CreateTitle(data.name)
                                rootDescription:CreateButton("Add LC", function() GuildUtils.Ledger:ShowOfficerAdjustmentModal(data.name, data.guid, "Add") end)
                                rootDescription:CreateButton("Subtract LC", function() GuildUtils.Ledger:ShowOfficerAdjustmentModal(data.name, data.guid, "Subtract") end)
                                local isFrozen = GU_GlobalDB.Ledger.frozenAccounts and GU_GlobalDB.Ledger.frozenAccounts[data.guid] == "F"
                                rootDescription:CreateButton(isFrozen and "Unfreeze Account" or "Freeze Account", function()
                                    local tState = isFrozen and "0" or "1"
                                    GuildUtils.LootCoin:ToggleManagementFreeze(data.guid, data.name, false, tState)
                                end)
                            end)
                        end
                    end)
                    self.Rows[rowIndex] = row
                end
                
                row:SetSize(dynamicRowWidth, rowHeight)
                row.nameText:SetWidth(120 + math.max(0, sizeDiff * 10))
                
                local fontPath1, _, flags1 = row.nameText:GetFont()
                if fontPath1 then row.nameText:SetFont(fontPath1, fontSize, flags1) end
                
                local fontPath2, _, flags2 = row.balText:GetFont()
                if fontPath2 then row.balText:SetFont(fontPath2, fontSize, flags2) end
                
                row:SetPoint("TOPLEFT", 0, yOffset)
                local isFrozen = GU_GlobalDB.Ledger.frozenAccounts and GU_GlobalDB.Ledger.frozenAccounts[data.guid]
                local tagString = ""
                local cTags = GuildUtils.Constants and GuildUtils.Constants.StatusTags
                
                if isFrozen then
                    local fColor = "FFFF00"
                    if isFrozen == "F" then fColor = cTags and cTags.Freeze.defaultColor or "00BFFF"
                    elseif isFrozen == "GL" then fColor = cTags and cTags.GroupLeader.defaultColor or "FF8C00"
                    elseif isFrozen == "G" then fColor = cTags and cTags.InGroup.defaultColor or "FF8C00"
                    elseif isFrozen == "T" then fColor = cTags and cTags.Tampered.defaultColor or "FF4500" end
                    tagString = "|cFF" .. fColor .. "[" .. tostring(isFrozen) .. "]|r "
                end
                
                row.nameText:SetText(tagString .. data.name)
                row.nameText:SetTextColor(unpack(style.nameColor))
                
                local totalBal = data.balance
                local heldBal = 0
                local committedBal = 0
                
                if GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members[data.guid] then
                    heldBal = math.abs(GU_GlobalDB.Ledger.ActiveSession.members[data.guid].change or 0)
                end
                
                if GU_GlobalDB.Contracts and GU_GlobalDB.Contracts.list then
                    for _, contract in ipairs(GU_GlobalDB.Contracts.list) do
                        if not contract.completed and contract.creatorGuid == data.guid then
                            committedBal = committedBal + (contract.reward or 0)
                        end
                    end
                end
                
                local liquidBal = totalBal - heldBal - committedBal
                row.balText:SetText(string.format("%d (C:%d/H:%d/L:%d)", totalBal, committedBal, heldBal, liquidBal))
                row.balText:SetTextColor(unpack(style.balColor))
                
                row:Show()
                yOffset = yOffset - rowHeight
                rowIndex = rowIndex + 1
            end
        end
        scrollChild:SetHeight(math.abs(yOffset))
        
    elseif self.Frame.currentView == "AUDIT" then
        if not self.AuditBox then
            self.AuditBox = CreateFrame("EditBox", nil, scrollChild)
            self.AuditBox:SetMultiLine(true)
            self.AuditBox:SetFontObject("GameFontHighlight")
            self.AuditBox:SetWidth(dynamicRowWidth - 10)
            self.AuditBox:SetAutoFocus(false)
            self.AuditBox:SetScript("OnEscapePressed", function(selfEb) selfEb:ClearFocus() end)
            self.AuditBox:SetScript("OnEditFocusGained", function(selfEb) selfEb:HighlightText() end)
        else
            self.AuditBox:SetWidth(dynamicRowWidth - 10)
        end
        
        local aFontPath, _, aFlags = self.AuditBox:GetFont()
        if aFontPath then self.AuditBox:SetFont(aFontPath, fontSize, aFlags) end
        
        self.AuditBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -2)
        
        local fullLog = ""
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.auditLog then
            for i = #GU_GlobalDB.Ledger.auditLog, 1, -1 do
                fullLog = fullLog .. tostring(GU_GlobalDB.Ledger.auditLog[i]) .. "\n"
            end
        end
        self.AuditBox:SetText(fullLog)
        self.AuditBox:SetTextColor(unpack(style.nameColor))
        self.AuditBox:Show()
        scrollChild:SetHeight(math.max(300, self.AuditBox:GetHeight() + 20))
    end
end