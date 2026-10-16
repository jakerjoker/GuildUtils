local addonName, GuildUtils = ...
_G.GuildUtils = GuildUtils 
GuildUtils.UI = GuildUtils.UI or {}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        GU_GlobalDB = GU_GlobalDB or {}
        
        if not GU_GlobalDB.Ledger then
            GU_GlobalDB.Ledger = { 
                version = 1, 
                balances = {}, 
                roster = {}, 
                frozenAccounts = {}, 
                joinDates = {},
				auditLog = {}				
            }
        end
        
        GU_GlobalDB.Contracts = GU_GlobalDB.Contracts or { list = {}, nextId = 1 }
        GU_GlobalDB.Events = GU_GlobalDB.Events or { list = {}, nextId = 1 }
        GU_GlobalDB.Settings = GU_GlobalDB.Settings or {}
    end
end)

function GuildUtils:VerifyGuildPartition()
    local currentGuild = GetGuildInfo("player")
    if not currentGuild then return end
    
    if GU_GlobalDB.GuildName and GU_GlobalDB.GuildName ~= currentGuild then
        GuildUtils:Print("Guild shift detected. Wiping local GuildUtils database to prevent cross-contamination.", true)
        
        GU_GlobalDB.Ledger = { 
            version = 1, 
            balances = {}, 
            roster = {}, 
            frozenAccounts = {}, 
            joinDates = {},
			auditLog = {}			
        }
        GU_GlobalDB.Contracts = { list = {}, nextId = 1 }
        GU_GlobalDB.Events = { list = {}, nextId = 1 }
        GU_GlobalDB.Settings = {}
    end
    
    GU_GlobalDB.GuildName = currentGuild
end

local partitionWatcher = CreateFrame("Frame")
partitionWatcher:RegisterEvent("PLAYER_LOGIN")
partitionWatcher:RegisterEvent("PLAYER_GUILD_UPDATE")
partitionWatcher:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, function()
        if GuildUtils.VerifyGuildPartition then
            GuildUtils:VerifyGuildPartition()
        end
    end)
end)