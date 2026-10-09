local addonName, GuildUtils = ...

GuildUtils.Constants = {
    -- Chat Notifications (Color Customizable)
    ChatAlerts = {
        Normal = { text = "[GuildUtils] %s", defaultColor = "00BFFF" },
        Election = { text = "[GuildUtils] %s", defaultColor = "FFD700" },
        ArchiveMissed = { text = "[GuildUtils] ARCHIVE MISSED: Log cap reached before officer sync. New sequence started.", defaultColor = "FFD700" },
        RollQueue = { text = "[GuildUtils] Roll queue started for [%s]. 30-second defense window active.", defaultColor = "00FF7F" },
    },
    
    -- Ledger Status Tags (Member States - Immutable Colors)
    StatusTags = {
        Host = { text = "[H]", defaultColor = "00FF7F" },
        GroupLeader = { text = "[GL]", defaultColor = "FF8C00" },
        InGroup = { text = "[G]", defaultColor = "FF8C00" },
        Freeze = { text = "[F]", defaultColor = "00BFFF" },
        Tampered = { text = "[T]", defaultColor = "FF4500" },
    },
    
    -- Ledger Tags
    LedgerTags = {
        Reserved = { text = "[RESERVED]", defaultColor = "A335EE" },
        Prog = { text = "Reason: Raid Prog", defaultColor = "0070DD" },
        Event = { text = "Reason: Event Reward", defaultColor = "1EFF00" },
        GuildBank = { text = "Target: Guild Bank", defaultColor = "FFD100" },
    },
    
    -- UI Headers & Text (Theme Locked)
    Headers = {
        MainLedger = "GuildUtils: Ledger",
        RollQueue = "GuildUtils: Active Roll Queue",
        SettingsMain = "GuildUtils: Settings",
        SettingsAdmin = "GuildUtils Settings: Guild Administration",
        SettingsGeneral = "GuildUtils Settings: General Preferences",
        SettingsAppearance = "GuildUtils Settings: Appearance & Themes",
        AuditLog = "GuildUtils: Audit Log Archives",
    },
    UIText = {
        Instruction = "Select a target member or route to Guild Bank to begin reserve tracking."
    }
}