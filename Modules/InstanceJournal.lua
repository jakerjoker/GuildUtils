-- ==============================================================================
-- WoW:Forever Add-on - GuildUtils
-- Module: Instance Journal & Crowd-Sourced Boss Ledger
-- ==============================================================================

local addonName, GuildUtils = ...
GuildUtils.InstanceJournal = GuildUtils.InstanceJournal or {}

-- Register the chat prefix for peer-to-peer ledger sync
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix("InstanceLedger")
end

-- Initialize permanent database storage
function GuildUtils.InstanceJournal:InitializeStorage()
    if not GU_GlobalDB then GU_GlobalDB = {} end
    if not GU_GlobalDB.InstanceJournal then
        GU_GlobalDB.InstanceJournal = {}
    end
end

local activeRunSession = nil

-- Event Tracking Frame
local ledgerTracker = CreateFrame("Frame")
ledgerTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
ledgerTracker:RegisterEvent("GROUP_ROSTER_UPDATE")
ledgerTracker:RegisterEvent("ENCOUNTER_END")
ledgerTracker:RegisterEvent("CHAT_MSG_ADDON")

ledgerTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        local inInstance, instanceType = IsInInstance()
        
        -- Core Requirement: Validate instance entry, ignore battlegrounds/arenas
        if inInstance and instanceType ~= "pvp" and instanceType ~= "arena" then
            local instanceName = select(1, GetInstanceInfo())
            local zoneName = GetRealZoneText()
            local isRaid = (instanceType == "raid")
            
            if instanceName and instanceName ~= "" then
                GuildUtils.InstanceJournal:InitializeStorage()
                
                -- Initialize or switch active session upon entering a new instance
                if not activeRunSession or activeRunSession.instanceName ~= instanceName then
                    if activeRunSession then
                        GuildUtils.InstanceJournal:FinalizeRun()
                    end
                    
                    activeRunSession = {
                        instanceName = instanceName,
                        zoneName = zoneName,
                        isRaid = isRaid,
                        bossKills = 0
                    }
                end
            end
        else
            -- Left instance, arena, or battleground
            if activeRunSession then
                GuildUtils.InstanceJournal:FinalizeRun()
                activeRunSession = nil
            end
        end
        
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        -- Increment temporary run table upon successful boss kill
        if activeRunSession and success == 1 then
            activeRunSession.bossKills = activeRunSession.bossKills + 1
        end
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "InstanceLedger" then
            GuildUtils.InstanceJournal:HandlePeerUpdate(message, sender)
        end
    end
end)

-- Finalize session and reconcile against permanent storage
function GuildUtils.InstanceJournal:FinalizeRun()
    if not activeRunSession then return end
    
    self:InitializeStorage()
    local db = GU_GlobalDB.InstanceJournal
    local name = activeRunSession.instanceName
    local currentKills = activeRunSession.bossKills
    
    local updated = false
    
    if not db[name] then
        db[name] = {
            instanceName = name,
            zoneName = activeRunSession.zoneName,
            isRaid = activeRunSession.isRaid,
            minBosses = currentKills,
            maxBosses = currentKills,
            totalRuns = 1,
            verified = 1 -- Initialize consensus tracker
        }
        updated = true
    else
        local entry = db[name]
        entry.totalRuns = (entry.totalRuns or 1) + 1
        
        -- Ratchet Logic for Minimums and Maximums
        if currentKills > 0 then
            if currentKills > entry.maxBosses then
                entry.minBosses = entry.maxBosses
                entry.maxBosses = currentKills
                entry.verified = 1 -- Bounds shifted, reset consensus
                updated = true
            elseif currentKills > entry.minBosses then
                entry.minBosses = currentKills
                entry.verified = 1
                updated = true
            end
        end
    end
    
    -- Trigger Dungeon Quest Validation (Raid events skipped)
    if GuildUtils.Contracts and GuildUtils.Contracts.ValidateDungeonRun then
        GuildUtils.Contracts:ValidateDungeonRun(name, currentKills, activeRunSession.isRaid)
    end
    
    -- Broadcast update if new thresholds were established
    if updated then
        self:BroadcastJournalUpdate(name)
    end
end

-- Broadcast safe updates across active available channels
function GuildUtils.InstanceJournal:BroadcastJournalUpdate(instanceName)
    local entry = GU_GlobalDB.InstanceJournal[instanceName]
    if not entry then return end
    
    -- Payload format: INSTANCE_DATA:Name:Min:Max:Runs:IsRaid
    local payload = string.format("INSTANCE_DATA:%s:%d:%d:%d:%s",
        entry.instanceName,
        entry.minBosses,
        entry.maxBosses,
        entry.totalRuns,
        tostring(entry.isRaid)
    )
    
    local channels = {"GUILD", "PARTY", "INSTANCE_CHAT"}
    if IsInRaid() then table.insert(channels, "RAID") end
    
    for _, chan in ipairs(channels) do
        -- Only broadcast to active channels the player is currently eligible for
        if (chan == "GUILD" and IsInGuild()) or 
           (chan == "PARTY" and UnitInParty("player") and not IsInRaid()) or 
           (chan == "RAID" and IsInRaid()) or 
           (chan == "INSTANCE_CHAT" and select(1, IsInInstance())) then
            C_ChatInfo.SendAddonMessage("InstanceLedger", payload, chan)
        end
    end
end

-- Enforce peer validation rules for incoming community updates
function GuildUtils.InstanceJournal:HandlePeerUpdate(message, sender)
    if not message then return end
    
    local prefix, name, minKills, maxKills, runs, isRaidStr = strsplit(":", message)
    if prefix ~= "INSTANCE_DATA" or not name then return end
    
    minKills = tonumber(minKills) or 0
    maxKills = tonumber(maxKills) or 0
    runs = tonumber(runs) or 0
    
    self:InitializeStorage()
    local db = GU_GlobalDB.InstanceJournal
    
    if not db[name] then
        db[name] = {
            instanceName = name,
            minBosses = minKills,
            maxBosses = maxKills,
            totalRuns = runs,
            isRaid = (isRaidStr == "true"),
            verified = 1
        }
    else
        local entry = db[name]
        
        -- Consensus Verification: Peer reports the exact same boundaries
        if maxKills == entry.maxBosses and minKills == entry.minBosses then
            entry.verified = (entry.verified or 1) + 1
            entry.totalRuns = math.max(entry.totalRuns, runs)
            
        -- Peer Ratchet Logic: Peer discovered a higher maximum
        elseif maxKills > entry.maxBosses then
            entry.minBosses = entry.maxBosses 
            entry.maxBosses = maxKills
            entry.totalRuns = math.max(entry.totalRuns, runs)
            entry.verified = 1 
            
        -- Peer Ratchet Logic: Peer discovered a higher minimum without breaking max
        elseif maxKills == entry.maxBosses and minKills > entry.minBosses then
            entry.minBosses = minKills
            entry.totalRuns = math.max(entry.totalRuns, runs)
            entry.verified = 1
        end
    end
end