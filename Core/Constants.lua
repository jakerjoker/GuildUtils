local addonName, GuildUtils = ...
_G.GuildUtils = GuildUtils

GuildUtils.Constants = {
    HEARTBEAT_INTERVAL = 10,
    HEARTBEAT_TIMEOUT = 25,
    THROTTLE_RATE = 1.0,

    ChatAlerts = {
        Normal = { text = "[GuildUtils] %s", defaultColor = "00BFFF" },
        Election = { text = "[GuildUtils] %s", defaultColor = "FFD700" },
        RollQueue = { text = "[GuildUtils] %s", defaultColor = "00FF7F" },
    },
    
    StatusTags = {
        Host = { text = "[H]", defaultColor = "00FF7F" },
        GroupLeader = { text = "[GL]", defaultColor = "FF8C00" },
        InGroup = { text = "[G]", defaultColor = "FF8C00" },
        Freeze = { text = "[F]", defaultColor = "00BFFF" },
        Tampered = { text = "[T]", defaultColor = "FF4500" },
    }
}