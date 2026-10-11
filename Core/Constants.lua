local addonName, GuildUtils = ...
_G.GuildUtils = GuildUtils

GuildUtils.Constants = {
    HEARTBEAT_INTERVAL = 5,
    HEARTBEAT_TIMEOUT = 12,
    THROTTLE_RATE = 1.0,

    ChatAlerts = {
        Normal = { text = "[GuildUtils] %s", defaultColor = "00BFFF" },
        Election = { text = "[GuildUtils] %s", defaultColor = "FFD700" },
        ArchiveMissed = { text = "[GuildUtils] ARCHIVE MISSED: Log cap reached before officer sync.", defaultColor = "FFD700" },
        RollQueue = { text = "[GuildUtils] Roll queue started for [%s]. 30-second defense window active.", defaultColor = "00FF7F" },
    },
    
    StatusTags = {
        Host = { text = "[H]", defaultColor = "00FF7F" },
        GroupLeader = { text = "[GL]", defaultColor = "FF8C00" },
        InGroup = { text = "[G]", defaultColor = "FF8C00" },
        Freeze = { text = "[F]", defaultColor = "00BFFF" },
        Tampered = { text = "[T]", defaultColor = "FF4500" },
    },
    
    LedgerTags = {
        Reserved = { text = "[RESERVED]", defaultColor = "A335EE" },
        Prog = { text = "Reason: Raid Prog", defaultColor = "0070DD" },
        Event = { text = "Reason: Event Reward", defaultColor = "1EFF00" },
        GuildBank = { text = "Target: Guild Bank", defaultColor = "FFD100" },
    },
    
    Headers = {
        MainLedger = "GuildUtils: Ledger",
        RollQueue = "GuildUtils: Active Roll Queue",
        SettingsMain = "GuildUtils: Settings",
        SettingsAdmin = "GuildUtils Settings: Guild Administration",
        SettingsGeneral = "GuildUtils Settings: General Preferences",
        SettingsAppearance = "GuildUtils Settings: Appearance & Themes",
        AuditLog = "GuildUtils: Audit Log Archives",
    }
}