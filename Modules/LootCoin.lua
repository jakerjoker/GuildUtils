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

function GuildUtils.LootCoin:StartGroupEvent(eventName)
    self:Initialize()
    local leaderGuid = UnitGUID("player")
    local leaderName = UnitName("player")
    GU_GlobalDB.Ledger.roster[leaderGuid] = leaderName
    
    GU_GlobalDB.Ledger.ActiveSession = { leaderName = leaderName, groupName = eventName, members = {} }
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
    end
end

function GuildUtils.LootCoin:EndGroupEvent()
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.ActiveSession then return end
    
    local activeEventTitle = GU_GlobalDB.Ledger.ActiveSession.groupName or ""
    if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
        for _, ev in ipairs(GU_GlobalDB.Events.list) do
            if ev.title == activeEventTitle or string.find(activeEventTitle, ev.title) then
                if ev.date then
                    local mm, dd = string.match(ev.date, "(%d+)/(%d+)")
                    if mm and dd then
                        local m = tonumber(mm)
                        local d = tonumber(dd) + 7
                        local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                        if d > (daysInMonth[m] or 30) then
                            d = d - (daysInMonth[m] or 30)
                            m = m + 1
                            if m > 12 then m = 1 end
                        end
                        ev.date = string.format("%02d/%02d", m, d)
                        GuildUtils:Print(string.format("Raid event '%s' concluded. Rescheduled for %s.", ev.title, ev.date), false)
                    end
                end
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
    local linkedEventId = GU_GlobalDB.Ledger.ActiveSession.linkedEventId
    local basePay = GU_GlobalDB.Ledger.ActiveSession.basePay or 0
    local earlyBonus = GU_GlobalDB.Ledger.ActiveSession.earlyBonus or 0
    
    GU_GlobalDB.Ledger.ActiveSession = nil
    
    local isAuthHost = (GuildUtils.Host == UnitName("player")) or GuildUtils.SoloMode
    if isAuthHost then
        self:ProcessGroupMerge(payload)
        GuildUtils:Print("Group ended. Session merged directly by Authoritative Host.", false)
    else
        GU_GlobalDB.Ledger.PendingMerges[mergeID] = payload
        GuildUtils:Print("Group ended. Session data cached for merge.", false)
        self:PushPendingMerges()
    end

    -- FIXED: Trigger verification screen in both Solo Mode and live groups
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
            -- FIXED: Correctly tag Raid Leaders / Group Leaders as GL and members as G
            GU_GlobalDB.Ledger.frozenAccounts[guid] = (guid == leaderGuid) and "GL" or "G"
        end
    end
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then 
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) 
    end
end

function GuildUtils.LootCoin:ProcessGroupMerge(payload)
    self:Initialize()
    local mergeID, leaderName, changesBlob = string.match(payload, "^([^@]*)@@([^@]*)@@(.*)$")
    if not changesBlob then return end
    
    -- Apply net changes to master balances
    for entry in string.gmatch(changesBlob, "([^;]+)") do
        local guid, name, changeStr = string.match(entry, "^([^:]+):([^:]+):([^:]+)$")
        local amount = tonumber(changeStr) or 0
        if guid and amount ~= 0 then
            GU_GlobalDB.Ledger.balances[guid] = (GU_GlobalDB.Ledger.balances[guid] or 0) + amount
        end
    end
    
    -- Clear group lock tags
    for guid, tag in pairs(GU_GlobalDB.Ledger.frozenAccounts) do
        if tag == "GL" or tag == "G" then
            GU_GlobalDB.Ledger.frozenAccounts[guid] = nil
        end
    end
    
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText())
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
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then 
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) 
    end
end

function GuildUtils.LootCoin:ProcessGroupMerge(payload)
    self:Initialize()
end

function GuildUtils.LootCoin:GetEffectiveGuid(guid)
    return guid
end