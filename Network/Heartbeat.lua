local addonName, GuildUtils = ...
GuildUtils.Network = GuildUtils.Network or {}
GuildUtils.Host = nil
GuildUtils.HostTimeoutTimer = nil
GuildUtils.HeartbeatTicker = nil
GuildUtils.ElectionActive = false
GuildUtils.SoloMode = false

local f = CreateFrame("Frame")
C_ChatInfo.RegisterAddonMessagePrefix("GU_SYNC")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GROUP_LEFT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, function()
            GuildUtils:QueueMessage("GU_DISCOVER_HOST:req", "GUILD")
            C_Timer.After(3, function() if not GuildUtils.Host and not GuildUtils.ElectionActive then GuildUtils.Network:StartElection() end end)
        end)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == "GU_SYNC" then
            if UnitIsUnit(sender, "player") and not GuildUtils.SoloMode then return end
            GuildUtils.Network:OnMessageReceived(prefix, text, channel, GuildUtils:FormatName(sender))
        end
    elseif event == "GROUP_LEFT" then
        if not GuildUtils.SoloMode and GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then
            if GU_GlobalDB.Ledger.ActiveSession.leaderName == UnitName("player") then
                GuildUtils.LootCoin:EndGroupEvent()
            else
                GuildUtils:QueueMessage("SET_FREEZE:" .. UnitGUID("player") .. ":" .. UnitName("player") .. ":0", "GUILD")
            end
            GU_GlobalDB.Ledger.ActiveSession = nil
            GU_GlobalDB.Ledger.LocalSessionSpent = 0
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if GuildUtils.LootCoin and GuildUtils.LootCoin.ReconcileRoster then GuildUtils.LootCoin:ReconcileRoster(...) end
    end
end)

function GuildUtils:IsAuthoritativeHost() return self.Host == UnitName("player") or self.SoloMode end

function GuildUtils.Network:OnMessageReceived(prefix, text, channel, senderName)
    local command, payload = string.match(text, "^([^:]+):(.*)$")
    command, payload = command or text, payload or ""

    if command == "GU_DISCOVER_HOST" then
        if GuildUtils:IsAuthoritativeHost() then GuildUtils:QueueMessage("GU_HOST_ANNOUNCE:" .. (GU_GlobalDB.Ledger.version or 0), "GUILD") end
    elseif command == "GU_HOST_ANNOUNCE" or command == "HEARTBEAT" then self:AcknowledgeHeartbeat(senderName, tonumber(payload) or 0)
    elseif command == "REQ_SYNC" then if GuildUtils:IsAuthoritativeHost() then self:SendLedgerSyncPayload(senderName) end
    elseif command == "SYNC_CHUNK" then self:ReceiveLedgerSyncChunk(payload)
    elseif command == "ELECTION" then
        local rankStr, verStr, guidStr = strsplit(":", payload)
        self:ProcessElection(senderName, tonumber(rankStr), tonumber(verStr), guidStr)
    elseif command == "SET_FREEZE" then
        local tGuid, tName, tState = strsplit(":", payload)
        if GuildUtils.LootCoin then GuildUtils.LootCoin:ToggleManagementFreeze(tGuid, tName, true, tState) end
    elseif command == "FREEZE_GROUP" then
        if GuildUtils.LootCoin then GuildUtils.LootCoin:ProcessGroupFreeze(payload) end
    elseif command == "MERGE_GROUP" then
        if GuildUtils.LootCoin then GuildUtils.LootCoin:ProcessGroupMerge(payload) end
    elseif command == "MERGE_ACK" then
        if GuildUtils.LootCoin then GuildUtils.LootCoin:ReceiveMergeAck(payload) end
    elseif command == "NOTIFY_GROUP" then
        if payload == "START" then
            if GU_GlobalDB and GU_GlobalDB.Ledger then GU_GlobalDB.Ledger.LocalSessionSpent = 0 end
            GuildUtils:Print("The loot event has started! Balances are frozen.", false)
        else GuildUtils:Print(payload, false) end
    elseif command == "START_QUEUE" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:ClientStartQueue(payload) end
    elseif command == "NEXT_ITEM" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:ClientAdvanceQueue(tonumber(payload)) end
    elseif command == "QUEUE_FINISHED" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:ClientFinishQueue() end
    elseif command == "BID_INTENT" then
        if GuildUtils:IsMasterLootActive() and GuildUtils.PartyRoller then GuildUtils.PartyRoller:HostProcessBid(senderName, payload) end
    elseif command == "BID_CONFIRMED" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:OnBidConfirmed(payload) end
    elseif command == "BID_REJECTED" then
        local targetGuid, reason = strsplit(":", payload)
        if targetGuid == UnitGUID("player") then GuildUtils:Print("Bid Rejected: " .. reason, true) end
    elseif command == "RESULTS_CLOSED" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:OnResultsClosed(senderName, tonumber(payload)) end
    end
end

function GuildUtils.Network:AcknowledgeHeartbeat(hostName, hostLedgerVersion)
    GuildUtils.ElectionActive = false
    GuildUtils.Host = hostName
    if GuildUtils.HeartbeatTicker then GuildUtils.HeartbeatTicker:Cancel(); GuildUtils.HeartbeatTicker = nil end
    if GuildUtils.HostTimeoutTimer then GuildUtils.HostTimeoutTimer:Cancel() end
    
    local myVersion = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
    if hostLedgerVersion > myVersion and not GuildUtils:IsAuthoritativeHost() then
        GuildUtils:QueueMessage("REQ_SYNC:" .. myVersion, "WHISPER", hostName)
    end
    
    local timeout = GuildUtils.Constants.HEARTBEAT_TIMEOUT or 12
    GuildUtils.HostTimeoutTimer = C_Timer.NewTicker(timeout, function()
        GuildUtils:Print("Host heartbeat lost. Initiating election.", true)
        self:StartElection()
    end)
    if GuildUtils.LootCoin and GuildUtils.LootCoin.PushPendingMerges then GuildUtils.LootCoin:PushPendingMerges() end
end

function GuildUtils.Network:StartElection()
    GuildUtils.ElectionActive = true
    local rankIndex = GuildControlGetNumRanks() or 10 
    if IsInGuild() then _, _, rankIndex = GetGuildInfo("player") end
    local localVersion = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
    GuildUtils:QueueMessage(string.format("ELECTION:%d:%d:%s", rankIndex, localVersion, UnitGUID("player")), "GUILD")
    C_Timer.After(3, function() self:ConcludeElection() end)
end

function GuildUtils.Network:ProcessElection(sender, senderRank, senderVersion, senderGuid)
    if not GuildUtils.ElectionActive then return end
    local myRank = GuildControlGetNumRanks() or 10
    if IsInGuild() then _, _, myRank = GetGuildInfo("player") end
    local myVersion = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
    if senderVersion > myVersion then GuildUtils.ElectionActive = false
    elseif senderVersion == myVersion then
        if senderRank < myRank then GuildUtils.ElectionActive = false 
        elseif senderRank == myRank and senderGuid < UnitGUID("player") then GuildUtils.ElectionActive = false end
    end
end

function GuildUtils.Network:ConcludeElection()
    if GuildUtils.ElectionActive then
        GuildUtils.ElectionActive = false
        GuildUtils.Host = UnitName("player")
        GuildUtils:Print("Election won. Assuming Authoritative Host role.", false)
        if GuildUtils.HostTimeoutTimer then GuildUtils.HostTimeoutTimer:Cancel(); GuildUtils.HostTimeoutTimer = nil end
        if GuildUtils.HeartbeatTicker then GuildUtils.HeartbeatTicker:Cancel() end
        local interval = (GU_GlobalDB and GU_GlobalDB.Settings and GU_GlobalDB.Settings.HeartbeatRate) or 5
        GuildUtils.HeartbeatTicker = C_Timer.NewTicker(interval, function() GuildUtils:QueueMessage("HEARTBEAT:" .. (GU_GlobalDB.Ledger.version or 0), "GUILD") end)
    end
end