local addonName, GuildUtils = ...
_G.GuildUtils = GuildUtils -- Global access for Debug.lua and external macros

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- B1.0 Database Schemas
local defaultGlobalDB = {
    Ledger = {},
    Contracts = {},
    Settings = {
        Hierarchy = { [0] = "GM", [1] = "RL", [2] = "EC", [3] = "Officer" },
        HeartbeatRate = 10,
        Quarantine = {}
    }
}

local defaultCharDB = {
    PartyRollerEnabled = true,
    SmartMinimap = true,
    ShowTooltips = true,
    DynamicColors = true,
    AchievementToasts = true,
    UIPositions = {}
}

-- Recursive deep copy to safely inject missing schema updates
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