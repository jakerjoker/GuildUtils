local addonName, GuildUtils = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local defaultGlobalDB = {
    Ledger = { 
        version = 1, balances = {}, auditLog = {}, frozenAccounts = {}, roster = {},
        altMap = {}, LocalSessionSpent = 0, ActiveSession = nil,
        PendingMerges = {}, ProcessedMerges = {}, PENDING_CONSENSUS = false, PENDING_LOG_EXPORT = false
    },
    Contracts = { list = {}, nextId = 1 },
    Settings = { Hierarchy = { [0] = "GM", [1] = "RL", [2] = "EC", [3] = "Officer" }, HeartbeatRate = 5, AttendanceReward = 10 }
}

local defaultCharDB = {
    PartyRollerEnabled = true, SmartMinimap = true, ShowTooltips = true,
    Theme = 1, ActiveProfile = "Default", LedgerFontSize = 12,
    Profiles = { Guild = { Colors = {} }, Personal = { Colors = {} }, Default = { Colors = {} } }
}

local function CopyDefaults(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            CopyDefaults(v, dest[k])
        elseif dest[k] == nil then dest[k] = v end
    end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        GU_GlobalDB = GU_GlobalDB or {}
        GU_CharDB = GU_CharDB or {}
        CopyDefaults(defaultGlobalDB, GU_GlobalDB)
        CopyDefaults(defaultCharDB, GU_CharDB)
        print("|cFF00FF00GuildUtils B1.1 Core Loaded.|r")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)