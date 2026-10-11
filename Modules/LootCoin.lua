local addonName, GuildUtils = ...
GuildUtils.LootCoin = {}

function GuildUtils.LootCoin:GetEffectiveGuid(guid)
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.altMap then return guid end
    return GU_GlobalDB.Ledger.altMap[guid] or guid
end

function GuildUtils.LootCoin:ProcessTransaction(guid, playerName, amount, reason)
    amount = tonumber(amount) or 0
    if amount == 0 then return end
    
    local targetGuid = self:GetEffectiveGuid(guid)
    local targetName = GU_GlobalDB.Ledger.roster[targetGuid] or playerName
    GU_GlobalDB.Ledger.roster[targetGuid] = targetName
    
    if GU_GlobalDB.Ledger.frozenAccounts[targetGuid] then
        GuildUtils:Print("Transaction blocked: " .. targetName .. " is frozen.", true)
        return
    end

    local currentBalance = GU_GlobalDB.Ledger.balances[targetGuid] or 0
    local newBalance = math.max(0, currentBalance + amount)
    
    GU_GlobalDB.Ledger.balances[targetGuid] = newBalance
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    
    GuildUtils:AppendAuditLog(string.format("[%s] %s: %d LC (%s) - New Balance: %d", date("%Y-%m-%d %H:%M:%S"), targetName, amount, reason or "Manual", newBalance))
    GuildUtils:Print(string.format("Transaction: %s %d LC. Balance: %d", targetName, amount, newBalance), false)
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
    if GuildUtils:IsAuthoritativeHost() then GuildUtils:QueueMessage("HEARTBEAT:" .. GU_GlobalDB.Ledger.version, "GUILD") end
end

function GuildUtils.LootCoin:ToggleManagementFreeze(guid, playerName, fromSync, targetState)
    local targetGuid = self:GetEffectiveGuid(guid)
    local isCurrentlyFrozen = (GU_GlobalDB.Ledger.frozenAccounts[targetGuid] == "F")
    
    if fromSync then
        if targetState == "1" then GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = "F"
        elseif targetState == "0" then GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = nil
        else GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = isCurrentlyFrozen and nil or "F" end
    else
        local newState = isCurrentlyFrozen and "0" or "1"
        if newState == "1" then GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = "F"; GuildUtils:Print("Management freeze |F| applied to " .. tostring(playerName), true)
        else GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = nil; GuildUtils:Print("Management freeze |F| lifted for " .. tostring(playerName), false) end
        GuildUtils:QueueMessage("SET_FREEZE:" .. targetGuid .. ":" .. tostring(playerName) .. ":" .. newState, "GUILD")
    end
    
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
end

function GuildUtils.LootCoin:StartGroupEvent()
    local leaderGuid = UnitGUID("player")
    local leaderName = UnitName("player")
    GU_GlobalDB.Ledger.roster[leaderGuid] = leaderName
    
    GU_GlobalDB.Ledger.ActiveSession = { leaderName = leaderName, members = {} }
    GU_GlobalDB.Ledger.ActiveSession.members[leaderGuid] = { name = leaderName, start = GU_GlobalDB.Ledger.balances[leaderGuid] or 0, change = 0 }
    
    local members = { leaderGuid }
    if not GuildUtils.SoloMode then
        local prefix = IsInRaid() and "raid" or "party"
        local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, numGroup do
            local unit = prefix .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                table.insert(members, guid)
                GU_GlobalDB.Ledger.ActiveSession.members[guid] = { name = UnitName(unit), start = GU_GlobalDB.Ledger.balances[guid] or 0, change = 0 }
            end
        end
    end
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    if GuildUtils.SoloMode then channel = "GUILD" end
    GuildUtils:QueueMessage("NOTIFY_GROUP:START", channel)
    
    local payload = leaderGuid .. "@@" .. table.concat(members, ",")
    if not GuildUtils.SoloMode then GuildUtils:QueueMessage("FREEZE_GROUP:" .. payload, "GUILD") end
    self:ProcessGroupFreeze(payload)
    GuildUtils:Print("Temp ledger created and saved. Group event active.", false)
end

function GuildUtils.LootCoin:UpdateTempLedger(guid, amount)
    if GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members[guid] then
        GU_GlobalDB.Ledger.ActiveSession.members[guid].change = GU_GlobalDB.Ledger.ActiveSession.members[guid].change + amount
    end
end

function GuildUtils.LootCoin:EndGroupEvent()
    if not GU_GlobalDB.Ledger.ActiveSession then return end
    local changes = {}
    for guid, data in pairs(GU_GlobalDB.Ledger.ActiveSession.members) do
        if data.change ~= 0 then table.insert(changes, string.format("%s:%s:%d", guid, data.name, data.change)) end
    end
    
    local leaderName = GU_GlobalDB.Ledger.ActiveSession.leaderName
    local mergeID = tostring(time()) .. "-" .. leaderName
    local payload = mergeID .. "@@" .. leaderName .. "@@" .. table.concat(changes, ";;")
    
    GU_GlobalDB.Ledger.ActiveSession = nil
    if GuildUtils:IsAuthoritativeHost() then
        self:ProcessGroupMerge(payload)
        GuildUtils:Print("Group ended. Session merged directly by Authoritative Host.", false)
    else
        GU_GlobalDB.Ledger.PendingMerges[mergeID] = payload
        GuildUtils:Print("Group ended. Session data cached for merge.", false)
        self:PushPendingMerges()
    end
end

function GuildUtils.LootCoin:PushPendingMerges()
    if not GU_GlobalDB.Ledger.PendingMerges then return end
    local hasPending = false
    for mergeID, payload in pairs(GU_GlobalDB.Ledger.PendingMerges) do
        hasPending = true
        GuildUtils:QueueMessage("MERGE_GROUP:" .. payload, "GUILD")
    end
    if hasPending and not GuildUtils.Host and not GuildUtils.SoloMode then
        GuildUtils:Print("No active Host detected to receive merge. Initiating election...", true)
        GuildUtils.Network:StartElection()
    end
end

function GuildUtils.LootCoin:ReceiveMergeAck(mergeID)
    if GU_GlobalDB.Ledger.PendingMerges[mergeID] then
        GU_GlobalDB.Ledger.PendingMerges[mergeID] = nil
        GuildUtils:Print("Merge confirmed by Host. Cached payload cleared.", false)
    end
end

function GuildUtils.LootCoin:ProcessGroupFreeze(payload)
    local leaderGuid, guidsBlob = string.match(payload, "^(.*)@@(.*)$")
    if not leaderGuid then return end
    for guid in string.gmatch(guidsBlob, "([^,]+)") do
        local currentTag = GU_GlobalDB.Ledger.frozenAccounts[guid]
        if currentTag ~= "T" and currentTag ~= "F" then GU_GlobalDB.Ledger.frozenAccounts[guid] = (guid == leaderGuid) and "GL" or "G" end
    end
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
end

function GuildUtils.LootCoin:ProcessGroupMerge(payload)
    local mergeID, leaderName, changesBlob = string.match(payload, "^(.*)@@(.*)@@(.*)$")
    if not mergeID then return end
    if GU_GlobalDB.Ledger.ProcessedMerges[mergeID] then
        if GuildUtils:IsAuthoritativeHost() then GuildUtils:QueueMessage("MERGE_ACK:" .. mergeID, "GUILD") end
        return
    end
    if changesBlob and changesBlob ~= "" then
        for chunk in string.gmatch(changesBlob, "([^;;]+)") do
            local guid, name, changeStr = strsplit(":", chunk)
            local change = tonumber(changeStr) or 0
            if change ~= 0 then
                local current = GU_GlobalDB.Ledger.balances[guid] or 0
                GU_GlobalDB.Ledger.balances[guid] = math.max(0, current + change)
                GuildUtils:AppendAuditLog(string.format("[%s] %s: balance change after group ran by: %s (Change: %d)", date("%Y-%m-%d %H:%M:%S"), name, leaderName, change))
            end
        end
    end
    GU_GlobalDB.Ledger.ProcessedMerges[mergeID] = true
    for g, tag in pairs(GU_GlobalDB.Ledger.frozenAccounts) do
        if tag == "GL" or tag == "G" then GU_GlobalDB.Ledger.frozenAccounts[g] = nil end
    end
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    if GuildUtils:IsAuthoritativeHost() then
        if changesBlob ~= "" then GuildUtils:QueueMessage("NOTIFY_GUILD:" .. leaderName .. "'s group has returned we await news of their glory!!!!", "GUILD") end
        GuildUtils:QueueMessage("HEARTBEAT:" .. GU_GlobalDB.Ledger.version, "GUILD")
        GuildUtils:QueueMessage("MERGE_ACK:" .. mergeID, "GUILD")
    end
    self:ReceiveMergeAck(mergeID)
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
end

function GuildUtils.LootCoin:ReconcileRoster(...)
    if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then
        if not IsInGroup() and not GuildUtils.SoloMode then return end
        if UnitIsGroupLeader("player") then
            if GU_GlobalDB.Ledger.ActiveSession.leaderName ~= UnitName("player") then
                GU_GlobalDB.Ledger.ActiveSession.leaderName = UnitName("player")
                GuildUtils:Print("Previous group leader disconnected. You now control the active session.", true)
            end
            local prefix = IsInRaid() and "raid" or "party"
            local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
            local newMembers = {}
            for i = 1, numGroup do
                local unit = prefix .. i
                if UnitExists(unit) then
                    local guid = UnitGUID(unit)
                    if not GU_GlobalDB.Ledger.ActiveSession.members[guid] then
                        GU_GlobalDB.Ledger.ActiveSession.members[guid] = { name = UnitName(unit), start = GU_GlobalDB.Ledger.balances[guid] or 0, change = 0 }
                        table.insert(newMembers, guid)
                    end
                end
            end
            if #newMembers > 0 then
                local payload = UnitGUID("player") .. "@@" .. table.concat(newMembers, ",")
                self:ProcessGroupFreeze(payload)
                GuildUtils:QueueMessage("FREEZE_GROUP:" .. payload, "GUILD")
            end
        end
    end
end