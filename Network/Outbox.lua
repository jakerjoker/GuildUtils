local addonName, GuildUtils = ...
GuildUtils.OutboundQueue = {}
GuildUtils.SyncThrottleTimer = nil

function GuildUtils:ProcessOutboundQueue()
    if #self.OutboundQueue == 0 then return end
    local payload = table.remove(self.OutboundQueue, 1)
    if self.SoloMode and payload.channel ~= "GUILD" and payload.channel ~= "WHISPER" then
        if self.Network then self.Network:OnMessageReceived("GU_SYNC", payload.msg, payload.channel, UnitName("player")) end
        return
    end
    if payload.channel == "WHISPER" then C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, "WHISPER", payload.target)
    else C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, payload.channel) end
end

function GuildUtils:QueueMessage(msg, specificChannel, target)
    if self.SoloMode and not specificChannel then
        if self.Network then self.Network:OnMessageReceived("GU_SYNC", msg, "PARTY", UnitName("player")) end
        return
    end
    local targetChannel = specificChannel or (IsInRaid() and "RAID" or "PARTY")
    table.insert(self.OutboundQueue, {msg = msg, channel = targetChannel, target = target})
    if not self.SyncThrottleTimer then
        self.SyncThrottleTimer = C_Timer.NewTicker(self.Constants.THROTTLE_RATE, function()
            if #self.OutboundQueue > 0 then self:ProcessOutboundQueue()
            else self.SyncThrottleTimer:Cancel(); self.SyncThrottleTimer = nil end
        end)
    end
end