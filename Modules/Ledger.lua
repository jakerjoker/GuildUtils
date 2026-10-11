local addonName, GuildUtils = ...
GuildUtils.Ledger = {}
GuildUtils.Ledger.Rows = {}

StaticPopupDialogs["GUILDUTILS_LC_MODAL"] = {
    text = "%s LC for %s:",
    button1 = "Confirm", button2 = "Cancel",
    hasEditBox = true, maxLetters = 6,
    OnAccept = function(selfPopup, data)
        local amt = tonumber(selfPopup.EditBox:GetText())
        if amt and GuildUtils.LootCoin then
            local finalAmt = data.action == "Add" and math.abs(amt) or -math.abs(amt)
            GuildUtils.LootCoin:ProcessTransaction(data.guid, data.name, finalAmt, "Manual " .. data.action)
        end
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText(""); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_LINK_ALT_MODAL"] = {
    text = "Link %s as Alt to Main Character Name:",
    button1 = "Link Alt", button2 = "Cancel",
    hasEditBox = true, maxLetters = 16,
    OnAccept = function(selfPopup, data)
        local mainName = GuildUtils:FormatName(selfPopup.EditBox:GetText())
        if mainName and GuildUtils.LootCoin then
            local mainGuid = nil
            for g, n in pairs(GU_GlobalDB.Ledger.roster) do
                if n:lower() == mainName:lower() then mainGuid = g; break end
            end
            if mainGuid then
                GuildUtils.LootCoin:LinkAlt(data.guid, data.name, mainGuid, mainName)
            else
                GuildUtils:Print("Could not find Main character '" .. mainName .. "' in guild roster.", true)
            end
        end
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText(""); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function GuildUtils.Ledger:Toggle()
    if not self.Frame then
        self.Frame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsLedgerFrame", UIParent, 280, 460)
        self.Frame:Hide()
        self.Frame:SetPoint("CENTER")
        
        local f = self.Frame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.title:SetPoint("TOP", 0, -10)
        f.title:SetText("GuildUtils: Ledger")

        f.syncIndicator = f:CreateTexture(nil, "OVERLAY")
        f.syncIndicator:SetSize(12, 12)
        f.syncIndicator:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
        f.syncIndicator:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        f.syncIndicator:SetVertexColor(1, 0, 0, 1)

        -- Search Bar
        f.searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.searchBox:SetSize(220, 20)
        f.searchBox:SetPoint("TOP", 0, -30)
        f.searchBox:SetAutoFocus(false)
        f.searchBox:SetText("")
        f.searchBox:SetScript("OnTextChanged", function(eb)
            GuildUtils.Ledger:UpdateDisplay(eb:GetText())
        end)
        f.searchBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

        f.hostLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.hostLabel:SetPoint("BOTTOMLEFT", 12, 40)
        f.hostLabel:SetText("Host: None")

        f.scrollFrame = CreateFrame("ScrollFrame", nil, f)
        f.scrollFrame:SetPoint("TOPLEFT", 10, -60)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 65)
        
        f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
        f.scrollChild:SetSize(230, 1)
        f.scrollFrame:SetScrollChild(f.scrollChild)
        
        -- Dashboard Navigation Buttons
        local div = f:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.3, 0.3, 0.3, 1)
        div:SetSize(260, 1)
        div:SetPoint("BOTTOM", 0, 35)

        f.btnLoot = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnLoot:SetSize(60, 22)
        f.btnLoot:SetPoint("BOTTOMLEFT", 10, 8)
        f.btnLoot:SetText("G&L")
        f.btnLoot:SetScript("OnClick", function() if GuildUtils.PartyRoller then GuildUtils.PartyRoller:Toggle() end end)

        f.btnBounty = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnBounty:SetSize(60, 22)
        f.btnBounty:SetPoint("LEFT", f.btnLoot, "RIGHT", 5, 0)
        f.btnBounty:SetText("Bounty")
        f.btnBounty:SetScript("OnClick", function() if GuildUtils.Contracts then GuildUtils.Contracts:Toggle() end end)

        f.btnLog = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnLog:SetSize(60, 22)
        f.btnLog:SetPoint("LEFT", f.btnBounty, "RIGHT", 5, 0)
        f.btnLog:SetText("Audit")
        f.btnLog:SetScript("OnClick", function() GuildUtils.Ledger:ToggleAuditLog() end)

        f.btnConfig = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnConfig:SetSize(60, 22)
        f.btnConfig:SetPoint("LEFT", f.btnLog, "RIGHT", 5, 0)
        f.btnConfig:SetText("Config")
        f.btnConfig:SetScript("OnClick", function() if GuildUtils.SettingsUI then GuildUtils.SettingsUI:TogglePanel() end end)
    end

    if self.Frame:IsShown() then self.Frame:Hide() else self.Frame:Show(); self:UpdateDisplay() end
end

function GuildUtils.Ledger:ToggleAuditLog()
    if not self.LogFrame then
        self.LogFrame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsAuditLogFrame", UIParent, 450, 400)
        self.LogFrame:Hide()
        self.LogFrame:SetPoint("CENTER", 100, 50)
        
        local f = self.LogFrame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -12)
        f.title:SetText("GuildUtils: Central Bank Audit Log")

        f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.scrollFrame:SetPoint("TOPLEFT", 15, -40)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 15)

        f.text = CreateFrame("EditBox", nil, f.scrollFrame)
        f.text:SetMultiLine(true)
        f.text:SetSize(400, 340)
        f.text:SetFontObject("GameFontHighlightSmall")
        f.text:SetAutoFocus(false)
        f.text:EnableMouse(true)
        f.scrollFrame:SetScrollChild(f.text)
    end

    if self.LogFrame:IsShown() then
        self.LogFrame:Hide()
    else
        self.LogFrame:Show()
        local logEntries = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.auditLog) or {}
        local fullLog = ""
        for i = #logEntries, math.max(1, #logEntries - 100), -1 do
            fullLog = fullLog .. logEntries[i] .. "\n"
        end
        self.LogFrame.text:SetText(fullLog ~= "" and fullLog or "No recorded bank transactions.")
    end
end

function GuildUtils.Ledger:UpdateSyncIndicator(state)
    if not self.Frame then return end
    if state == "SYNCED" then self.Frame.syncIndicator:SetVertexColor(0, 1, 0, 1)
    elseif state == "PENDING" then self.Frame.syncIndicator:SetVertexColor(1, 1, 0, 1)
    else self.Frame.syncIndicator:SetVertexColor(1, 0, 0, 1) end
end

function GuildUtils.Ledger:UpdateDisplay(searchQuery)
    if not self.Frame or not self.Frame:IsShown() then return end
    
    local hostName = GuildUtils.Host or "None"
    if GuildUtils.SoloMode then hostName = UnitName("player") .. " (Solo)" end
    self.Frame.hostLabel:SetText("Host: " .. hostName)
    
    for _, row in ipairs(self.Rows) do row:Hide() end
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.balances then return end
    
    local sortedList = {}
    for guid, bal in pairs(GU_GlobalDB.Ledger.balances) do
        local name = GU_GlobalDB.Ledger.roster[guid] or "Unknown"
        local mainGuid = GU_GlobalDB.Ledger.altMap and GU_GlobalDB.Ledger.altMap[guid]
        local effectiveBal = bal
        if mainGuid and GU_GlobalDB.Ledger.balances[mainGuid] then
            effectiveBal = GU_GlobalDB.Ledger.balances[mainGuid]
        end
        table.insert(sortedList, {guid = guid, name = name, balance = effectiveBal, isAlt = (mainGuid ~= nil), mainGuid = mainGuid})
    end
    
    table.sort(sortedList, function(a, b)
        if a.balance ~= b.balance then return a.balance > b.balance end
        return a.name < b.name
    end)
    
    local rowIndex, yOffset = 1, -5
    local scrollChild = self.Frame.scrollChild 
    searchQuery = searchQuery or (self.Frame.searchBox and self.Frame.searchBox:GetText()) or ""
    searchQuery = searchQuery:lower()

    for _, data in ipairs(sortedList) do
        if searchQuery == "" or data.name:lower():find(searchQuery) then
            local row = self.Rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(230, 24)
                row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.nameText:SetPoint("LEFT", 2, 0)
                row.nameText:SetWidth(150)
                row.nameText:SetJustifyH("LEFT")
                row.balText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.balText:SetPoint("RIGHT", -5, 0) 
                
                row:EnableMouse(true)
                self.Rows[rowIndex] = row
            end
            
            row:SetScript("OnMouseDown", function(selfRow, button)
                if button == "RightButton" and GuildUtils:IsAuthoritativeHost() then
                    MenuUtil.CreateContextMenu(selfRow, function(owner, rootDescription)
                        rootDescription:CreateTitle(data.name .. (data.isAlt and " (Alt)" or ""))
                        rootDescription:CreateButton("Add LC", function() StaticPopup_Show("GUILDUTILS_LC_MODAL", "Add", data.name, {action = "Add", guid = data.guid, name = data.name}) end)
                        rootDescription:CreateButton("Subtract LC", function() StaticPopup_Show("GUILDUTILS_LC_MODAL", "Subtract", data.name, {action = "Subtract", guid = data.guid, name = data.name}) end)
                        
                        if not data.isAlt then
                            rootDescription:CreateButton("Link as Alt...", function()
                                StaticPopup_Show("GUILDUTILS_LINK_ALT_MODAL", data.name, nil, {guid = data.guid, name = data.name})
                            end)
                        else
                            rootDescription:CreateButton("Unlink Alt", function()
                                GuildUtils.LootCoin:UnlinkAlt(data.guid, data.name)
                            end)
                        end

                        local isFrozen = GU_GlobalDB.Ledger.frozenAccounts and GU_GlobalDB.Ledger.frozenAccounts[data.guid] == "F"
                        rootDescription:CreateButton(isFrozen and "Unfreeze Account" or "Freeze Account", function()
                            local tState = isFrozen and "0" or "1"
                            GuildUtils.LootCoin:ToggleManagementFreeze(data.guid, data.name, tState)
                            GuildUtils:QueueMessage("SET_FREEZE:" .. data.guid .. ":" .. data.name .. ":" .. tState, "GUILD")
                        end)
                    end)
                end
            end)

            row:SetPoint("TOPLEFT", 0, yOffset)
            local isFrozen = GU_GlobalDB.Ledger.frozenAccounts and GU_GlobalDB.Ledger.frozenAccounts[data.guid]
            local tagString = ""
            if data.isAlt then
                tagString = "|cFF00BFFF[Alt]|r "
            end
            if isFrozen then
                tagString = tagString .. "|cFFFF0000[" .. tostring(isFrozen) .. "]|r "
            end
            
            row.nameText:SetText(tagString .. data.name)
            row.nameText:SetTextColor(1, 0.82, 0, 1)
            row.balText:SetText(tostring(data.balance))
            row.balText:SetTextColor(1, 1, 1, 1)
            row:Show()
            yOffset = yOffset - 26
            rowIndex = rowIndex + 1
        end
    end
    scrollChild:SetHeight(math.abs(yOffset))
end

local rosterScanner = CreateFrame("Frame")
rosterScanner:RegisterEvent("PLAYER_LOGIN")
rosterScanner:RegisterEvent("GUILD_ROSTER_UPDATE")

rosterScanner:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" and IsInGuild() then
        C_Timer.After(5, function() 
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() 
            elseif GuildRoster then GuildRoster() end
        end)
    elseif event == "GUILD_ROSTER_UPDATE" then
        if not GU_GlobalDB or not GU_GlobalDB.Ledger then return end
        local dbUpdated = false
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if name and guid then
                local cleanName = GuildUtils:FormatName(name)
                if not GU_GlobalDB.Ledger.roster[guid] or GU_GlobalDB.Ledger.roster[guid] ~= cleanName then
                    GU_GlobalDB.Ledger.roster[guid] = cleanName
                    GU_GlobalDB.Ledger.balances[guid] = GU_GlobalDB.Ledger.balances[guid] or 0
                    dbUpdated = true
                end
            end
        end
        if dbUpdated then
            GuildUtils:Print("|cFF00FF00[Scanner]|r Guild roster synchronized.", false)
            if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
        end
    end
end)