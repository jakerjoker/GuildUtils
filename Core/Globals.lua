local addonName, GuildUtils = ...

-- ============================================================================
-- CONSTANTS & HELPERS
-- ============================================================================
GuildUtils.Constants = GuildUtils.Constants or {}
GuildUtils.Constants.ChatAlerts = {
    Normal = { defaultColor = "00BFFF" },
    Election = { defaultColor = "FFD700" }
}
GuildUtils.Constants.StatusTags = {
    Freeze = { defaultColor = "00BFFF" },
    GroupLeader = { defaultColor = "FF8C00" },
    InGroup = { defaultColor = "FF8C00" },
    Tampered = { defaultColor = "FF4500" }
}

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
    if not GU_GlobalDB or not GU_GlobalDB.Ledger then return end
    GU_GlobalDB.Ledger.auditLog = GU_GlobalDB.Ledger.auditLog or {}
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() and GuildUtils.Ledger.Frame.currentView == "AUDIT" then
        GuildUtils.Ledger:UpdateDisplay()
    end
end

-- ============================================================================
-- THEME & STYLE REGISTRY (HIGH CONTRAST)
-- ============================================================================
GuildUtils.Styles = {
    [1] = { 
        name = "Blizzard Classic", 
        backdrop = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } }, 
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        bgColor = {1, 1, 1, 1}, 
        borderColor = {1, 1, 1, 1}, 
        titleColor = {1, 0.82, 0, 1}, 
        nameColor = {1, 0.96, 0.41, 1},  -- High Contrast Bright Gold
        balColor = {1, 1, 1, 1},         -- Pure White
        entryColor = {1, 1, 1, 1}        -- Pure White (For EditBoxes & Audit Log)
    },
    [2] = { 
        name = "Modern Flat", 
        backdrop = { edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }, 
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        bgColor = {0.05, 0.05, 0.05, 0.95}, -- Pitch Black Background
        borderColor = {0.4, 0.4, 0.4, 1}, 
        titleColor = {0, 0.8, 1, 1},     -- Cyan Header
        nameColor = {0.2, 1, 0.2, 1},    -- Neon Green Names
        balColor = {1, 1, 1, 1},         -- Pure White Balances
        entryColor = {1, 1, 1, 1}        -- Pure White
    },
    [3] = { 
        name = "Floating Scroll", 
        backdrop = nil, 
        bgFile = "Interface\\AddOns\\GuildUtils\\Media\\MyParchment.tga", 
        bgColor = {1, 1, 1, 1}, 
        borderColor = {0, 0, 0, 0}, 
        titleColor = {0.2, 0.1, 0.05, 1}, 
        nameColor = {0, 0, 0, 1},        -- Pure Black Names
        balColor = {0.15, 0.1, 0.05, 1}, -- Dark Brown Balances
        entryColor = {0, 0, 0, 1},       -- Pure Black
        texCoords = {0, 1, 0, 1}   -- Custom crop coordinates
    }
}

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
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

SLASH_GUILDUTILSSOLO1 = "/gusolo"
SlashCmdList["GUILDUTILSSOLO"] = function()
    GuildUtils.SoloMode = not GuildUtils.SoloMode
    if GuildUtils.SoloMode then
        GuildUtils.Host = UnitName("player")
        GuildUtils:Print("Solo Mode ENABLED. Bypassing group restrictions for local testing.", false)
    else
        GuildUtils.Host = nil
        GuildUtils:Print("Solo Mode DISABLED. Normal network synchronization active.", false)
    end
    
    -- Force a live redraw of the Ledger if it's open so the [H] tag updates immediately
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
        GuildUtils.Ledger:UpdateDisplay()
    end
end
SLASH_GUILDUTILSINITGUILD1 = "/guinitguild"
SlashCmdList["GUILDUTILSINITGUILD"] = function()
    if GuildUtils.LootCoin and GuildUtils.LootCoin.InitializeGuild then
        GuildUtils.LootCoin:InitializeGuild()
    else
        GuildUtils:Print("LootCoin module or InitializeGuild function not loaded.", true)
    end
end