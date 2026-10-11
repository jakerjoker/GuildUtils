local addonName, GuildUtils = ...

function GuildUtils:GetChatColor(alertType)
    if not GU_CharDB or not GU_CharDB.ActiveProfile then return self.Constants.ChatAlerts[alertType].defaultColor end
    local activeProfile = GU_CharDB.ActiveProfile
    if activeProfile == "Default" or not GU_CharDB.Profiles[activeProfile].Colors[alertType] then
        return self.Constants.ChatAlerts[alertType].defaultColor
    end
    return GU_CharDB.Profiles[activeProfile].Colors[alertType]
end

function GuildUtils:Print(msg, alertTypeOrWarning)
    local alertType = "Normal"
    if type(alertTypeOrWarning) == "string" then alertType = alertTypeOrWarning
    elseif alertTypeOrWarning == true then alertType = "Election" end
    
    local color = self:GetChatColor(alertType)
    print(string.format("|cFF%s[GuildUtils] %s|r", color, tostring(msg)))
end

function GuildUtils:TriggerDesktopAlert()
    if GU_CharDB and GU_CharDB.DesktopAlerts then FlashClientIcon() end
end

function GuildUtils:FormatName(rawName)
    if not rawName or rawName == "" then return nil end
    local cleanName = Ambiguate(rawName, "none")
    return cleanName:lower():gsub("^%l", string.upper)
end

function GuildUtils:IsMasterLootActive()
    if self.SoloMode then return true end
    if not IsInGroup() then return false end
    local isLeader = UnitIsGroupLeader("player")
    if type(GetLootMethod) ~= "function" then return isLeader end
    
    local lootMethod, mlPartyID = GetLootMethod()
    if isLeader and (GetNumGroupMembers() <= 2) then return true end
    if not lootMethod or string.lower(lootMethod) ~= "master" then return false end
    return (isLeader or (mlPartyID == 0))
end

function GuildUtils:AppendAuditLog(entry)
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.auditLog then return end
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() and GuildUtils.Ledger.Frame.currentView == "AUDIT" then
        GuildUtils.Ledger:UpdateDisplay()
    end
end

GuildUtils.Styles = {
    [1] = { name = "Blizzard Classic", backdrop = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } }, bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", bgColor = {1, 1, 1, 1}, borderColor = {1, 1, 1, 1}, titleColor = {1, 0.96, 0.41, 1}, nameColor = {1, 0.82, 0, 1}, balColor = {1, 1, 1, 1}, texCoords = {0, 1, 0, 1} },
    [2] = { name = "Modern Flat", backdrop = { edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }, bgFile = "Interface\\Buttons\\WHITE8x8", bgColor = {0.05, 0.05, 0.05, 0.95}, borderColor = {0.3, 0.3, 0.3, 1}, titleColor = {1, 1, 1, 1}, nameColor = {1, 0.88, 0.1, 1}, balColor = {1, 1, 1, 1}, texCoords = {0, 1, 0, 1} },
    
    -- Properly restored to use your custom asset without being overwritten!
    [3] = { name = "Floating Scroll", backdrop = nil, bgFile = "Interface\\AddOns\\GuildUtils\\Media\\MyParchment.tga", bgColor = {1, 1, 1, 1}, borderColor = {0, 0, 0, 0}, titleColor = {0.2, 0.1, 0.05, 1}, nameColor = {0.1, 0.1, 0.1, 1}, balColor = {0.2, 0.1, 0.05, 1}, texCoords = {0, 1, 0, 1} }
}

SLASH_GUILDUTILSLEDGER1, SLASH_GUILDUTILSLEDGER2 = "/gu", "/ledger"
SlashCmdList["GUILDUTILSLEDGER"] = function() if GuildUtils.Ledger then GuildUtils.Ledger:Toggle() end end

SLASH_GUILDUTILSLOOT1 = "/guloot"
SlashCmdList["GUILDUTILSLOOT"] = function() if GuildUtils.PartyRoller then GuildUtils.PartyRoller:Toggle() end end

SLASH_GUILDUTILSCONFIG1 = "/guconfig"
SlashCmdList["GUILDUTILSCONFIG"] = function() if GuildUtils.SettingsUI then GuildUtils.SettingsUI:TogglePanel() end end

SLASH_GUILDUTILSCONTRACTS1 = "/gubb"
SlashCmdList["GUILDUTILSCONTRACTS"] = function() if GuildUtils.Contracts then GuildUtils.Contracts:Toggle() end end

SLASH_GUILDUTILSSTARTGROUP1 = "/gustartgroup"
SlashCmdList["GUILDUTILSSTARTGROUP"] = function() if GuildUtils:IsMasterLootActive() then GuildUtils.LootCoin:StartGroupEvent() end end

SLASH_GUILDUTILSENDGROUP1 = "/guendgroup"
SlashCmdList["GUILDUTILSENDGROUP"] = function() if GuildUtils:IsMasterLootActive() then GuildUtils.LootCoin:EndGroupEvent() end end

SLASH_GUILDUTILS_BID1 = "/gubid"
SlashCmdList["GUILDUTILS_BID"] = function(msg) if GuildUtils.PartyRoller then GuildUtils.PartyRoller:ParseBidCommand(msg) end end

SLASH_GUILDUTILSNEXT1 = "/gunext"
SlashCmdList["GUILDUTILSNEXT"] = function()
    if not GuildUtils.SoloMode and not IsInGroup() then
        GuildUtils:Print("You must be in a party/raid or have Solo Mode enabled (/gusolo).", true)
        return
    end
    if GuildUtils.PartyRoller then GuildUtils.PartyRoller:HostNextItem() end
end

SLASH_GUILDUTILSSOLO1 = "/gusolo"
SlashCmdList["GUILDUTILSSOLO"] = function()
    GuildUtils.SoloMode = not GuildUtils.SoloMode
    if GuildUtils.SoloMode then
        GuildUtils.Host = UnitName("player")
        GuildUtils:Print("Solo Mode ENABLED. Host set to local player. Master Loot checks bypassed.", false)
    else
        GuildUtils.Host = nil
        GuildUtils:Print("Solo Mode DISABLED. Using standard party/raid logic.", false)
    end
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then 
        GuildUtils.Ledger:UpdateDisplay() 
    end
end