local addonName, GuildUtils = ...

GuildUtils.LedgerRows = {}
GuildUtils.AuditRows = {}

-- Define the reusable right-click context menu
if not GuildUtils.ContextMenu then
    local menu = CreateFrame("Frame", "GuildUtilsLedgerMenu", UIParent, "BackdropTemplate")
    menu:SetSize(150, 130)
    menu:SetFrameStrata("TOOLTIP") -- Ensures it renders above all other windows
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    menu:Hide()
    
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menu.title:SetPoint("TOP", 0, -10)
    
    local function CreateMenuButton(text, yOffset)
        local btn = CreateFrame("Button", nil, menu, "GameMenuButtonTemplate")
        btn:SetSize(120, 22)
        btn:SetPoint("TOP", 0, yOffset)
        btn:SetText(text)
        return btn
    end
    
    menu.btnAdd = CreateMenuButton("Add LC", -30)
    menu.btnSub = CreateMenuButton("Subtract LC", -55)
    menu.btnFreeze = CreateMenuButton("Toggle Freeze", -80)
    
    menu.btnCancel = CreateMenuButton("Cancel", -105)
    menu.btnCancel:SetScript("OnClick", function() menu:Hide() end)

    GuildUtils.ContextMenu = menu
end

function GuildUtils:ToggleLedgerUI()
    if not self.LedgerFrame then
        self.LedgerFrame = CreateFrame("Frame", "GuildUtilsLedgerFrame", UIParent, "BasicFrameTemplateWithInset")
        local f = self.LedgerFrame
        f:SetSize(420, 480)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
        f.title:SetText("GuildUtils: LootCoin Ledger")
        
        f.currentView = "BALANCES"
        
        -- Toggle Tab Buttons
        f.tabBalances = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.tabBalances:SetSize(90, 24)
        f.tabBalances:SetPoint("TOPLEFT", 12, -30)
        f.tabBalances:SetText("Balances")
        f.tabBalances:SetScript("OnClick", function()
            f.currentView = "BALANCES"
            f.searchBox:Show()
            GuildUtils:UpdateLedgerDisplay(f.searchBox:GetText())
        end)
        
        f.tabAudit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.tabAudit:SetSize(90, 24)
        f.tabAudit:SetPoint("LEFT", f.tabBalances, "RIGHT", 5, 0)
        f.tabAudit:SetText("Audit Log")
        f.tabAudit:SetScript("OnClick", function()
            f.currentView = "AUDIT"
            f.searchBox:Hide()
            GuildUtils:UpdateLedgerDisplay()
        end)

        -- Search Box
        f.searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.searchBox:SetSize(180, 20)
        f.searchBox:SetPoint("TOPRIGHT", -12, -32)
        f.searchBox:SetAutoFocus(false)
        f.searchBox:SetScript("OnTextChanged", function(self)
            GuildUtils:UpdateLedgerDisplay(self:GetText())
        end)
        
        f.searchPlaceholder = f.searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.searchPlaceholder:SetPoint("LEFT", f.searchBox, "LEFT", 4, 0)
        f.searchPlaceholder:SetText("Search player...")
        f.searchBox:SetScript("OnEditFocusGained", function(self) f.searchPlaceholder:Hide() end)
        f.searchBox:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then f.searchPlaceholder:Show() end end)

        -- Scroll Frame Area
        f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.scrollFrame:SetPoint("TOPLEFT", 10, -65)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)
        
        f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
        f.scrollChild:SetSize(360, 1)
        f.scrollFrame:SetScrollChild(f.scrollChild)

        -- Bottom Host Indicator & Sync Controls
        f.hostLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.hostLabel:SetPoint("BOTTOMLEFT", 15, 15)
        f.hostLabel:SetText("Host: None")

        f.syncBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.syncBtn:SetSize(100, 22)
        f.syncBtn:SetPoint("BOTTOMRIGHT", -15, 12)
        f.syncBtn:SetText("Sync Ledger")
        f.syncBtn:SetScript("OnClick", function()
            if GuildUtils.Host and GuildUtils.Host ~= UnitName("player") then
                GuildUtils:SendSync("SYNC_REQUEST:0", "WHISPER", GuildUtils.Host)
                GuildUtils:Print("Requested ledger synchronization from " .. GuildUtils.Host, false)
            else
                GuildUtils:Print("You are currently the Host or no Host is available.", true)
            end
        end)
    end

    if self.LedgerFrame:IsShown() then
        self.LedgerFrame:Hide()
    else
        self.LedgerFrame:Show()
        self:UpdateLedgerDisplay()
    end
end

function GuildUtils:UpdateLedgerDisplay(searchQuery)
    if not self.LedgerFrame or not self.LedgerFrame:IsShown() then return end
    
    -- Update Host Footer Tag
    local hostName = self.Host or "None"
    if self.SoloMode then hostName = UnitName("player") .. " (Solo)" end
    self.LedgerFrame.hostLabel:SetText("Host: " .. hostName)
    
    local scrollChild = self.LedgerFrame.scrollChild
    for _, row in ipairs(GuildUtils.LedgerRows) do row:Hide() end
    if self.AuditBox then self.AuditBox:Hide() end
    
    searchQuery = searchQuery and searchQuery:lower() or ""
    
    if self.LedgerFrame.currentView == "BALANCES" then
        if not GuildUtilsDB or not GuildUtilsDB.Ledger or not GuildUtilsDB.Ledger.balances then return end
        
        local sortedList = {}
        for guid, bal in pairs(GuildUtilsDB.Ledger.balances) do
            local name = GuildUtilsDB.Ledger.roster[guid] or "Unknown"
            table.insert(sortedList, {guid = guid, name = name, balance = bal})
        end
        
        table.sort(sortedList, function(a, b)
            if a.balance ~= b.balance then return a.balance > b.balance end
            return a.name < b.name
        end)
        
        local rowIndex = 1
        local yOffset = -5
        
        for _, data in ipairs(sortedList) do
            if searchQuery == "" or data.name:lower():find(searchQuery) then
                local row = GuildUtils.LedgerRows[rowIndex]
                if not row then
                    row = CreateFrame("Frame", nil, scrollChild)
                    row:SetSize(360, 24)
                    
                    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.nameText:SetPoint("LEFT", 5, 0)
                    
                    -- Shifted right to fill the space left by removed buttons
                    row.balText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.balText:SetPoint("RIGHT", -20, 0) 
                    
                    GuildUtils.LedgerRows[rowIndex] = row
                end
                
                row:SetPoint("TOPLEFT", 0, yOffset)
                row.nameText:SetText(data.name)
                
                local isFrozen = GuildUtilsDB.Ledger.frozenAccounts and GuildUtilsDB.Ledger.frozenAccounts[data.guid]
                local balDisplay = tostring(data.balance)
                if isFrozen then
                    balDisplay = balDisplay .. " |cFFFF0000[" .. tostring(isFrozen) .. "]|r"
                end
                row.balText:SetText(balDisplay)
                
                -- Context Menu (Right-Click) Binding
                row:EnableMouse(true)
                row:SetScript("OnMouseDown", function(self, button)
                    if button == "RightButton" then
                        local menu = GuildUtils.ContextMenu
                        menu.title:SetText(data.name)
                        
                        menu.btnAdd:SetScript("OnClick", function()
                            menu:Hide()
                            StaticPopupDialogs["GUILDUTILS_ADD_BALANCE"] = {
                                text = "Add LC for " .. data.name .. ":",
                                button1 = "Add", button2 = "Cancel",
                                hasEditBox = true, maxLetters = 6,
                                OnAccept = function(selfPopup)
                                    local amt = tonumber(selfPopup.EditBox:GetText())
                                    if amt and GuildUtils.LootCoin then
                                        GuildUtils.LootCoin:ProcessTransaction(data.guid, data.name, math.abs(amt), "Manual Addition")
                                    end
                                end,
                                timeout = 0, whileDead = true, hideOnEscape = true,
                            }
                            StaticPopup_Show("GUILDUTILS_ADD_BALANCE")
                        end)
                        
                        menu.btnSub:SetScript("OnClick", function()
                            menu:Hide()
                            StaticPopupDialogs["GUILDUTILS_SUB_BALANCE"] = {
                                text = "Subtract LC from " .. data.name .. ":",
                                button1 = "Subtract", button2 = "Cancel",
                                hasEditBox = true, maxLetters = 6,
                                OnAccept = function(selfPopup)
                                    local amt = tonumber(selfPopup.EditBox:GetText())
                                    if amt and GuildUtils.LootCoin then
                                        GuildUtils.LootCoin:ProcessTransaction(data.guid, data.name, -math.abs(amt), "Manual Deduction")
                                    end
                                end,
                                timeout = 0, whileDead = true, hideOnEscape = true,
                            }
                            StaticPopup_Show("GUILDUTILS_SUB_BALANCE")
                        end)
                        
                        menu.btnFreeze:SetScript("OnClick", function()
                            menu:Hide()
                            if GuildUtils.LootCoin then 
                                local currentlyFrozen = GuildUtilsDB.Ledger.frozenAccounts and GuildUtilsDB.Ledger.frozenAccounts[data.guid] == "F"
                                local targetState = currentlyFrozen and "0" or "1"
                                GuildUtils.LootCoin:ToggleManagementFreeze(data.guid, data.name, false, targetState) 
                            end
                        end)
                        
                        local x, y = GetCursorPosition()
                        local scale = UIParent:GetEffectiveScale()
                        menu:ClearAllPoints()
                        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                        menu:Show()
                    end
                end)
                
                row:Show()
                yOffset = yOffset - 28
                rowIndex = rowIndex + 1
            end
        end
        scrollChild:SetHeight(math.abs(yOffset))
        
    elseif self.LedgerFrame.currentView == "AUDIT" then
        if not self.AuditBox then
            self.AuditBox = CreateFrame("EditBox", nil, scrollChild)
            self.AuditBox:SetMultiLine(true)
            self.AuditBox:SetFontObject("GameFontHighlightSmall")
            self.AuditBox:SetWidth(330)
            self.AuditBox:SetAutoFocus(false)
            self.AuditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            self.AuditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        end
        
        self.AuditBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, -5)
        
        local fullLog = ""
        if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.auditLog then
            for i = #GuildUtilsDB.Ledger.auditLog, 1, -1 do
                local entry = GuildUtilsDB.Ledger.auditLog[i]
                if type(entry) == "table" then
                    local ts = entry.timestamp or "Unknown Time"
                    local p = entry.pusher or "Unknown"
                    local d = entry.details or "No details"
                    fullLog = fullLog .. string.format("[%s] %s: %s", ts, p, d) .. "\n"
                else
                    fullLog = fullLog .. tostring(entry) .. "\n"
                end
            end
        end
        
        self.AuditBox:SetText(fullLog)
        self.AuditBox:Show()
        scrollChild:SetHeight(math.max(300, self.AuditBox:GetHeight() + 20))
    end
end

-- Slash Commands
SLASH_GUILDUTILSLEDGER1 = "/gu"
SLASH_GUILDUTILSLEDGER2 = "/ledger"
SlashCmdList["GUILDUTILSLEDGER"] = function()
    GuildUtils:ToggleLedgerUI()
end

SLASH_GUILDUTILSREFRESH1 = "/gurefresh"
SlashCmdList["GUILDUTILSREFRESH"] = function()
    GuildUtils:UpdateLedgerDisplay()
    GuildUtils:Print("Ledger UI manually refreshed.", false)
end

-- Native Guild/Communities Pane Integration
local function CreateGuildPaneButton()
    if not CommunitiesFrame then return end
    
    -- Prevent duplicate button creation on re-loads
    if _G["GuildUtilsLedgerButton"] then return end

    -- 1. LC Ledger Button
    local ledgerBtn = CreateFrame("Button", "GuildUtilsLedgerButton", CommunitiesFrame, "UIPanelButtonTemplate")
    ledgerBtn:SetText("LC Ledger")
    ledgerBtn:SetSize(80, 22) 
    ledgerBtn:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 2, -250)
    ledgerBtn:SetScript("OnClick", function()
        if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then
            GuildUtils.LedgerFrame:Hide()
        else
            if not GuildUtils.LedgerFrame then GuildUtils:ToggleLedgerUI(); GuildUtils.LedgerFrame:Hide(); end
            GuildUtils.LedgerFrame:ClearAllPoints()
            GuildUtils.LedgerFrame:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 90, 0)
            GuildUtils.LedgerFrame:Show()
            GuildUtils:UpdateLedgerDisplay()
        end
    end)

    -- 2. Group & Loot Manager Button (Formatted with staggered spacing)
    local glBtn = CreateFrame("Button", "GuildUtilsGLButton", CommunitiesFrame, "UIPanelButtonTemplate")
    glBtn:SetText("Group\n     &\n  Loot")
    
    local btnText = glBtn:GetFontString()
    if btnText then
        btnText:SetJustifyH("LEFT")
    end
    
    glBtn:SetSize(80, 50) 
    glBtn:SetPoint("TOP", ledgerBtn, "BOTTOM", 0, -10)
    glBtn:SetScript("OnClick", function()
        if GuildUtils.PartyRoller then
            local f = GuildUtils.PartyRoller:InitializeUI()
            if f:IsShown() then
                f:Hide()
            else
                if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.ActiveSession then
                    GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
                else
                    GuildUtils.PartyRoller:SetUIState("IDLE_PANEL")
                end
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 90, 0)
            end
        end
    end)
end

local eventWatcher = CreateFrame("Frame")
eventWatcher:RegisterEvent("ADDON_LOADED")
eventWatcher:RegisterEvent("PLAYER_LOGIN")
eventWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" or arg1 == "Blizzard_Communities" then
        if CommunitiesFrame then
            CreateGuildPaneButton()
        end
    end
end)

if CommunitiesFrame then
    CreateGuildPaneButton()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, addon)
        if addon == "Blizzard_Communities" then
            CreateGuildPaneButton()
            self:UnregisterAllEvents()
        end
    end)
end