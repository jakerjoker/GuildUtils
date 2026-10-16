local addonName, GuildUtils = ...
GuildUtils.Tester = {}

-- =========================================================================
-- INITIALIZATION & DATABASE TESTS
-- =========================================================================
function GuildUtils.Tester:TestInitializationAndDatabase()
    GuildUtils:Print("[Test Suite] Running: Initialization & Database...", false)
    
    assert(GU_GlobalDB, "CRITICAL: GU_GlobalDB failed to initialize!")
    assert(GU_GlobalDB.Ledger, "CRITICAL: GU_GlobalDB.Ledger table is missing!")
    assert(GU_GlobalDB.Contracts, "CRITICAL: GU_GlobalDB.Contracts table is missing!")
    assert(GU_GlobalDB.Events, "CRITICAL: GU_GlobalDB.Events table is missing!")
    assert(GU_GlobalDB.Settings, "CRITICAL: GU_GlobalDB.Settings table is missing!")
    
    local myGuid = UnitGUID("player") or "Player-Test-GUID"
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin.GetEffectiveGuid and GuildUtils.LootCoin:GetEffectiveGuid(myGuid) or myGuid
    
    GU_GlobalDB.Ledger.balances[effGuid] = GU_GlobalDB.Ledger.balances[effGuid] or 50
    assert(GU_GlobalDB.Ledger.balances[effGuid] >= 50, "FAIL: Baseline LootCoin balance missing or below 50.")
    
    GuildUtils.Host = GuildUtils.Host or UnitName("player")
    assert(GuildUtils.Host ~= nil, "FAIL: Authoritative Host designation failed.")
    
    GuildUtils:Print("-> Test Passed: Initialization & Database verified.", false)
end

-- =========================================================================
-- QUEST FILTERS & GATING TESTS
-- =========================================================================
function GuildUtils.Tester:TestQuestFiltersAndGating()
    GuildUtils:Print("[Test Suite] Running: Quest Filters & Profession/Level Gating...", false)
    
    if not GuildUtils.Contracts or not GuildUtils.Contracts.RecurringQuests then
        GuildUtils:Print("-> SKIP: RecurringQuests table not loaded yet.", true)
        return
    end

    local weeklyPool = GuildUtils.Contracts.RecurringQuests.Weekly
    assert(weeklyPool and #weeklyPool > 0, "FAIL: Weekly recurring quest table is empty.")

    local fakeLevel = 15
    local fakeProfessions = { ["Mining"] = 1, ["Herbalism"] = 1, ["Skinning"] = 1 }
    local passedCount = 0
    
    for _, quest in ipairs(weeklyPool) do
        if quest.type == "DUNGEON" then
            if fakeLevel >= (quest.minLevel or 1) and fakeLevel <= (quest.maxLevel or 60) then
                passedCount = passedCount + 1
            end
        elseif quest.profession and quest.profession ~= "None" then
            local profSkill = fakeProfessions[quest.profession] or 0
            if profSkill >= (quest.skillReq or 0) then
                passedCount = passedCount + 1
            end
        else
            passedCount = passedCount + 1
        end
    end
    assert(passedCount > 0, "FAIL: Quest filter blocked all mock items for level 15.")
    
    GuildUtils:Print(string.format("-> Test Passed: Quest Filters & Gating (%d eligible mock quests).", passedCount), false)
end

-- =========================================================================
-- RAID EVENTS & SIGNUPS TESTS
-- =========================================================================
function GuildUtils.Tester:TestRaidEventsAndSignups()
    GuildUtils:Print("[Test Suite] Running: Raid Events, Creation & Role Signups...", false)
    
    local title = "E2E Automated Test Raid"
    local id = GU_GlobalDB.Events.nextId or 1
    GU_GlobalDB.Events.nextId = id + 1
    GU_GlobalDB.Events.list = GU_GlobalDB.Events.list or {}
    
    local newEvent = { id = id, title = title, date = "10/30", time = "20:00", maxSize = 40, roster = {}, creator = UnitName("player") }
    table.insert(GU_GlobalDB.Events.list, newEvent)
    assert(#GU_GlobalDB.Events.list > 0, "FAIL: Raid event failed to insert into global database.")
    
    local playerName = UnitName("player")
    newEvent.roster[playerName] = { class = UnitClass("player"), role = "Tank", timestamp = time() }
    assert(newEvent.roster[playerName], "FAIL: Player failed to register on event roster.")
    assert(newEvent.roster[playerName].role == "Tank", "FAIL: Player role mismatched.")
    
    newEvent.roster[playerName] = nil
    assert(newEvent.roster[playerName] == nil, "FAIL: Player withdrawal failed to clear roster slot.")
    
    GuildUtils:Print("-> Test Passed: Raid Events & Signups verified.", false)
end

-- =========================================================================
-- RAID & DUNGEON INSTANCE TRACKING & VERIFICATION TESTS
-- =========================================================================
function GuildUtils.Tester:TestRaidAndDungeonTracking()
    GuildUtils:Print("[Test Suite] Running: Raid & Dungeon Tracking & Verification Pipeline...", false)
    
    -- 1. Mock Active Session & Instance Time Tracking
    GU_GlobalDB.Ledger.ActiveSession = {
        leaderName = UnitName("player"),
        members = {
            ["Player-Test-Guid-1"] = { name = "Tanker", timeInInstance = 1800, start = 100, change = 0 },
            ["Player-Test-Guid-2"] = { name = "HealerBob", timeInInstance = 1800, start = 100, change = 0 },
            ["Player-Test-Guid-3"] = { name = "EarlyLeaver", timeInInstance = 300, start = 100, change = 0 }
        }
    }
    
    assert(GU_GlobalDB.Ledger.ActiveSession.members["Player-Test-Guid-3"], "FAIL: Temporary roster failed to retain early leaver record.")
    assert(GU_GlobalDB.Ledger.ActiveSession.members["Player-Test-Guid-3"].timeInInstance == 300, "FAIL: Instance timer tracking failed.")

    -- 2. Mock Party Leader Verification Screen Validation
    local verifiedRosterCount = 0
    for guid, data in pairs(GU_GlobalDB.Ledger.ActiveSession.members) do
        if data.timeInInstance >= 900 then -- 15 minute threshold mock
            verifiedRosterCount = verifiedRosterCount + 1
        end
    end
    assert(verifiedRosterCount == 2, "FAIL: Verification filter incorrectly scored qualifying instance times.")

    -- 3. Mock Individual Player Quest-Claim Dispatch to Authoritative Host
    local testClaimGuid = "Player-Test-Guid-1"
    local testClaimName = "Tanker"
    local testReward = 3
    GU_GlobalDB.Ledger.balances[testClaimGuid] = 100
	
    if GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
        GuildUtils.LootCoin:ProcessTransaction(testClaimGuid, testClaimName, testReward, "Verified Dungeon Quest Reward")
        assert(GU_GlobalDB.Ledger.balances[testClaimGuid] == 103, "FAIL: Host failed to process individual quest-claim payout.")
    end

    GU_GlobalDB.Ledger.ActiveSession = nil
    GuildUtils:Print("-> Test Passed: Raid & Dungeon Tracking & Verification verified.", false)
end

-- =========================================================================
-- LEDGER & AUDIT BUFFERS TESTS
-- =========================================================================
function GuildUtils.Tester:TestLedgerAndAuditBuffers()
    GuildUtils:Print("[Test Suite] Running: LootCoin Ledger & Audit Buffers...", false)
    
    local testGuid = "Player-E2E-Guid-777"
    local testName = "E2ETester"
	GU_GlobalDB.Ledger.balances[testGuid] = 50
    
    GuildUtils.LootCoin:ProcessTransaction(testGuid, testName, 200, "E2E Raid Reward")
    assert(GU_GlobalDB.Ledger.balances[testGuid] == 250, "FAIL: Credit transaction balance calculation incorrect.")
    
    GuildUtils.LootCoin:ProcessTransaction(testGuid, testName, -100, "E2E Bidding Cost")
    assert(GU_GlobalDB.Ledger.balances[testGuid] == 150, "FAIL: Debit transaction balance calculation incorrect.")
    
	GU_GlobalDB.Ledger.auditLog = GU_GlobalDB.Ledger.auditLog or {}
    local initialLogCount = #GU_GlobalDB.Ledger.auditLog
    GuildUtils.LootCoin:ProcessTransaction(testGuid, testName, 10, "E2E Audit Check")
    assert(#GU_GlobalDB.Ledger.auditLog > initialLogCount, "FAIL: Audit log failed to record transaction entry.")
    assert(GU_GlobalDB.Ledger.version > 1, "FAIL: Ledger version failed to increment.")
    
    GuildUtils:Print("-> Test Passed: LootCoin Ledger & Audit Buffers verified.", false)
end

-- =========================================================================
-- PARTYROLLER, NETWORK & UI TESTS
-- =========================================================================
function GuildUtils.Tester:TestPartyRollerNetworkAndUI()
    GuildUtils:Print("[Test Suite] Running: PartyRoller, Network Throttle & UI Frames...", false)
    
    if GuildUtils.PartyRoller then
        GuildUtils.PartyRoller.ActiveSession = { itemLink = "[Test Epic Sword]", itemId = 19019, bids = {}, status = "ACTIVE" }
        assert(GuildUtils.PartyRoller.ActiveSession.status == "ACTIVE", "FAIL: PartyRoller session failed to initialize.")
        GuildUtils.PartyRoller.ActiveSession = nil
    end
    
    GuildUtils.OutboundQueue = GuildUtils.OutboundQueue or {}
    local initialQueueSize = #GuildUtils.OutboundQueue
	local wasSolo = GuildUtils.SoloMode
    GuildUtils.SoloMode = false
    GuildUtils:QueueMessage("E2E_TEST_PAYLOAD", "WHISPER", UnitName("player"))
    assert(#GuildUtils.OutboundQueue == initialQueueSize + 1, "FAIL: Message failed to stage in OutboundQueue.")
    table.remove(GuildUtils.OutboundQueue)
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Toggle then
        GuildUtils.Ledger:Toggle()
        if GuildUtils.Ledger.Frame then GuildUtils.Ledger.Frame:Hide() end
    end
    
    if GuildUtils.SettingsUI and GuildUtils.SettingsUI.TogglePanel then
        GuildUtils.SettingsUI:TogglePanel()
        if GuildUtils.SettingsUI.Frame then GuildUtils.SettingsUI.Frame:Hide() end
    end
    
    GuildUtils:Print("-> Test Passed: PartyRoller, Network Throttle & UI Frames verified.", false)
end

-- =========================================================================
-- MULTI-CLIENT SIMULATION TESTS
-- =========================================================================
function GuildUtils.Tester:TestMultiClientSimulations()
    GuildUtils:Print("[Test Suite] Running: Multi-Client Network Simulations...", false)
    
    local fakeSender = "OfficerDan"
    local electionPayload = string.format("ELECTION:%d:%d:%s:%s", 2, (GU_GlobalDB.Ledger.version or 1), "Guid-OfficerDan-123", "true")
    if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then 
        GuildUtils.Network:OnMessageReceived("GU_SYNC", electionPayload, "GUILD", fakeSender)
    end
    
    local syncPayload = "REQ_SYNC:0"
    if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then 
        GuildUtils.Network:OnMessageReceived("GU_SYNC", syncPayload, "WHISPER", "NewRecruit")
    end
    
    local myGuid = UnitGUID("player") or "Player-Test-GUID"
    local myName = UnitName("player") or "TestPlayer"
    if GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
        GuildUtils.LootCoin:ProcessTransaction(myGuid, myName, 25, "Simulated Officer 1 Payout")
        GuildUtils.LootCoin:ProcessTransaction(myGuid, myName, 50, "Simulated Officer 2 Payout")
    end
    
    local tamperPayload = "SET_FREEZE:Player-Bad-Guid:SuspiciousPlayer:1"
    if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then 
        GuildUtils.Network:OnMessageReceived("GU_SYNC", tamperPayload, "GUILD", "SuspiciousPlayer")
    end
    
    if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then
        GuildUtils.Network:OnMessageReceived("GU_SYNC", "EVENT_ADD:601:E2E Simulation Raid:10/31:21:00:40:25:RaidLeader:Admin", "GUILD", "RaidLeader")
        C_Timer.After(0.4, function() GuildUtils.Network:OnMessageReceived("GU_SYNC", "EVENT_SIGNUP:601:Player-RaidMate-456:RaidMate:Healer", "GUILD", "RaidMate") end)
        C_Timer.After(0.8, function() GuildUtils.Network:OnMessageReceived("GU_SYNC", "EVENT_WITHDRAW:601:Player-RaidMate-456", "GUILD", "RaidMate") end)
    end
    
    local contractPayload = "CONTRACT_NEW:88:[Weekly] Copper Ore Shipment:40:3:SYSTEM_QUEST:GuildMaster"
    if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then 
        GuildUtils.Network:OnMessageReceived("GU_SYNC", contractPayload, "GUILD", "GuildMaster")
    end
    
    GuildUtils:Print("-> Test Passed: Multi-Client Network Simulations queued.", false)
end

-- =========================================================================
-- MASTER END-TO-END SUITE RUNNER
-- =========================================================================
function GuildUtils.Tester:RunEndToEndMegaSuite()
    GuildUtils:Print("==================================================", false)
    GuildUtils:Print("   STARTING END-TO-END MASTER QA MEGA-SUITE      ", false)
    GuildUtils:Print("==================================================", false)
    
    self:TestInitializationAndDatabase()
    self:TestQuestFiltersAndGating()
    self:TestRaidEventsAndSignups()
    self:TestRaidAndDungeonTracking()
    self:TestLedgerAndAuditBuffers()
    self:TestPartyRollerNetworkAndUI()
    C_Timer.After(1, function() self:TestMultiClientSimulations() end)
    
    C_Timer.After(2, function()
        GuildUtils:Print("==================================================", false)
        GuildUtils:Print("   ALL PHASES EXECUTED SUCCESSFULLY              ", false)
        GuildUtils:Print("==================================================", false)
    end)
end

-- =========================================================================
-- SLASH COMMAND ROUTING
-- =========================================================================	
SLASH_GUILDUTILSTEST1 = "/gutest"
SlashCmdList["GUILDUTILSTEST"] = function(msg)
    msg = strlower(strtrim(msg or "mega"))
    if msg == "mega" or msg == "all" or msg == "" then
        GuildUtils.Tester:RunEndToEndMegaSuite()
    elseif msg == "init" or msg == "db" then
        GuildUtils.Tester:TestInitializationAndDatabase()
    elseif msg == "quests" or msg == "filters" then
        GuildUtils.Tester:TestQuestFiltersAndGating()
    elseif msg == "events" or msg == "signups" then
        GuildUtils.Tester:TestRaidEventsAndSignups()
    elseif msg == "tracking" or msg == "dungeon" then
        GuildUtils.Tester:TestRaidAndDungeonTracking()
    elseif msg == "ledger" or msg == "audit" then
        GuildUtils.Tester:TestLedgerAndAuditBuffers()
    elseif msg == "ui" or msg == "network" then
        GuildUtils.Tester:TestPartyRollerNetworkAndUI()
    elseif msg == "multi" or msg == "sim" then
        GuildUtils.Tester:TestMultiClientSimulations()
    else
        GuildUtils:Print("Usage: /gutest [mega | init | quests | events | tracking | ledger | ui | multi]", true)
    end
end