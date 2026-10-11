local addonName, GuildUtils = ...
GuildUtils.OutboundQueue = {}
GuildUtils.SyncThrottleTimer = nil

function GuildUtils:ProcessOutboundQueue()
    if #self.OutboundQueue == 0 then return end
    local payload = table.remove(self.OutboundQueue, 1)
    
    if payload.channel == "WHISPER" then 
        C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, "WHISPER", payload.target)
    else 
        C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, payload.channel) 
    end
end

function GuildUtils:QueueMessage(msg, specificChannel, target)
    local targetChannel = specificChannel or (IsInRaid() and "RAID" or "PARTY")
    table.insert(self.OutboundQueue, {msg = msg, channel = targetChannel, target = target})
    
    if not self.SyncThrottleTimer then
        self.SyncThrottleTimer = C_Timer.NewTicker(GuildUtils.Constants.THROTTLE_RATE, function()
            if #self.OutboundQueue > 0 then 
                GuildUtils:ProcessOutboundQueue()
            else
                self.SyncThrottleTimer:Cancel()
                self.SyncThrottleTimer = nil
            end
        end)
    end
end