local addonName, GuildUtils = ...

function GuildUtils:Print(msg, isWarning)
    local alertType = isWarning and "Election" or "Normal"
    local color = (self.Constants and self.Constants.ChatAlerts[alertType]) and self.Constants.ChatAlerts[alertType].defaultColor or "00BFFF"
    print(string.format("|cFF%s[GuildUtils]|r %s", color, tostring(msg)))
end

function GuildUtils:FormatName(rawName)
    if not rawName or rawName == "" then return nil end
    local cleanName = Ambiguate(rawName, "none")
    return cleanName:lower():gsub("^%l", string.upper)
end

GuildUtils.ItemCacheQueue = {}
local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
cacheFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" and success and GuildUtils.ItemCacheQueue[itemID] then
        for _, callback in ipairs(GuildUtils.ItemCacheQueue[itemID]) do callback(itemID) end
        GuildUtils.ItemCacheQueue[itemID] = nil
    end
end)

function GuildUtils:GetItemOrYield(itemID, callback)
    local itemName, itemLink = GetItemInfo(itemID)
    if itemName then
        callback(itemID, itemName, itemLink)
    else
        if not self.ItemCacheQueue[itemID] then self.ItemCacheQueue[itemID] = {} end
        table.insert(self.ItemCacheQueue[itemID], function(id)
            local name, link = GetItemInfo(id)
            callback(id, name, link)
        end)
    end
end

SLASH_GUILDUTILSLEDGER1, SLASH_GUILDUTILSLEDGER2 = "/gu", "/ledger"
SlashCmdList["GUILDUTILSLEDGER"] = function() if GuildUtils.Ledger then GuildUtils.Ledger:Toggle() end end

SLASH_GUILDUTILSLOOT1 = "/guloot"
SlashCmdList["GUILDUTILSLOOT"] = function() if GuildUtils.PartyRoller then GuildUtils.PartyRoller:Toggle() end end

SLASH_GUILDUTILSCONFIG1 = "/guconfig"
SlashCmdList["GUILDUTILSCONFIG"] = function() if GuildUtils.SettingsUI then GuildUtils.SettingsUI:TogglePanel() end end

SLASH_GUILDUTILSCONTRACTS1 = "/gubb"
SlashCmdList["GUILDUTILSCONTRACTS"] = function() if GuildUtils.Contracts then GuildUtils.Contracts:Toggle() end end

SLASH_GUILDUTILS_BID1 = "/gubid"
SlashCmdList["GUILDUTILS_BID"] = function(msg)
    if msg == "" then 
        GuildUtils:Print("Usage: /gubid [Item Link]", true) 
        return 
    end
    if GuildUtils.PartyRoller then GuildUtils.PartyRoller:HostStartRoll(msg) end
end

SLASH_GUILDUTILSSCAN1 = "/guscan"
SlashCmdList["GUILDUTILSSCAN"] = function()
    if IsInGuild() then
        GuildUtils:Print("Requesting live roster update from server...", false)
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() 
        elseif GuildRoster then GuildRoster() end
    else
        GuildUtils:Print("You are not currently in a guild. Roster scan failed.", true)
    end
end