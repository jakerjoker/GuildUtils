local addonName, GuildUtils = ...
_G.GuildUtils = GuildUtils 
GuildUtils.UI = GuildUtils.UI or {}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        GU_GlobalDB = GU_GlobalDB or {}
        
        -- Core Ledger Initialization
        if not GU_GlobalDB.Ledger then
            GU_GlobalDB.Ledger = { 
                version = 1, 
                balances = {}, 
                roster = {}, 
                frozenAccounts = {}, 
                joinDates = {} 
            }
        end
        
        -- Module Databases 
        GU_GlobalDB.Contracts = GU_GlobalDB.Contracts or { list = {}, nextId = 1 }
        
        -- TASK 3: Added the Events Database
        GU_GlobalDB.Events = GU_GlobalDB.Events or { list = {}, nextId = 1 }
        GU_GlobalDB.Settings = GU_GlobalDB.Settings or {}
    end
end)

-- ==========================================
-- GUILD PARTITION & DATA PROTECTION
-- ==========================================
function GuildUtils:VerifyGuildPartition()
    local currentGuild = GetGuildInfo("player")
    if not currentGuild then return end
    
    if GU_GlobalDB.GuildName and GU_GlobalDB.GuildName ~= currentGuild then
        GuildUtils:Print("Guild shift detected. Wiping local GuildUtils database to prevent cross-contamination.", true)
        
        -- Nuke the local database so it doesn't infect the new guild
        GU_GlobalDB.Ledger = { 
            version = 1, 
            balances = {}, 
            roster = {}, 
            frozenAccounts = {}, 
            joinDates = {} 
        }
        GU_GlobalDB.Contracts = { list = {}, nextId = 1 }
        GU_GlobalDB.Events = { list = {}, nextId = 1 }
        GU_GlobalDB.Settings = {}
    end
    
    GU_GlobalDB.GuildName = currentGuild
end

-- Create an invisible frame to listen for login/guild updates
local partitionWatcher = CreateFrame("Frame")
partitionWatcher:RegisterEvent("PLAYER_LOGIN")
partitionWatcher:RegisterEvent("PLAYER_GUILD_UPDATE")
partitionWatcher:SetScript("OnEvent", function(self, event)
    -- Delay slightly on login so the WoW client has time to fetch the guild name from the server
    C_Timer.After(2, function()
        if GuildUtils.VerifyGuildPartition then
            GuildUtils:VerifyGuildPartition()
        end
    end)
end)