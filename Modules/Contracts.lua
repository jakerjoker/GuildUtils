local addonName, GuildUtils = ...
GuildUtils.Contracts = {}

-- Master Recurring Quests Template (Weekly & Monthly)
GuildUtils.Contracts.RecurringQuests = {
    Weekly = {
        -- Gathering Quests (1-2 stacks, 1-3 LC)
        { item = "Linen Cloth", count = 40, reward = 1, minLevel = 1 },
        { item = "Copper Ore", count = 40, reward = 2, minLevel = 1 },
        { item = "Light Leather", count = 20, reward = 1, minLevel = 1 },
        { item = "Peacebloom", count = 20, reward = 1, minLevel = 1 },
        { item = "Silverleaf", count = 20, reward = 1, minLevel = 1 },
        { item = "Rough Stone", count = 40, reward = 1, minLevel = 1 },
        { item = "Raw Brilliant Smallfish", count = 20, reward = 1, minLevel = 1 },
        { item = "Wool Cloth", count = 40, reward = 2, minLevel = 12 },
        { item = "Tin Ore", count = 40, reward = 2, minLevel = 12 },
        { item = "Medium Leather", count = 20, reward = 2, minLevel = 15 },
        { item = "Earthroot", count = 20, reward = 1, minLevel = 1 },
        { item = "Mageroyal", count = 20, reward = 1, minLevel = 1 },
        { item = "Stranglekelp", count = 20, reward = 2, minLevel = 20 },
        { item = "Bruiseweed", count = 20, reward = 2, minLevel = 15 },
        { item = "Raw Longjaw Mud Snapper", count = 20, reward = 1, minLevel = 10 },
        { item = "Tigerseye", count = 20, reward = 1, minLevel = 1 },
        { item = "Shadowgem", count = 20, reward = 2, minLevel = 15 },
        { item = "Coarse Stone", count = 40, reward = 1, minLevel = 15 },
        { item = "Swiftthistle", count = 20, reward = 3, minLevel = 15 },
        { item = "Minor Bloodstone", count = 20, reward = 2, minLevel = 10 },
        
        -- Weekly Dungeon Quests (All Horde-Accessible Dungeons, 1 Run Req)
        { name = "Ragefire Chasm Clear", type = "DUNGEON", target = "Ragefire Chasm", minLevel = 12, maxLevel = 25, reward = 2 },
        { name = "Wailing Caverns Clear", type = "DUNGEON", target = "Wailing Caverns", minLevel = 15, maxLevel = 30, reward = 2 },
        { name = "Shadowfang Keep Clear", type = "DUNGEON", target = "Shadowfang Keep", minLevel = 18, maxLevel = 32, reward = 2 },
        { name = "Blackfathom Deeps Clear", type = "DUNGEON", target = "Blackfathom Deeps", minLevel = 20, maxLevel = 38, reward = 3 },
        { name = "Razorfen Kraul Clear", type = "DUNGEON", target = "Razorfen Kraul", minLevel = 29, maxLevel = 45, reward = 3 },
        { name = "Scarlet Monastery: Graveyard", type = "DUNGEON", target = "SM: Graveyard", minLevel = 26, maxLevel = 40, reward = 2 },
        { name = "Scarlet Monastery: Library", type = "DUNGEON", target = "SM: Library", minLevel = 29, maxLevel = 43, reward = 3 },
        { name = "Scarlet Monastery: Armory", type = "DUNGEON", target = "SM: Armory", minLevel = 32, maxLevel = 45, reward = 3 },
        { name = "Scarlet Monastery: Cathedral", type = "DUNGEON", target = "SM: Cathedral", minLevel = 35, maxLevel = 48, reward = 3 },
        { name = "Razorfen Downs Clear", type = "DUNGEON", target = "Razorfen Downs", minLevel = 35, maxLevel = 50, reward = 3 },
        { name = "Uldaman Clear", type = "DUNGEON", target = "Uldaman", minLevel = 38, maxLevel = 52, reward = 3 },
        { name = "Zul'Farrak Clear", type = "DUNGEON", target = "Zul'Farrak", minLevel = 42, maxLevel = 55, reward = 3 },
        { name = "Maraudon Clear", type = "DUNGEON", target = "Maraudon", minLevel = 45, maxLevel = 58, reward = 3 },
        { name = "Sunken Temple (ST) Clear", type = "DUNGEON", target = "Sunken Temple", minLevel = 50, maxLevel = 60, reward = 3 },
        { name = "Blackrock Depths (BRD) Clear", type = "DUNGEON", target = "Blackrock Depths", minLevel = 52, maxLevel = 60, reward = 3 },
        { name = "Lower Blackrock Spire (LBRS)", type = "DUNGEON", target = "LBRS", minLevel = 55, maxLevel = 60, reward = 3 },
        { name = "Scholomance Clear", type = "DUNGEON", target = "Scholomance", minLevel = 58, maxLevel = 60, reward = 3 },
        { name = "Stratholme Clear", type = "DUNGEON", target = "Stratholme", minLevel = 58, maxLevel = 60, reward = 3 },

        -- Weekly PvP & Battleground Quests (Requires 5 participations)
        { name = "Warsong Gulch Skirmishes", type = "PVP_SESSION", target = "Warsong Gulch", minLevel = 10, countReq = 5, reward = 12 },
        { name = "Arathi Basin Skirmishes", type = "PVP_SESSION", target = "Arathi Basin", minLevel = 20, countReq = 5, reward = 15 },
        { name = "Alterac Valley Skirmishes", type = "PVP_SESSION", target = "Alterac Valley", minLevel = 51, countReq = 5, reward = 20 },
        { name = "Weekly Honor Milestone", type = "PVP_HONOR", targetHonor = 5000, minLevel = 10, reward = 15 }
    },
    
    Monthly = {
        -- Gathering Quests (5+ stacks, max 10 LC)
        { item = "Mageweave Cloth", count = 100, reward = 7, minLevel = 40 },
        { item = "Iron Ore", count = 100, reward = 8, minLevel = 30 },
        { item = "Heavy Leather", count = 100, reward = 7, minLevel = 35 },
        { item = "Thick Leather", count = 100, reward = 9, minLevel = 40 },
        { item = "Kingsblood", count = 100, reward = 7, minLevel = 30 },
        { item = "Solid Stone", count = 100, reward = 6, minLevel = 30 },
        { item = "Wild Steelbloom", count = 100, reward = 7, minLevel = 25 },
        { item = "Mithril Ore", count = 100, reward = 10, minLevel = 40 },
        { item = "Runecloth", count = 100, reward = 10, minLevel = 50 },
        { item = "Truesilver Ore", count = 100, reward = 10, minLevel = 45 },
        
        -- Monthly Dungeon Quests (All Horde-Accessible Dungeons split explicitly into wings, Requires 5 runs)
        { name = "Ragefire Chasm: 5 Runs", type = "DUNGEON", target = "Ragefire Chasm", minLevel = 12, countReq = 5, reward = 5 },
        { name = "Wailing Caverns: 5 Runs", type = "DUNGEON", target = "Wailing Caverns", minLevel = 15, countReq = 5, reward = 5 },
        { name = "Shadowfang Keep: 5 Runs", type = "DUNGEON", target = "Shadowfang Keep", minLevel = 18, countReq = 5, reward = 5 },
        { name = "Blackfathom Deeps: 5 Runs", type = "DUNGEON", target = "Blackfathom Deeps", minLevel = 20, countReq = 5, reward = 6 },
        { name = "Razorfen Kraul: 5 Runs", type = "DUNGEON", target = "Razorfen Kraul", minLevel = 29, countReq = 5, reward = 6 },
        { name = "Scarlet Monastery: Graveyard (5 Runs)", type = "DUNGEON", target = "SM: Graveyard", minLevel = 26, countReq = 5, reward = 6 },
        { name = "Scarlet Monastery: Library (5 Runs)", type = "DUNGEON", target = "SM: Library", minLevel = 29, countReq = 5, reward = 6 },
        { name = "Scarlet Monastery: Armory (5 Runs)", type = "DUNGEON", target = "SM: Armory", minLevel = 32, countReq = 5, reward = 6 },
        { name = "Scarlet Monastery: Cathedral (5 Runs)", type = "DUNGEON", target = "SM: Cathedral", minLevel = 35, countReq = 5, reward = 7 },
        { name = "Razorfen Downs: 5 Runs", type = "DUNGEON", target = "Razorfen Downs", minLevel = 35, countReq = 5, reward = 6 },
        { name = "Uldaman: 5 Runs", type = "DUNGEON", target = "Uldaman", minLevel = 38, countReq = 5, reward = 7 },
        { name = "Zul'Farrak: 5 Runs", type = "DUNGEON", target = "Zul'Farrak", minLevel = 42, countReq = 5, reward = 7 },
        { name = "Maraudon: 5 Runs", type = "DUNGEON", target = "Maraudon", minLevel = 45, countReq = 5, reward = 7 },
        { name = "Sunken Temple (ST): 5 Runs", type = "DUNGEON", target = "Sunken Temple", minLevel = 50, countReq = 5, reward = 8 },
        { name = "Blackrock Depths (BRD): 5 Runs", type = "DUNGEON", target = "Blackrock Depths", minLevel = 52, countReq = 5, reward = 9 },
        { name = "Lower Blackrock Spire (LBRS): 5 Runs", type = "DUNGEON", target = "LBRS", minLevel = 55, countReq = 5, reward = 10 },
        { name = "Scholomance: 5 Runs", type = "DUNGEON", target = "Scholomance", minLevel = 58, countReq = 5, reward = 10 },
        { name = "Stratholme: 5 Runs", type = "DUNGEON", target = "Stratholme", minLevel = 58, countReq = 5, reward = 10 },

        -- Monthly PvP & Battleground Quests (Requires 10 participations)
        { name = "Master of Warsong Gulch", type = "PVP_SESSION", target = "Warsong Gulch", minLevel = 10, countReq = 10, reward = 30 },
        { name = "Master of Arathi Basin", type = "PVP_SESSION", target = "Arathi Basin", minLevel = 20, countReq = 10, reward = 40 },
        { name = "Alterac Valley Conqueror", type = "PVP_SESSION", target = "Alterac Valley", minLevel = 51, countReq = 10, reward = 50 },
        { name = "Monthly Elite Honor Cap", type = "PVP_HONOR", targetHonor = 20000, minLevel = 10, reward = 45 }
    }
}

local function PlayerHasProfession(targetProfession, requiredSkill)
    if not targetProfession or targetProfession == "None" or requiredSkill == 0 then 
        return true 
    end
    
    local prof1, prof2 = GetProfessions()
    local profsToCheck = {prof1, prof2}
    
    for _, profIndex in ipairs(profsToCheck) do
        if profIndex then
            local name, _, skillLine = GetProfessionInfo(profIndex)
            if name and string.lower(name) == string.lower(targetProfession) then
                if skillLine >= requiredSkill then
                    return true
                end
            end
        end
    end
    return false
end

function GuildUtils.Contracts:FilterEligibleQuests(poolTable)
    local playerLevel = UnitLevel("player") or 1
    local eligible = {}
    
    for _, quest in ipairs(poolTable) do
        local minLvl = quest.minLevel or 1
        local maxLvl = quest.maxLevel or 60
        
        if playerLevel >= minLvl and playerLevel <= maxLvl then
            local passesProfession = true
            if quest.profession and quest.profession ~= "None" then
                passesProfession = PlayerHasProfession(quest.profession, quest.skillReq or 1)
            end
            
            if passesProfession then
                table.insert(eligible, quest)
            end
        end
    end
    return eligible
end

function GuildUtils.Contracts:InitializeDB()
    if not GU_GlobalDB then GU_GlobalDB = {} end
    if not GU_GlobalDB.Contracts then
        GU_GlobalDB.Contracts = { list = {}, nextId = 1 }
    end
    
    if #GU_GlobalDB.Contracts.list == 0 then
        local eligibleWeekly = self:FilterEligibleQuests(self.RecurringQuests.Weekly)
        local eligibleMonthly = self:FilterEligibleQuests(self.RecurringQuests.Monthly)

        -- Weekly Insertion Loop
        for i = 1, math.min(5, #eligibleWeekly) do
            local q = eligibleWeekly[i]
            local titleText = q.item and string.format("Weekly: %dx %s", q.count, q.item) or q.name
            table.insert(GU_GlobalDB.Contracts.list, {
                id = GU_GlobalDB.Contracts.nextId,
                title = titleText,
                targetCount = q.count or q.runsRequired or 1,
                currentProgress = 0,
                reward = q.reward,
                completed = false,
                creatorName = "SYSTEM",
                isGuildQuest = true,
                period = "Weekly" -- NEW: Added for rollover tracking
            })
            GU_GlobalDB.Contracts.nextId = GU_GlobalDB.Contracts.nextId + 1
        end

        -- Monthly Insertion Loop
        for i = 1, math.min(3, #eligibleMonthly) do
            local q = eligibleMonthly[i]
            local titleText = q.item and string.format("Monthly: %dx %s", q.count, q.item) or q.name
            table.insert(GU_GlobalDB.Contracts.list, {
                id = GU_GlobalDB.Contracts.nextId,
                title = titleText,
                targetCount = q.count or q.runsRequired or 1,
                currentProgress = 0,
                reward = q.reward,
                completed = false,
                creatorName = "SYSTEM",
                isGuildQuest = true,
                period = "Monthly" -- NEW: Added for rollover tracking
            })
            GU_GlobalDB.Contracts.nextId = GU_GlobalDB.Contracts.nextId + 1
        end
    end
end

function GuildUtils.Contracts:Toggle()
    if not self.Frame then
        self:InitializeUI()
    end
    if self.Frame:IsShown() then 
        self.Frame:Hide() 
    else 
        self.Frame:Show() 
        self:UpdateBoard() 
    end
end

function GuildUtils.Contracts:InitializeUI()
    if self.Frame then return end
    self:InitializeDB()
    
    local mainFrame = GuildUtils.PartyRoller:InitializeUI()
    local f = mainFrame.BountyContainer
    self.Frame = mainFrame
    self.Container = f

    f.colLeftText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colLeftText:SetPoint("TOPLEFT", 20, -10)
    f.colLeftText:SetText("Open Guild Quests")

    f.colRightText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colRightText:SetPoint("TOPLEFT", 305, -10)
    f.colRightText:SetText("Personal Contracts")

    local midDiv = f:CreateTexture(nil, "ARTWORK")
    midDiv:SetColorTexture(0.3, 0.3, 0.3, 1)
    midDiv:SetSize(1, 340)
    midDiv:SetPoint("TOP", 0, -10)
    midDiv:SetPoint("LEFT", f, "LEFT", 290, 0)
    
    f.scrollLeft = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollLeft:SetPoint("TOPLEFT", 10, -35)
    f.scrollLeft:SetPoint("BOTTOMLEFT", 10, 50)
    f.scrollLeft:SetWidth(270)
    
    f.childLeft = CreateFrame("Frame", nil, f.scrollLeft)
    f.childLeft:SetSize(270, 1)
    f.scrollLeft:SetScrollChild(f.childLeft)

    f.scrollRight = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollRight:SetPoint("TOPLEFT", 300, -35)
    f.scrollRight:SetPoint("BOTTOMRIGHT", -30, 50)
    
    f.childRight = CreateFrame("Frame", nil, f.scrollRight)
    f.childRight:SetSize(250, 1)
    f.scrollRight:SetScrollChild(f.childRight)

    f.createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.createBtn:SetSize(140, 22)
    f.createBtn:SetPoint("BOTTOM", 0, 15)
    f.createBtn:SetText("Post New Contract")
    f.createBtn:SetScript("OnClick", function() GuildUtils:Print("Contract creation interface coming soon.", false) end)
end

function GuildUtils.Contracts:ShowInstructionModal(contract)
    if not self.InstructionModal then
        local m = CreateFrame("Frame", "GuildUtilsContractInstructionModal", UIParent, "BasicFrameTemplateWithInset")
        m:SetSize(360, 210)
        m:SetPoint("CENTER")
        m:SetFrameStrata("DIALOG")
        m:Hide()
        
        m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        m.title:SetPoint("TOP", 0, -5)
        m.title:SetText("Fulfillment Instructions")
        
        m.scrollArea = CreateFrame("ScrollFrame", nil, m, "UIPanelScrollFrameTemplate")
        m.scrollArea:SetPoint("TOPLEFT", 12, -32)
        m.scrollArea:SetPoint("BOTTOMRIGHT", -30, 40)
        
        m.editBox = CreateFrame("EditBox", nil, m.scrollArea)
        m.editBox:SetMultiLine(true)
        m.editBox:SetFontObject(ChatFontNormal)
        m.editBox:SetWidth(300)
        m.editBox:SetAutoFocus(false)
        m.editBox:SetScript("OnEscapePressed", function() m:Hide() end)
        m.scrollArea:SetScrollChild(m.editBox)
        
        m.closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        m.closeBtn:SetSize(100, 22)
        m.closeBtn:SetPoint("BOTTOM", 0, 10)
        m.closeBtn:SetText("Close")
        m.closeBtn:SetScript("OnClick", function() m:Hide() end)
        
        self.InstructionModal = m
    end
    
    local officerName = nil
    if IsInGuild() then
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local name, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and rankIndex and rankIndex <= 3 then
                officerName = Ambiguate(name, "short")
                break
            end
        end
    end
    
    local recipient = contract.creatorName
    if not recipient or recipient == "SYSTEM" then
        recipient = officerName or GuildUtils.Host or UnitName("player")
    end

    local modal = self.InstructionModal
    local instructions = string.format(
        "--- FULFILLMENT INSTRUCTIONS ---\n\n" ..
        "Quest: %s\n" ..
        "Target Goal: %d items/runs\n" ..
        "Reward: %d LC\n\n" ..
        "HOW TO TURN IN:\n" ..
        "1. By Mail (Asynchronous):\n" ..
        "   - Send items to: %s\n" ..
        "   - Subject Line (Required):\n     <GU_CONTRACT:PC-%d>\n" ..
        "   - You can submit items in bunches!\n\n" ..
        "2. By Trade (Face-to-Face):\n" ..
        "   - Open a trade with an Officer (%s).\n" ..
        "   - Hand over items to have progress recorded instantly.",
        contract.title, contract.targetCount or 1, contract.reward,
        recipient, contract.id, recipient
    )
    
    modal.editBox:SetText(instructions)
    modal:Show()
    modal.editBox:HighlightText()
    modal.editBox:SetFocus()
end

function GuildUtils.Contracts:UpdateBoard()
    self:InitializeDB()
    if not self.Container or not self.Container:IsShown() then return end
    
    local themeIdx = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = GuildUtils.Styles[themeIdx] or GuildUtils.Styles[1]

    self.Container.colLeftText:SetTextColor(unpack(style.titleColor))
    self.Container.colRightText:SetTextColor(unpack(style.titleColor))

    self.LeftRows = self.LeftRows or {}
    for _, row in ipairs(self.LeftRows) do row:Hide() end

    local yOffset, rowIndex = -5, 1
    if GU_GlobalDB and GU_GlobalDB.Contracts and GU_GlobalDB.Contracts.list then
        for _, contract in ipairs(GU_GlobalDB.Contracts.list) do
            if not contract.completed and contract.creatorName == "SYSTEM" then
                local row = self.LeftRows[rowIndex]
                if not row then
                    row = CreateFrame("Frame", nil, self.Container.childLeft)
                    row:SetSize(260, 50)
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                    
                    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.title:SetPoint("TOPLEFT", 5, -3)
                    row.title:SetWidth(250)
                    row.title:SetJustifyH("LEFT")
                    row.title:SetWordWrap(true)
                    
                    row.progress = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.progress:SetPoint("BOTTOMLEFT", 5, 18)
                    
                    row.reward = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.reward:SetPoint("BOTTOMLEFT", 5, 4)
                    
                    row.infoBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.infoBtn:SetSize(55, 20)
                    row.infoBtn:SetPoint("BOTTOMRIGHT", -5, 4)
                    row.infoBtn:SetText("Info")
                    
                    self.LeftRows[rowIndex] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, yOffset)
                row.title:SetText(contract.title)
                row.title:SetTextColor(unpack(style.nameColor))
                
                local current = contract.currentProgress or 0
                local target = contract.targetCount or 1
                row.progress:SetText(string.format("Progress: %d / %d", current, target))
                row.progress:SetTextColor(unpack(style.balColor))
                
                row.reward:SetText(string.format("Reward: %d LC", contract.reward))
                row.reward:SetTextColor(unpack(style.balColor))
                
                row.infoBtn:SetScript("OnClick", function()
                    GuildUtils.Contracts:ShowInstructionModal(contract)
                end)
                
                row:Show()
                yOffset = yOffset - 55
                rowIndex = rowIndex + 1
            end
        end
    end
    self.Container.childLeft:SetHeight(math.max(200, math.abs(yOffset)))
end

-- ============================================================================ -- RECEIVER FULFILLMENT HOOKS (MAIL & TRADE SIGN-OFF) -- ============================================================================

local mailMonitor = CreateFrame("Frame")
mailMonitor:RegisterEvent("MAIL_INBOX_UPDATE")
mailMonitor:SetScript("OnEvent", function(self, event)
    local numItems = GetInboxNumItems() or 0
    for i = 1, numItems do
        local _, _, sender, subject = GetInboxHeaderInfo(i)
        local contractID = string.match(subject or "", "<GU_CONTRACT:PC-(.-)>")
        
        if contractID then
            local cIDNum = tonumber(contractID)
            local itemID, itemTexture, count = select(2, GetInboxItem(i, 1))
            if cIDNum and GU_GlobalDB and GU_GlobalDB.Contracts and GU_GlobalDB.Contracts.list then
                for _, contract in ipairs(GU_GlobalDB.Contracts.list) do
                    if contract.id == cIDNum and not contract.completed then
                        contract.currentProgress = (contract.currentProgress or 0) + (count or 1)
                        if contract.currentProgress >= contract.targetCount then
                            contract.completed = true
                            if GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
                                local senderGuid = UnitGUID("player") -- Fallback or parsed sender
                                GuildUtils.LootCoin:ProcessTransaction(senderGuid, sender, contract.reward, "Bounty Completed: " .. contract.title)
                            end
                            GuildUtils:Print(string.format("Contract #%d fulfilled by %s! Reward issued.", cIDNum, sender), false)
                        else
                            GuildUtils:Print(string.format("Contract #%d progress updated (+%d) by %s (%d/%d).", cIDNum, count or 1, sender, contract.currentProgress, contract.targetCount), false)
                        end
                        -- Broadcast progress sync to network
                        GuildUtils:QueueMessage(string.format("CONTRACT_PROGRESS:%d:%d", cIDNum, contract.currentProgress), "GUILD")
                        if GuildUtils.Contracts.UpdateBoard then GuildUtils.Contracts:UpdateBoard() end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- AUTOMATED QUEST TRACKING & VALIDATION PIPELINES
-- ============================================================================

function GuildUtils.Contracts:CompleteContract(contract)
    contract.completed = true
    if GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
        GuildUtils.LootCoin:ProcessTransaction(UnitGUID("player"), UnitName("player"), contract.reward, "Quest Completed: " .. contract.title)
    end
    GuildUtils:Print(string.format("Quest Completed! '%s' - Awarded %d LC.", contract.title, contract.reward), false)
    GuildUtils:QueueMessage(string.format("CONTRACT_PROGRESS:%d:%d", contract.id, contract.currentProgress), "GUILD")
    if self.UpdateBoard then self:UpdateBoard() end
end

function GuildUtils.Contracts:ProgressQuestType(qType, targetName, amount)
    if not GU_GlobalDB or not GU_GlobalDB.Contracts then return end
    for _, contract in ipairs(GU_GlobalDB.Contracts.list) do
        if not contract.completed and contract.type == qType and (contract.target == targetName or string.find(targetName, contract.target)) then
            contract.currentProgress = (contract.currentProgress or 0) + amount
            if contract.currentProgress >= contract.targetCount then
                self:CompleteContract(contract)
            else
                GuildUtils:Print(string.format("Quest Progress: %s (%d/%d)", contract.title, contract.currentProgress, contract.targetCount), false)
                GuildUtils:QueueMessage(string.format("CONTRACT_PROGRESS:%d:%d", contract.id, contract.currentProgress), "GUILD")
                if self.UpdateBoard then self:UpdateBoard() end
            end
        end
    end
end

-- 1. Dungeon Quest Validation (Triggered by InstanceJournal)
function GuildUtils.Contracts:ValidateDungeonRun(instanceName, bossKills, isRaid)
    if isRaid then return end -- Ignoring raid events
    if not GU_GlobalDB or not GU_GlobalDB.InstanceJournal then return end
    
    local entry = GU_GlobalDB.InstanceJournal[instanceName]
    local minRequired = entry and entry.minBosses or 1
    
    if bossKills >= minRequired and bossKills > 0 then
        self:ProgressQuestType("DUNGEON", instanceName, 1)
    end
end

-- 2. PvP & Battleground Tracking
-- 2. PvP & Battleground Tracking (With Honor Delta Fix)
local pvpTracker = CreateFrame("Frame")
pvpTracker:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
pvpTracker:RegisterEvent("HONOR_XP_UPDATE")
pvpTracker:RegisterEvent("PLAYER_ENTERING_WORLD") -- To initialize baseline honor

local lastKnownHonor = 0

pvpTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        lastKnownHonor = UnitHonor("player") or 0
        
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        local bgIndex = ...
        local status, mapName = GetBattlefieldStatus(bgIndex)
        if status == "active" then
            self.activeBG = mapName
        elseif status == "none" and self.activeBG then
            local winner = GetBattlefieldWinner()
            if winner ~= nil then 
                GuildUtils.Contracts:ProgressQuestType("PVP_SESSION", self.activeBG, 1)
            end
            self.activeBG = nil
        end
        
    elseif event == "HONOR_XP_UPDATE" then
        local currentHonor = UnitHonor("player") or 0
        local honorGained = 0
        
        if currentHonor > lastKnownHonor then
            -- Normal gain
            honorGained = currentHonor - lastKnownHonor
        elseif currentHonor < lastKnownHonor then
            -- A weekly server reset occurred; honor wiped to 0 and started over
            honorGained = currentHonor
        end
        
        lastKnownHonor = currentHonor
        
        if honorGained > 0 and GU_GlobalDB and GU_GlobalDB.Contracts then
            -- We push the delta (honorGained) to our Progress function
            -- We use a dummy target name "Honor" to match the PVP_HONOR type
            GuildUtils.Contracts:ProgressQuestType("PVP_HONOR", "Honor", honorGained)
        end
    end
end)

-- 3. Face-to-Face Trade Tracking (Gathering Quests)
local tradeTracker = CreateFrame("Frame")
tradeTracker:RegisterEvent("TRADE_CLOSED")
tradeTracker:RegisterEvent("TRADE_ACCEPT_UPDATE")

local tradeAccepted = false
tradeTracker:SetScript("OnEvent", function(self, event, playerAccepted, targetAccepted)
    if event == "TRADE_ACCEPT_UPDATE" then
        if playerAccepted and targetAccepted then 
            tradeAccepted = true 
        end
    elseif event == "TRADE_CLOSED" then
        if tradeAccepted then
            GuildUtils:Print("|cFF00FF00[GuildUtils]|r Trade successful. Contracted items handed to an officer will be parsed and validated by their client.", false)
        end
        tradeAccepted = false
    end
end)
-- ============================================================================
-- ROLLOVER MANAGER (Weekly & Monthly Resets)
-- ============================================================================

-- Calculates the timestamp for the upcoming Tuesday at 8:00 AM
function GuildUtils.Contracts:GetNextWeeklyReset()
    local t = time()
    local d = date("*t", t)
    -- wday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    local daysToTuesday = (3 - d.wday) % 7
    if daysToTuesday == 0 and d.hour >= 8 then
        daysToTuesday = 7
    end
    -- os.time automatically normalizes out-of-range days/months
    return time({year = d.year, month = d.month, day = d.day + daysToTuesday, hour = 8, min = 0, sec = 0})
end

-- Calculates the timestamp for the 1st of the next month at 8:00 AM
function GuildUtils.Contracts:GetNextMonthlyReset()
    local d = date("*t", time())
    local nextMonth = d.month + 1
    local nextYear = d.year
    if nextMonth > 12 then
        nextMonth = 1
        nextYear = nextYear + 1
    end
    return time({year = nextYear, month = nextMonth, day = 1, hour = 8, min = 0, sec = 0})
end

function GuildUtils.Contracts:CheckRollovers()
    if not GU_GlobalDB or not GU_GlobalDB.Contracts then return end
    
    local currentTime = time()
    local db = GU_GlobalDB.Contracts
    local needsUpdate = false
    
    -- Check Weekly Rollover
    if not db.nextWeeklyReset or currentTime >= db.nextWeeklyReset then
        db.nextWeeklyReset = self:GetNextWeeklyReset()
        
        -- Safely purge old weekly system quests (iterating backwards to prevent shifting issues)
        if db.list then
            for i = #db.list, 1, -1 do
                if db.list[i].isGuildQuest and db.list[i].period == "Weekly" then
                    table.remove(db.list, i)
                end
            end
        end
        needsUpdate = true
        GuildUtils:Print("Weekly server reset detected. Refreshing Weekly Bounty Board...", false)
    end
    
    -- Check Monthly Rollover
    if not db.nextMonthlyReset or currentTime >= db.nextMonthlyReset then
        db.nextMonthlyReset = self:GetNextMonthlyReset()
        
        -- Safely purge old monthly system quests
        if db.list then
            for i = #db.list, 1, -1 do
                if db.list[i].isGuildQuest and db.list[i].period == "Monthly" then
                    table.remove(db.list, i)
                end
            end
        end
        needsUpdate = true
        GuildUtils:Print("Monthly server reset detected. Refreshing Monthly Bounty Board...", false)
    end
    
    -- Repopulate missing quests and redraw the UI if a reset occurred
    if needsUpdate then
        self:InitializeDB() 
        if self.UpdateBoard then self:UpdateBoard() end
    end
end

-- Run the rollover check quietly in the background when the player logs in
local rolloverTracker = CreateFrame("Frame")
rolloverTracker:RegisterEvent("PLAYER_LOGIN")
rolloverTracker:SetScript("OnEvent", function()
    C_Timer.After(5, function() 
        if GuildUtils.Contracts.CheckRollovers then
            GuildUtils.Contracts:CheckRollovers()
        end
    end)
end)
-- ============================================================================
-- AUTOMATED QUEST TRACKING, ROLLOVER, & VALIDATION PIPELINES
-- ============================================================================

-- Base Completion Handlers
function GuildUtils.Contracts:CompleteContract(contract)
    contract.completed = true
    if GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
        GuildUtils.LootCoin:ProcessTransaction(UnitGUID("player"), UnitName("player"), contract.reward, "Quest Completed: " .. contract.title)
    end
    GuildUtils:Print(string.format("Quest Completed! '%s' - Awarded %d LC.", contract.title, contract.reward), false)
    GuildUtils:QueueMessage(string.format("CONTRACT_PROGRESS:%d:%d", contract.id, contract.currentProgress), "GUILD")
    if self.UpdateBoard then self:UpdateBoard() end
end

function GuildUtils.Contracts:ProgressQuestType(qType, targetName, amount)
    if not GU_GlobalDB or not GU_GlobalDB.Contracts then return end
    for _, contract in ipairs(GU_GlobalDB.Contracts.list) do
        if not contract.completed and contract.type == qType and (contract.target == targetName or string.find(targetName, contract.target)) then
            contract.currentProgress = (contract.currentProgress or 0) + amount
            if contract.currentProgress >= contract.targetCount then
                self:CompleteContract(contract)
            else
                GuildUtils:Print(string.format("Quest Progress: %s (%d/%d)", contract.title, contract.currentProgress, contract.targetCount), false)
                GuildUtils:QueueMessage(string.format("CONTRACT_PROGRESS:%d:%d", contract.id, contract.currentProgress), "GUILD")
                if self.UpdateBoard then self:UpdateBoard() end
            end
        end
    end
end

-- Dungeon Quest Validation (Triggered by InstanceJournal module)
function GuildUtils.Contracts:ValidateDungeonRun(instanceName, bossKills, isRaid)
    if isRaid then return end -- Raid events are handled by the leader sign-off screen
    if not GU_GlobalDB or not GU_GlobalDB.InstanceJournal then return end
    
    local entry = GU_GlobalDB.InstanceJournal[instanceName]
    local minRequired = entry and entry.minBosses or 1
    
    if bossKills >= minRequired and bossKills > 0 then
        self:ProgressQuestType("DUNGEON", instanceName, 1)
    end
end

-- PvP & Battleground Tracking (With Honor Delta Fix)
local pvpTracker = CreateFrame("Frame")
pvpTracker:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
pvpTracker:RegisterEvent("HONOR_XP_UPDATE")
pvpTracker:RegisterEvent("PLAYER_ENTERING_WORLD")

local lastKnownHonor = 0
pvpTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        lastKnownHonor = UnitHonor("player") or 0
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        local bgIndex = ...
        local status, mapName = GetBattlefieldStatus(bgIndex)
        if status == "active" then
            self.activeBG = mapName
        elseif status == "none" and self.activeBG then
            local winner = GetBattlefieldWinner()
            if winner ~= nil then 
                GuildUtils.Contracts:ProgressQuestType("PVP_SESSION", self.activeBG, 1)
            end
            self.activeBG = nil
        end
    elseif event == "HONOR_XP_UPDATE" then
        local currentHonor = UnitHonor("player") or 0
        local honorGained = 0
        
        if currentHonor > lastKnownHonor then
            honorGained = currentHonor - lastKnownHonor
        elseif currentHonor < lastKnownHonor then
            honorGained = currentHonor
        end
        
        lastKnownHonor = currentHonor
        
        if honorGained > 0 and GU_GlobalDB and GU_GlobalDB.Contracts then
            GuildUtils.Contracts:ProgressQuestType("PVP_HONOR", "Honor", honorGained)
        end
    end
end)

-- Rollover Manager (Weekly/Monthly Resets)
function GuildUtils.Contracts:GetNextWeeklyReset()
    local t = time()
    local d = date("*t", t)
    local daysToTuesday = (3 - d.wday) % 7
    if daysToTuesday == 0 and d.hour >= 8 then daysToTuesday = 7 end
    return time({year = d.year, month = d.month, day = d.day + daysToTuesday, hour = 8, min = 0, sec = 0})
end

function GuildUtils.Contracts:GetNextMonthlyReset()
    local d = date("*t", time())
    local nextMonth = d.month + 1
    local nextYear = d.year
    if nextMonth > 12 then
        nextMonth = 1
        nextYear = nextYear + 1
    end
    return time({year = nextYear, month = nextMonth, day = 1, hour = 8, min = 0, sec = 0})
end

function GuildUtils.Contracts:CheckRollovers()
    if not GU_GlobalDB or not GU_GlobalDB.Contracts then return end
    
    local currentTime = time()
    local db = GU_GlobalDB.Contracts
    local needsUpdate = false
    
    if not db.nextWeeklyReset or currentTime >= db.nextWeeklyReset then
        db.nextWeeklyReset = self:GetNextWeeklyReset()
        if db.list then
            for i = #db.list, 1, -1 do
                if db.list[i].isGuildQuest and db.list[i].period == "Weekly" then
                    table.remove(db.list, i)
                end
            end
        end
        needsUpdate = true
        GuildUtils:Print("Weekly server reset detected. Refreshing Weekly Bounty Board...", false)
    end
    
    if not db.nextMonthlyReset or currentTime >= db.nextMonthlyReset then
        db.nextMonthlyReset = self:GetNextMonthlyReset()
        if db.list then
            for i = #db.list, 1, -1 do
                if db.list[i].isGuildQuest and db.list[i].period == "Monthly" then
                    table.remove(db.list, i)
                end
            end
        end
        needsUpdate = true
        GuildUtils:Print("Monthly server reset detected. Refreshing Monthly Bounty Board...", false)
    end
    
    if needsUpdate then
        self:InitializeDB() 
        if self.UpdateBoard then self:UpdateBoard() end
    end
end

local rolloverTracker = CreateFrame("Frame")
rolloverTracker:RegisterEvent("PLAYER_LOGIN")
rolloverTracker:SetScript("OnEvent", function()
    C_Timer.After(5, function() 
        if GuildUtils.Contracts.CheckRollovers then
            GuildUtils.Contracts:CheckRollovers()
        end
    end)
end)