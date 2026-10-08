local addonName, GuildUtils = ...

GuildUtils.LootCoin = {}
GuildUtils.LootCoin.SessionKey = math.random(100000, 999999) -- Anti-Cheat Session Key

function GuildUtils.LootCoin:Initialize()
    if not GuildUtilsDB then GuildUtilsDB = {} end
    if not GuildUtilsDB.Ledger then
        GuildUtilsDB.Ledger = {
            version = 1, balances = {}, auditLog = {}, frozenAccounts = {},
            LocalSessionSpent = 0, ActiveSession = nil, PendingMerges = {},
            ProcessedMerges = {}, roster = {}, PENDING_CONSENSUS = false, PENDING_LOG_EXPORT = false
        }
    end
    if not GuildUtilsDB.Ledger.balances then GuildUtilsDB.Ledger.balances = {} end
    if not GuildUtilsDB.Ledger.auditLog then GuildUtilsDB.Ledger.auditLog = {} end
    if not GuildUtilsDB.Ledger.frozenAccounts then GuildUtilsDB.Ledger.frozenAccounts = {} end
    if not GuildUtilsDB.Ledger.LocalSessionSpent then GuildUtilsDB.Ledger.LocalSessionSpent = 0 end
    if not GuildUtilsDB.Ledger.PendingMerges then GuildUtilsDB.Ledger.PendingMerges = {} end
    if not GuildUtilsDB.Ledger.ProcessedMerges then GuildUtilsDB.Ledger.ProcessedMerges = {} end
    if not GuildUtilsDB.Ledger.roster then GuildUtilsDB.Ledger.roster = {} end
    if GuildUtilsDB.Ledger.PENDING_CONSENSUS == nil then GuildUtilsDB.Ledger.PENDING_CONSENSUS = false end
    if GuildUtilsDB.Ledger.PENDING_LOG_EXPORT == nil then GuildUtilsDB.Ledger.PENDING_LOG_EXPORT = false end
end

function GuildUtils.LootCoin:BootstrapLedger()
    self:Initialize()
    if not IsInGuild() then return end
    
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        -- The modern WoW API returns the GUID as the 17th argument
        local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        
        if name and guid then
            -- Strip the connected realm name for cleaner UI display
            local cleanName = string.match(name, "([^%-]+)") or name
            GuildUtilsDB.Ledger.roster[guid] = cleanName
            
            if not GuildUtilsDB.Ledger.balances[guid] then
                GuildUtilsDB.Ledger.balances[guid] = 0
            end
        end
    end
    GuildUtils:Print("LootCoin ledger bootstrapped successfully.", false)
end

function GuildUtils.LootCoin:ProcessTransaction(guid, playerName, amount, reason)
    self:Initialize()
    amount = tonumber(amount) or 0
    if amount == 0 then return end
    
    if guid and playerName then GuildUtilsDB.Ledger.roster[guid] = playerName end
    local currentBalance = GuildUtilsDB.Ledger.balances[guid] or 0
    local newBalance = math.max(0, currentBalance + amount)
    
    GuildUtilsDB.Ledger.balances[guid] = newBalance
    GuildUtilsDB.Ledger.version = (GuildUtilsDB.Ledger.version or 1) + 1
    
    local timestamp = date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] %s (%s): %d LC (%s) - New Balance: %d", timestamp, playerName or "Unknown", guid, amount, reason or "No reason", newBalance)
    table.insert(GuildUtilsDB.Ledger.auditLog, entry)
    
    -- Overflow Buffers
    if #GuildUtilsDB.Ledger.auditLog > 300 then
        GuildUtilsDB.Ledger.auditLog = {"[EMERGENCY] Audit Log auto roll over check with regular members for save otherwise last 300 entries were not archived!!!"}
        if GuildUtils.LedgerFrame then
            GuildUtils.LedgerFrame.currentView = "AUDIT"
            GuildUtils.LedgerFrame:Show()
            GuildUtils:UpdateLedgerDisplay()
        end
    elseif #GuildUtilsDB.Ledger.auditLog > 200 then
        GuildUtilsDB.Ledger.PENDING_LOG_EXPORT = true
    end

    GuildUtils:Print(string.format("Transaction: %s %d LC. Balance: %d", playerName, amount, newBalance), false)
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
end

function GuildUtils.LootCoin:CheckAuditLogTrigger() self:Initialize() end

function GuildUtils.LootCoin:ValidateConsensus()
    self:Initialize()
    if not GuildUtils.Host then
        GuildUtilsDB.Ledger.PENDING_CONSENSUS = true
        GuildUtils:Print("Transaction logged offline. Flagged for PENDING_CONSENSUS verification.", true)
    else
        GuildUtilsDB.Ledger.PENDING_CONSENSUS = false
    end
end

function GuildUtils.LootCoin:PerformFactoryReset(sender)
    self:Initialize()
    GuildUtilsDB.Ledger = {
        version = (GuildUtilsDB.Ledger.version or 1) + 1000.0,
        balances = {}, auditLog = {}, frozenAccounts = {}, LocalSessionSpent = 0,
        ActiveSession = nil, PendingMerges = {}, ProcessedMerges = {}, roster = {},
        PENDING_CONSENSUS = false, PENDING_LOG_EXPORT = false
    }
    
    -- Force the ledger to repopulate immediately after the data is wiped
    self:BootstrapLedger()
    
    GuildUtils:Print(string.format("LootCoin ledger FACTORY RESET by %s.", sender or "System"), true)
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText())
    end
end

hooksecurefunc(GuildUtils.LootCoin, "ProcessTransaction", function(self, guid, playerName, amount, reason)
    if GuildUtilsDB.Ledger.frozenAccounts and GuildUtilsDB.Ledger.frozenAccounts[guid] then
        local tag = GuildUtilsDB.Ledger.frozenAccounts[guid]
        local reasonMsg = "frozen by unknown status"
        if tag == "T" then reasonMsg = "flagged for file tampering"
        elseif tag == "F" then reasonMsg = "frozen by management"
        elseif tag == "GL" or tag == "G" then reasonMsg = "in an active group event" end

        GuildUtils:Print("Transaction blocked: " .. playerName .. " is " .. reasonMsg .. ".", true)
        GuildUtilsDB.Ledger.balances[guid] = GuildUtilsDB.Ledger.balances[guid] - amount
        table.remove(GuildUtilsDB.Ledger.auditLog) 
        
        if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then
            GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText())
        end
    end
end)

-- Absolute State Network Implementation
function GuildUtils.LootCoin:ToggleManagementFreeze(guid, playerName, fromSync, targetState)
    self:Initialize()
    if not GuildUtilsDB.Ledger.frozenAccounts then GuildUtilsDB.Ledger.frozenAccounts = {} end
    
    guid = tostring(guid or ""):gsub("%s+", "")
    if guid == "" then return end

    local isCurrentlyFrozen = (GuildUtilsDB.Ledger.frozenAccounts[guid] == "F")

    if fromSync then
        -- STRIP invisible network characters (this was causing the bug)
        targetState = tostring(targetState or ""):gsub("%s+", "")
        
        -- Process absolute state payload (1 = Freeze, 0 = Unfreeze)
        if targetState == "1" then
            GuildUtilsDB.Ledger.frozenAccounts[guid] = "F"
        elseif targetState == "0" then
            GuildUtilsDB.Ledger.frozenAccounts[guid] = nil
        else
            -- Fallback for legacy blind toggles from un-updated guild members
            GuildUtilsDB.Ledger.frozenAccounts[guid] = isCurrentlyFrozen and nil or "F"
        end
    else
        -- Initiate Local Click: Set the absolute target state we want
        local newState = isCurrentlyFrozen and "0" or "1"
        
        if newState == "1" then
            GuildUtilsDB.Ledger.frozenAccounts[guid] = "F"
            GuildUtils:Print("Management freeze |F| applied to " .. tostring(playerName), true)
        else
            GuildUtilsDB.Ledger.frozenAccounts[guid] = nil
            GuildUtils:Print("Management freeze |F| lifted for " .. tostring(playerName), false)
        end
        
        -- Broadcast the absolute state to the guild
        if not GuildUtils.SoloMode then
            GuildUtils:SendSync("SET_FREEZE:" .. guid .. ":" .. tostring(playerName) .. ":" .. newState, "GUILD")
        end
    end
    
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then 
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) 
    end
end

function GuildUtils.LootCoin:StartGroupEvent()
    self:Initialize()
    local leaderGuid = UnitGUID("player")
    local leaderName = UnitName("player")
    GuildUtilsDB.Ledger.roster[leaderGuid] = leaderName
    
    GuildUtilsDB.Ledger.ActiveSession = { leaderName = leaderName, members = {} }
    GuildUtilsDB.Ledger.ActiveSession.members[leaderGuid] = { name = leaderName, start = GuildUtilsDB.Ledger.balances[leaderGuid] or 0, change = 0 }
    
    local members = { leaderGuid }
    if not GuildUtils.SoloMode then
        local prefix = IsInRaid() and "raid" or "party"
        local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, numGroup do
            local unit = prefix .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                table.insert(members, guid)
                GuildUtilsDB.Ledger.ActiveSession.members[guid] = { name = UnitName(unit), start = GuildUtilsDB.Ledger.balances[guid] or 0, change = 0 }
            end
        end
    end
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    if GuildUtils.SoloMode then channel = "GUILD" end
    GuildUtils:SendSync("NOTIFY_GROUP:START", channel)
    
    local payload = leaderGuid .. "@@" .. table.concat(members, ",")
    
    if not GuildUtils.SoloMode then GuildUtils:SendSync("FREEZE_GROUP:" .. payload, "GUILD") end
    self:ProcessGroupFreeze(payload)
    
    GuildUtils:Print("Temp ledger created and saved. Group event active.", false)
end

function GuildUtils.LootCoin:UpdateTempLedger(guid, amount)
    if GuildUtilsDB.Ledger.ActiveSession and GuildUtilsDB.Ledger.ActiveSession.members[guid] then
        GuildUtilsDB.Ledger.ActiveSession.members[guid].change = GuildUtilsDB.Ledger.ActiveSession.members[guid].change + amount
        GuildUtils:Print(string.format("Session Ledger: %s applied %d LC.", GuildUtilsDB.Ledger.ActiveSession.members[guid].name, amount), false)
    end
end

function GuildUtils.LootCoin:EndGroupEvent()
    if not GuildUtilsDB.Ledger.ActiveSession then return end
    
    local changes = {}
    for guid, data in pairs(GuildUtilsDB.Ledger.ActiveSession.members) do
        if data.change ~= 0 then
            table.insert(changes, string.format("%s:%s:%d", guid, data.name, data.change))
        end
    end
    
    local leaderName = GuildUtilsDB.Ledger.ActiveSession.leaderName
    local mergeID = tostring(time()) .. "-" .. leaderName
    local payload = mergeID .. "@@" .. leaderName .. "@@" .. table.concat(changes, ";;")
    
    GuildUtilsDB.Ledger.ActiveSession = nil
    local isAuthHost = (GuildUtils.Host == UnitName("player")) or GuildUtils.SoloMode
    
    if isAuthHost then
        self:ProcessGroupMerge(payload)
        GuildUtils:Print("Group ended. Session merged directly by Authoritative Host.", false)
    else
        GuildUtilsDB.Ledger.PendingMerges[mergeID] = payload
        GuildUtils:Print("Group ended. Session data cached for merge.", false)
        self:PushPendingMerges()
    end
end

function GuildUtils.LootCoin:PushPendingMerges()
    if not GuildUtilsDB or not GuildUtilsDB.Ledger or not GuildUtilsDB.Ledger.PendingMerges then return end
    local hasPending = false
    for mergeID, payload in pairs(GuildUtilsDB.Ledger.PendingMerges) do
        hasPending = true
        if not GuildUtils.SoloMode then GuildUtils:SendSync("MERGE_GROUP:" .. payload, "GUILD") end
        self:ProcessGroupMerge(payload)
    end
    if hasPending and not GuildUtils.Host and not GuildUtils.SoloMode and not GuildUtils.ElectionActive then
        GuildUtils:Print("No active Host detected to receive merge. Initiating emergency election...", true)
        GuildUtils:StartElection()
    end
end

function GuildUtils.LootCoin:ReceiveMergeAck(mergeID)
    self:Initialize()
    if GuildUtilsDB.Ledger.PendingMerges[mergeID] then
        GuildUtilsDB.Ledger.PendingMerges[mergeID] = nil
        GuildUtils:Print("Merge confirmed by Host. Cached payload cleared.", false)
    end
end

function GuildUtils.LootCoin:ProcessGroupFreeze(payload)
    self:Initialize()
    local leaderGuid, guidsBlob = string.match(payload, "^(.*)@@(.*)$")
    if not leaderGuid then return end
    for guid in string.gmatch(guidsBlob, "([^,]+)") do
        local currentTag = GuildUtilsDB.Ledger.frozenAccounts[guid]
        if currentTag ~= "T" and currentTag ~= "F" then
            GuildUtilsDB.Ledger.frozenAccounts[guid] = (guid == leaderGuid) and "GL" or "G"
        end
    end
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
end

function GuildUtils.LootCoin:ProcessGroupMerge(payload)
    self:Initialize()
    local mergeID, leaderName, changesBlob = string.match(payload, "^(.*)@@(.*)@@(.*)$")
    if not mergeID then return end
    if GuildUtilsDB.Ledger.ProcessedMerges[mergeID] then
        if GuildUtils.Host == UnitName("player") then GuildUtils:SendSync("MERGE_ACK:" .. mergeID, "GUILD") end
        return
    end
    if changesBlob and changesBlob ~= "" then
        for chunk in string.gmatch(changesBlob, "([^;;]+)") do
            local guid, name, changeStr = strsplit(":", chunk)
            local change = tonumber(changeStr) or 0
            if change ~= 0 then
                local current = GuildUtilsDB.Ledger.balances[guid] or 0
                GuildUtilsDB.Ledger.balances[guid] = math.max(0, current + change)
                local timestamp = date("%Y-%m-%d %H:%M:%S")
                local logEntry = string.format("[%s] %s: balance change after group ran by: %s (Change: %d)", timestamp, name, leaderName, change)
                table.insert(GuildUtilsDB.Ledger.auditLog, logEntry)
            end
        end
    end
    GuildUtilsDB.Ledger.ProcessedMerges[mergeID] = true
    for g, tag in pairs(GuildUtilsDB.Ledger.frozenAccounts) do
        if tag == "GL" or tag == "G" then GuildUtilsDB.Ledger.frozenAccounts[g] = nil end
    end
    GuildUtilsDB.Ledger.version = (GuildUtilsDB.Ledger.version or 1) + 1
    if GuildUtils.Host == UnitName("player") then
        if changesBlob ~= "" then GuildUtils:SendSync("NOTIFY_GUILD:" .. leaderName .. "'s group has returned we await news of their glory!!!!", "GUILD") end
        GuildUtils:SendSync("HEARTBEAT:" .. GuildUtilsDB.Ledger.version, "GUILD")
        GuildUtils:SendSync("MERGE_ACK:" .. mergeID, "GUILD")
    end
    self:ReceiveMergeAck(mergeID) 
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
end

GuildUtils.IncomingSyncBuffer = ""
function GuildUtils.LootCoin:SendLedgerSync(requesterName)
    local version = GuildUtilsDB.Ledger.version or 1
    local dataParts = {}
    for guid, bal in pairs(GuildUtilsDB.Ledger.balances) do table.insert(dataParts, guid .. "=" .. bal) end
    local fullString = table.concat(dataParts, ";")
    local chunkSize = 200
    local chunks = {}
    for i = 1, #fullString, chunkSize do table.insert(chunks, string.sub(fullString, i, i + chunkSize - 1)) end
    GuildUtils:SendSync(string.format("SYNC_START:%d:%d", version, #chunks), "WHISPER", requesterName)
    for i, chunk in ipairs(chunks) do GuildUtils:SendSync(string.format("SYNC_CHUNK:%d:%s", i, chunk), "WHISPER", requesterName) end
    GuildUtils:SendSync(string.format("SYNC_END:%d", version), "WHISPER", requesterName)
    GuildUtils:Print("Ledger synchronization pushed to " .. requesterName .. ".", false)
end

function GuildUtils.LootCoin:ReceiveSyncStart(version, totalChunks) GuildUtils.IncomingSyncBuffer = "" end
function GuildUtils.LootCoin:ReceiveSyncChunk(index, chunkData) GuildUtils.IncomingSyncBuffer = GuildUtils.IncomingSyncBuffer .. chunkData end
function GuildUtils.LootCoin:ReceiveSyncEnd(version)
    local data = GuildUtils.IncomingSyncBuffer
    local newBalances = {}
    for pair in string.gmatch(data, "([^;]+)") do
        local guid, balStr = strsplit("=", pair)
        if guid and balStr then newBalances[guid] = tonumber(balStr) or 0 end
    end
    GuildUtilsDB.Ledger.balances = newBalances
    GuildUtilsDB.Ledger.version = tonumber(version) or GuildUtilsDB.Ledger.version
    GuildUtils.IncomingSyncBuffer = ""
    GuildUtils:Print("Ledger successfully synchronized with Host (Version: " .. GuildUtilsDB.Ledger.version .. ").", false)
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
end