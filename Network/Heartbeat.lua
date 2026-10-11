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

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, function()
            GuildUtils:QueueMessage("GU_DISCOVER_HOST:req", "GUILD")
            C_Timer.After(3, function()
                if not GuildUtils.Host and not GuildUtils.ElectionActive then GuildUtils.Network:StartElection() end
            end)
        end)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == "GU_SYNC" then
            if UnitIsUnit(sender, "player") and not GuildUtils.SoloMode then return end
            local senderName = GuildUtils:FormatName(sender)
            local myName = GuildUtils:FormatName(UnitName("player"))
            if senderName == myName and not GuildUtils.SoloMode then return end
            GuildUtils.Network:OnMessageReceived(prefix, text, channel, senderName)
        end
    end
end)

function GuildUtils:IsAuthoritativeHost() return self.Host == UnitName("player") or self.SoloMode end

function GuildUtils.Network:OnMessageReceived(prefix, text, channel, senderName)
    local command, payload = string.match(text, "^([^:]+):(.*)$")
    command, payload = command or text, payload or ""

    if command == "GU_DISCOVER_HOST" then
        if GuildUtils:IsAuthoritativeHost() then
            local ver = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
            GuildUtils:QueueMessage("GU_HOST_ANNOUNCE:" .. ver, "GUILD")
        end
    elseif command == "GU_HOST_ANNOUNCE" or command == "HEARTBEAT" then
        self:AcknowledgeHeartbeat(senderName, tonumber(payload) or 0)
    elseif command == "REQ_SYNC" then
        if GuildUtils:IsAuthoritativeHost() then
            self:SendLedgerSyncPayload(senderName)
        end
    elseif command == "SYNC_CHUNK" then
        self:ReceiveLedgerSyncChunk(payload)
    elseif command == "ELECTION" then
        local rankStr, verStr, guidStr = strsplit(":", payload)
        self:ProcessElection(senderName, tonumber(rankStr), tonumber(verStr), guidStr)
    elseif command == "SET_FREEZE" then
        local tGuid, tName, tState = strsplit(":", payload)
        if GuildUtils.LootCoin then GuildUtils.LootCoin:ToggleManagementFreeze(tGuid, tName, tState) end
    elseif command == "SET_ALT_LINK" then
        local aGuid, aName, mGuid, mName = strsplit(":", payload)
        if GU_GlobalDB and GU_GlobalDB.Ledger then
            GU_GlobalDB.Ledger.altMap[aGuid] = mGuid
            if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
        end
    elseif command == "SET_ALT_UNLINK" then
        local aGuid = payload
        if GU_GlobalDB and GU_GlobalDB.Ledger then
            GU_GlobalDB.Ledger.altMap[aGuid] = nil
            if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
        end
    elseif command == "START_ROLL" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:ClientStartRoll(payload) end
    elseif command == "BID_INTENT" then
        if GuildUtils:IsAuthoritativeHost() and GuildUtils.PartyRoller then 
            GuildUtils.PartyRoller:HostProcessBid(senderName, payload) 
        end
    elseif command == "BID_CONFIRMED" then
        if GuildUtils.PartyRoller then GuildUtils.PartyRoller:OnBidConfirmed(payload) end
    elseif command == "CONTRACT_NEW" or command == "CONTRACT_FULFILL" then
        if GuildUtils.Contracts and GuildUtils.Contracts.OnNetworkContract then
            GuildUtils.Contracts:OnNetworkContract(command, payload)
        end
    end
end

function GuildUtils.Network:AcknowledgeHeartbeat(hostName, hostLedgerVersion)
    GuildUtils.ElectionActive = false
    GuildUtils.Host = hostName
    if GuildUtils.HeartbeatTicker then GuildUtils.HeartbeatTicker:Cancel(); GuildUtils.HeartbeatTicker = nil end
    if GuildUtils.HostTimeoutTimer then GuildUtils.HostTimeoutTimer:Cancel() end
    
    local myVersion = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
    if hostLedgerVersion > myVersion and not GuildUtils:IsAuthoritativeHost() then
        if GuildUtils.Ledger and GuildUtils.Ledger.UpdateSyncIndicator then GuildUtils.Ledger:UpdateSyncIndicator("PENDING") end
        GuildUtils:QueueMessage("REQ_SYNC:" .. myVersion, "WHISPER", hostName)
    else
        if GuildUtils.Ledger and GuildUtils.Ledger.UpdateSyncIndicator then GuildUtils.Ledger:UpdateSyncIndicator("SYNCED") end
    end
    
    local timeout = (GuildUtils.Constants and GuildUtils.Constants.HEARTBEAT_TIMEOUT) or 25
    GuildUtils.HostTimeoutTimer = C_Timer.NewTicker(timeout, function()
        GuildUtils:Print("Host heartbeat lost. Initiating election.", true)
        if GuildUtils.Ledger and GuildUtils.Ledger.UpdateSyncIndicator then GuildUtils.Ledger:UpdateSyncIndicator("OFFLINE") end
        self:StartElection()
    end)
end

function GuildUtils.Network:SendLedgerSyncPayload(targetPlayer)
    if not GuildUtils:IsAuthoritativeHost() then return end
    for guid, bal in pairs(GU_GlobalDB.Ledger.balances) do
        local name = GU_GlobalDB.Ledger.roster[guid] or "Unknown"
        GuildUtils:QueueMessage(string.format("SYNC_CHUNK:BAL:%s:%d:%s", guid, bal, name), "WHISPER", targetPlayer)
    end
    for altGuid, mainGuid in pairs(GU_GlobalDB.Ledger.altMap) do
        GuildUtils:QueueMessage(string.format("SYNC_CHUNK:ALT:%s:%s", altGuid, mainGuid), "WHISPER", targetPlayer)
    end
    GuildUtils:QueueMessage("SYNC_CHUNK:VER:" .. GU_GlobalDB.Ledger.version, "WHISPER", targetPlayer)
end

function GuildUtils.Network:ReceiveLedgerSyncChunk(payload)
    local subCmd, arg1, arg2, arg3 = strsplit(":", payload)
    if subCmd == "BAL" then
        local guid, bal, name = arg1, tonumber(arg2) or 0, arg3
        GU_GlobalDB.Ledger.balances[guid] = bal
        GU_GlobalDB.Ledger.roster[guid] = name
    elseif subCmd == "ALT" then
        local altGuid, mainGuid = arg1, arg2
        GU_GlobalDB.Ledger.altMap[altGuid] = mainGuid
    elseif subCmd == "VER" then
        GU_GlobalDB.Ledger.version = tonumber(arg1) or GU_GlobalDB.Ledger.version
        if GuildUtils.Ledger and GuildUtils.Ledger.UpdateSyncIndicator then GuildUtils.Ledger:UpdateSyncIndicator("SYNCED") end
        if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
    end
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
        
        local interval = (GU_GlobalDB and GU_GlobalDB.Settings and GU_GlobalDB.Settings.HeartbeatRate) or 10
        GuildUtils.HeartbeatTicker = C_Timer.NewTicker(interval, function()
            local ver = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.version) or 0
            GuildUtils:QueueMessage("HEARTBEAT:" .. ver, "GUILD")
        end)
    end
end