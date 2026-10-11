local addonName, GuildUtils = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local defaultGlobalDB = {
    Ledger = { 
        version = 1, 
        balances = {}, 
        auditLog = {}, 
        frozenAccounts = {}, 
        roster = {},
        altMap = {} -- Maps Alt GUID -> Main GUID
    },
    Contracts = {
        list = {}, -- Contract entries: {id, title, creatorGuid, creatorName, itemLink, count, reward, isGuildQuest, completed}
        nextId = 1
    },
    Settings = {
        Hierarchy = { [0] = "Guild Master", [1] = "Raid Leader", [2] = "Economy Council", [3] = "Officer" },
        HeartbeatRate = 10,
        AttendanceReward = 10
    }
}

local defaultCharDB = {
    PartyRollerEnabled = true,
    SmartMinimap = true,
    ShowTooltips = true,
    Theme = 1 -- 1: Dark Slate, 2: Citadel Steel, 3: Parchment Gold
}

local function CopyDefaults(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            CopyDefaults(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        GU_GlobalDB = GU_GlobalDB or {}
        GU_CharDB = GU_CharDB or {}

        CopyDefaults(defaultGlobalDB, GU_GlobalDB)
        CopyDefaults(defaultCharDB, GU_CharDB)
        
        print("|cFF00FF00GuildUtils B1.0 Core Loaded.|r")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)