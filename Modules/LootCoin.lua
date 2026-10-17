local addonName, GuildUtils = ...
GuildUtils.LootCoin = {}

function GuildUtils.LootCoin:Initialize()
    if not GU_GlobalDB then GU_GlobalDB = {} end
    if not GU_GlobalDB.Ledger then
        GU_GlobalDB.Ledger = {
            version = 1,
            balances = {},
            auditLog = {},
            frozenAccounts = {},
            roster = {},
            PendingMerges = {}
        }
    end
end

function GuildUtils.LootCoin:GetEffectiveGuid(guid)
    return guid
end

function GuildUtils.LootCoin:StartGroupEvent(eventName, linkedEventId, basePay, earlyBonus)
    self:Initialize()
    local leaderGuid = UnitGUID("player")
    local leaderName = UnitName("player")
    GU_GlobalDB.Ledger.roster[leaderGuid] = leaderName
    
    GU_GlobalDB.Ledger.ActiveSession = { 
        leaderName = leaderName, 
        groupName = eventName, 
        linkedEventId = linkedEventId,
        basePay = tonumber(basePay) or 0,
        earlyBonus = tonumber(earlyBonus) or 0,
        members = {} 
    }
    
    GU_GlobalDB.Ledger.ActiveSession.members[leaderGuid] = { 
        name = leaderName, 
        class = select(2, UnitClass("player")), 
        role = "Tank", 
        timeInInstance = 1801, 
        start = GU_GlobalDB.Ledger.balances[leaderGuid] or 0, 
        change = 0 
    }
    
    local members = { leaderGuid }
    if not GuildUtils.SoloMode then
        local prefix = IsInRaid() and "raid" or "party"
        local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, numGroup do
            local unit = prefix .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                table.insert(members, guid)
                GU_GlobalDB.Ledger.ActiveSession.members[guid] = { 
                    name = UnitName(unit), 
                    class = select(2, UnitClass(unit)), 
                    role = "DPS", 
                    timeInInstance = 1801, 
                    start = GU_GlobalDB.Ledger.balances[guid] or 0, 
                    change = 0 
                }
            end
        end
    end
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    if GuildUtils.SoloMode then channel = "GUILD" end
    
    GuildUtils:QueueMessage("NOTIFY_GROUP:START", channel)
    
    local payload = leaderGuid .. "@@" .. table.concat(members, ",")
    if not GuildUtils.SoloMode then 
        GuildUtils:QueueMessage("FREEZE_GROUP:" .. payload, "GUILD") 
    end
    
    self:ProcessGroupFreeze(payload)
    
    GuildUtils:Print("Temp ledger created and saved. Group event active.", false)
end

function GuildUtils.LootCoin:UpdateTempLedger(guid, amount)
    if GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members[guid] then
        GU_GlobalDB.Ledger.ActiveSession.members[guid].change = GU_GlobalDB.Ledger.ActiveSession.members[guid].change + amount
        GuildUtils:Print(string.format("Session Ledger: %s applied %d LC.", GU_GlobalDB.Ledger.ActiveSession.members[guid].name, amount), false)
        
        if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
            GuildUtils.Ledger:UpdateDisplay()
        end
    end
end

function GuildUtils.LootCoin:ProcessTransaction(guid, playerName, amount, reason)
    self:Initialize()
    
    amount = tonumber(amount) or 0
    if amount == 0 then return end
    
    if not guid and playerName then
        if playerName == UnitName("player") then
            guid = UnitGUID("player")
        else
            for knownGuid, name in pairs(GU_GlobalDB.Ledger.roster) do
                if name == playerName then
                    guid = knownGuid
                    break
                end
            end
        end
    end
    
    if not guid then 
        GuildUtils:Print("Transaction failed: Could not resolve GUID for player " .. tostring(playerName), true)
        return 
    end
    
    local currentBalance = GU_GlobalDB.Ledger.balances[guid] or 0
    local newBalance = currentBalance + amount
    
    if newBalance < 0 then
        newBalance = 0
    end
    
    GU_GlobalDB.Ledger.balances[guid] = newBalance
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    
    local timestamp = date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] %s (%s): %d LC (%s) - New Balance: %d", timestamp, playerName or "Unknown", guid, amount, reason or "No reason", newBalance)
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    
    GuildUtils:Print(string.format("LootCoin Transaction: %s %d LC (%s). Balance: %d", playerName, amount, reason, newBalance), false)
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
        GuildUtils.Ledger:UpdateDisplay()
    end
end

function GuildUtils.LootCoin:EndGroupEvent()
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.ActiveSession then return end
    
    local activeEventTitle = GU_GlobalDB.Ledger.ActiveSession.groupName or ""
    local linkedEventId = GU_GlobalDB.Ledger.ActiveSession.linkedEventId
    
    if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
        for _, ev in ipairs(GU_GlobalDB.Events.list) do
            if (linkedEventId and ev.id == linkedEventId) or (not linkedEventId and (ev.title == activeEventTitle or string.find(activeEventTitle, ev.title))) then
                if ev.timestamp then
                    ev.timestamp = ev.timestamp + 604800
                    ev.date = date("%m/%d", ev.timestamp)
                    ev.time = date("%I:%M %p", ev.timestamp)
                    ev.roster = {}
                    GuildUtils:Print(string.format("Raid event '%s' concluded. Rescheduled for %s.", ev.title, date("%b %d", ev.timestamp)), false)
                end
                break
            end
        end
    end

    local changes = {}
    for guid, data in pairs(GU_GlobalDB.Ledger.ActiveSession.members) do
        if data.change ~= 0 then
            table.insert(changes, string.format("%s:%s:%d", guid, data.name, data.change))
        end
    end
    
    local leaderName = GU_GlobalDB.Ledger.ActiveSession.leaderName
    local mergeID = tostring(time()) .. "-" .. leaderName
    local payload = mergeID .. "@@" .. leaderName .. "@@" .. table.concat(changes, ";;")
    
    GuildUtils.LastRaidResults = GU_GlobalDB.Ledger.ActiveSession.members
    local basePay = GU_GlobalDB.Ledger.ActiveSession.basePay or 0
    local earlyBonus = GU_GlobalDB.Ledger.ActiveSession.earlyBonus or 0
    
    GU_GlobalDB.Ledger.ActiveSession = nil
    
    -- FIXED: Force the idle panel linked event selector back to "None" the moment EndGroupEvent is triggered
    if GuildUtils.PartyRoller and GuildUtils.PartyRoller.ResetIdlePanel then
        GuildUtils.PartyRoller:ResetIdlePanel()
    end

    local isAuthHost = (GuildUtils.Host == UnitName("player")) or GuildUtils.SoloMode
    if isAuthHost then
        self:ProcessGroupMerge(payload)
        GuildUtils:Print("Group ended. Session merged directly by Authoritative Host.", false)
    else
        GU_GlobalDB.Ledger.PendingMerges[mergeID] = payload
        GuildUtils:Print("Group ended. Session data cached for merge.", false)
        self:PushPendingMerges()
    end

    if linkedEventId and GuildUtils.Verification and GuildUtils.Verification.ShowVerificationScreen then
        local eventDef = {id = linkedEventId, basePay = basePay, earlyBonus = earlyBonus}
        GuildUtils.Verification:ShowVerificationScreen(eventDef, GuildUtils.LastRaidResults)
    elseif GuildUtils.PartyRoller and GuildUtils.PartyRoller.ShowRaidResultsModal then
        GuildUtils.PartyRoller:ShowRaidResultsModal(GuildUtils.LastRaidResults)
    end
end

function GuildUtils.LootCoin:ProcessGroupFreeze(payload)
    self:Initialize()
    local leaderGuid, guidsBlob = string.match(payload, "^(.*)@@(.*)$")
    if not leaderGuid then return end
    for guid in string.gmatch(guidsBlob, "([^,]+)") do
        local currentTag = GU_GlobalDB.Ledger.frozenAccounts[guid]
        if currentTag ~= "T" and currentTag ~= "F" then
            GU_GlobalDB.Ledger.frozenAccounts[guid] = (guid == leaderGuid) and "GL" or "G"
        end
    end
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then 
        GuildUtils.Ledger:UpdateDisplay() 
    end
end

function GuildUtils.LootCoin:ProcessGroupMerge(payload)
    self:Initialize()
    local mergeID, leaderName, changesBlob = string.match(payload, "^([^@]*)@@([^@]*)@@(.*)$")
    if not changesBlob then return end
    
    for entry in string.gmatch(changesBlob, "([^;]+)") do
        local guid, name, changeStr = string.match(entry, "^([^:]+):([^:]+):([^:]+)$")
        local amount = tonumber(changeStr) or 0
        if guid and amount ~= 0 then
            GU_GlobalDB.Ledger.balances[guid] = (GU_GlobalDB.Ledger.balances[guid] or 0) + amount
            
            local timestamp = date("%Y-%m-%d %H:%M:%S")
            local logEntry = string.format("[%s] %s: Ledger reconciled by Host %s (Net Change: %d)", timestamp, name, leaderName, amount)
            table.insert(GU_GlobalDB.Ledger.auditLog, logEntry)
        end
    end
    
    for guid, tag in pairs(GU_GlobalDB.Ledger.frozenAccounts) do
        if tag == "GL" or tag == "G" then
            GU_GlobalDB.Ledger.frozenAccounts[guid] = nil
        end
    end
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
        GuildUtils.Ledger:UpdateDisplay()
    end
end

function GuildUtils.LootCoin:PushPendingMerges()
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.PendingMerges then return end
    local hasPending = false
    for mergeID, payload in pairs(GU_GlobalDB.Ledger.PendingMerges) do
        hasPending = true
        if not GuildUtils.SoloMode then 
            GuildUtils:QueueMessage("MERGE_GROUP:" .. payload, "GUILD") 
        end
        self:ProcessGroupMerge(payload)
    end
    if hasPending and not GuildUtils.Host and not GuildUtils.SoloMode and not GuildUtils.ElectionActive then
        GuildUtils:Print("No active Host detected to receive merge. Initiating emergency election...", true)
        GuildUtils:StartElection()
    end
end

function GuildUtils.LootCoin:ReceiveMergeAck(mergeID)
    self:Initialize()
    if GU_GlobalDB.Ledger.PendingMerges[mergeID] then
        GU_GlobalDB.Ledger.PendingMerges[mergeID] = nil
        GuildUtils:Print("Merge confirmed by Host. Cached payload cleared.", false)
    end
end