local addonName, GuildUtils = ...
GuildUtils.Network = GuildUtils.Network or {}
GuildUtils.Host = nil
GuildUtils.HostTimeoutTimer = nil
GuildUtils.HeartbeatTicker = nil
GuildUtils.ElectionActive = false
GuildUtils.SoloMode = false
GuildUtils.Network.SyncBuffer = {}
GuildUtils.Network.ExpectedChunks = 0

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
    elseif command == "EVENT_ADD" then
        local idStr, title, dateStr, timeStr, maxSizeStr = strsplit(":", payload)
        local id = tonumber(idStr)
        local exists = false
        for _, ev in ipairs(GU_GlobalDB.Events.list or {}) do
            if ev.id == id then exists = true; break end
        end
        if not exists then
            table.insert(GU_GlobalDB.Events.list, {
                id = id, title = title, date = dateStr, time = timeStr, maxSize = tonumber(maxSizeStr) or 40, roster = {}
            })
            if GuildUtils.Events.UpdateEventList then GuildUtils.Events:UpdateEventList() end
        end
    elseif command == "EVENT_SIGNUP" then
        local eventIdStr, guid, name, role = strsplit(":", payload)
        local eventId = tonumber(eventIdStr)
        for _, event in ipairs(GU_GlobalDB.Events.list) do
            if event.id == eventId then
                event.roster[guid] = { name = name, role = role }
                if GuildUtils.Events.SelectedEventId == eventId and GuildUtils.Events.UpdateEventDetails then
                    GuildUtils.Events:UpdateEventDetails(event)
                end
                break
            end
        end
    elseif command == "EVENT_WITHDRAW" then
        local eventIdStr, guid = strsplit(":", payload)
        local eventId = tonumber(eventIdStr)
        for _, event in ipairs(GU_GlobalDB.Events.list) do
            if event.id == eventId and event.roster then
                event.roster[guid] = nil
                if GuildUtils.Events.SelectedEventId == eventId and GuildUtils.Events.UpdateEventDetails then
                    GuildUtils.Events:UpdateEventDetails(event)
                end
                break
            end
        end
    elseif command == "EVENT_DELETE" then
        local eventId = tonumber(payload)
        for i, event in ipairs(GU_GlobalDB.Events.list or {}) do
            if event.id == eventId then
                table.remove(GU_GlobalDB.Events.list, i)
                if GuildUtils.Events.SelectedEventId == eventId then
                    GuildUtils.Events.SelectedEventId = nil
                    if GuildUtils.Events.UpdateEventDetails then
                        GuildUtils.Events.Container.eventTitle:SetText("No Event Selected")
                        GuildUtils.Events.Container.eventInfo:SetText("Select an event from the list to view details.")
                        if GuildUtils.Events.RosterRows then
                            for _, r in ipairs(GuildUtils.Events.RosterRows) do r:Hide() end
                        end
                    end
                end
                if GuildUtils.Events.UpdateEventList then GuildUtils.Events:UpdateEventList() end
                break
            end
        end
    elseif command == "QUEST_CLAIM" then
        local targetGuid, targetName, rewardStr = strsplit(":", payload)
        local reward = tonumber(rewardStr) or 0
        if GuildUtils:IsAuthoritativeHost() and GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
            GuildUtils.LootCoin:ProcessTransaction(targetGuid, targetName, reward, "Dungeon/Guild Quest Reward")
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

function GuildUtils.Network:SendLedgerSyncPayload(target)
    if not GuildUtils:IsAuthoritativeHost() then return end
    
    local parts = {}
    for guid, bal in pairs(GU_GlobalDB.Ledger.balances) do
        local name = GU_GlobalDB.Ledger.roster[guid] or "Unknown"
        local freeze = GU_GlobalDB.Ledger.frozenAccounts[guid] or "N"
        local join = GU_GlobalDB.Ledger.joinDates and GU_GlobalDB.Ledger.joinDates[guid] or 0
        table.insert(parts, string.format("%s@@%s@@%d@@%s@@%d", guid, name, bal, freeze, join))
    end
    
    local fullData = string.format("%d||%s", GU_GlobalDB.Ledger.version or 1, table.concat(parts, "::"))
    
    local chunkSize = 200
    local chunks = {}
    for i = 1, #fullData, chunkSize do
        table.insert(chunks, string.sub(fullData, i, i + chunkSize - 1))
    end
    
    local total = #chunks
    for i, chunkData in ipairs(chunks) do
        local msg = string.format("%d:%d:%s", total, i, chunkData)
        GuildUtils:QueueMessage("SYNC_CHUNK:" .. msg, "WHISPER", target)
    end
    
    GuildUtils:Print("Dispatched ledger sync payload to " .. target .. " in " .. total .. " chunks.", false)
end

function GuildUtils.Network:ReceiveLedgerSyncChunk(payload)
    local totalStr, indexStr, data = string.match(payload, "^(%d+):(%d+):(.*)$")
    local total = tonumber(totalStr)
    local index = tonumber(indexStr)
    
    if not total or not index or not data then return end
    
    if index == 1 then
        self.SyncBuffer = {}
        self.ExpectedChunks = total
    end
    
    self.SyncBuffer[index] = data
    
    local received = 0
    for _ in pairs(self.SyncBuffer) do received = received + 1 end
    
    if received == self.ExpectedChunks then
        self:ProcessCompletedSync()
    end
end

function GuildUtils.Network:ProcessCompletedSync()
    local fullData = ""
    for i = 1, self.ExpectedChunks do
        fullData = fullData .. (self.SyncBuffer[i] or "")
    end
    
    self.SyncBuffer = {}
    self.ExpectedChunks = 0
    
    local versionStr, rosterBlob = string.match(fullData, "^(%d+)||?(.*)$")
    local newVersion = tonumber(versionStr) or 1
    
    if newVersion <= (GU_GlobalDB.Ledger.version or 0) then return end
    
    GU_GlobalDB.Ledger.balances = {}
    GU_GlobalDB.Ledger.roster = {}
    GU_GlobalDB.Ledger.frozenAccounts = {}
    GU_GlobalDB.Ledger.joinDates = {}
    GU_GlobalDB.Ledger.version = newVersion
    
    if rosterBlob and rosterBlob ~= "" then
        for entry in string.gmatch(rosterBlob, "([^::]+)") do
            local guid, name, balStr, freeze, joinStr = string.match(entry, "^(.*)@@(.*)@@(.*)@@(.*)@@(.*)$")
            if guid then
                GU_GlobalDB.Ledger.balances[guid] = tonumber(balStr) or 0
                GU_GlobalDB.Ledger.roster[guid] = name
                if freeze ~= "N" then GU_GlobalDB.Ledger.frozenAccounts[guid] = freeze end
                local join = tonumber(joinStr)
                if join and join > 0 then GU_GlobalDB.Ledger.joinDates[guid] = join end
            end
        end
    end
    
    GuildUtils:Print("Ledger successfully synchronized from Authoritative Host (v" .. newVersion .. ").", false)
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
        GuildUtils.Ledger:UpdateDisplay()
    end
end