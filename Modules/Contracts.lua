local addonName, GuildUtils = ...
GuildUtils.Contracts = {}

-- Master Recurring Quest Library with Level Brackets and Skill Gates
GuildUtils.Contracts.RecurringQuests = {
    Weekly = {
        { item = "Linen Cloth", count = 40, reward = 1, profession = "None", skillReq = 0, minLevel = 1 },
        { item = "Copper Ore", count = 40, reward = 2, profession = "Mining", skillReq = 1, minLevel = 1 },
        { item = "Light Leather", count = 20, reward = 1, profession = "Skinning", skillReq = 1, minLevel = 1 },
        { item = "Peacebloom", count = 20, reward = 1, profession = "Herbalism", skillReq = 1, minLevel = 1 },
        { item = "Silverleaf", count = 20, reward = 1, profession = "Herbalism", skillReq = 1, minLevel = 1 },
        { item = "Rough Stone", count = 40, reward = 1, profession = "Mining", skillReq = 1, minLevel = 1 },
        { item = "Raw Brilliant Smallfish", count = 20, reward = 1, profession = "Fishing", skillReq = 1, minLevel = 1 },
        { item = "Wool Cloth", count = 40, reward = 2, profession = "None", skillReq = 0, minLevel = 12 },
        { item = "Tin Ore", count = 40, reward = 2, profession = "Mining", skillReq = 50, minLevel = 12 },
        { item = "Medium Leather", count = 20, reward = 2, profession = "Skinning", skillReq = 100, minLevel = 15 },
        { name = "Ragefire Chasm: 1 Run", type = "DUNGEON", target = "Ragefire Chasm", runsRequired = 1, minLevel = 12, maxLevel = 30, reward = 2 },
        { name = "Wailing Caverns: 1 Run", type = "DUNGEON", target = "Wailing Caverns", runsRequired = 1, minLevel = 15, maxLevel = 35, reward = 2 },
        { name = "The Stockade: 1 Run", type = "DUNGEON", target = "The Stockade", runsRequired = 1, minLevel = 20, maxLevel = 40, reward = 2 }
    },
    Monthly = {
        { item = "Mageweave Cloth", count = 100, reward = 7, profession = "None", skillReq = 0, minLevel = 40 },
        { item = "Iron Ore", count = 100, reward = 8, profession = "Mining", skillReq = 125, minLevel = 30 },
        { item = "Heavy Leather", count = 100, reward = 7, profession = "Skinning", skillReq = 150, minLevel = 35 },
        { item = "Thick Leather", count = 100, reward = 9, profession = "Skinning", skillReq = 205, minLevel = 40 },
        { item = "Kingsblood", count = 100, reward = 7, profession = "Herbalism", skillReq = 125, minLevel = 30 },
        { name = "Razorfen Downs: 5 Runs", type = "DUNGEON", target = "Razorfen Downs", runsRequired = 5, minLevel = 35, reward = 6 },
        { name = "Uldaman: 5 Runs", type = "DUNGEON", target = "Uldaman", runsRequired = 5, minLevel = 38, reward = 8 }
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
    if not GU_GlobalDB.Contracts.list then
        GU_GlobalDB.Contracts.list = {}
    end
    
    if #GU_GlobalDB.Contracts.list == 0 then
        local eligibleWeekly = self:FilterEligibleQuests(self.RecurringQuests.Weekly)
        local eligibleMonthly = self:FilterEligibleQuests(self.RecurringQuests.Monthly)

        for i = 1, math.min(5, #eligibleWeekly) do
            local q = eligibleWeekly[i]
            local titleText = q.item and string.format("Weekly: %dx %s", q.count, q.item) or q.name
            local targetVal = q.count or q.runsRequired or 1
            
            table.insert(GU_GlobalDB.Contracts.list, {
                id = GU_GlobalDB.Contracts.nextId,
                title = titleText,
                type = q.type,
                target = q.target,
                targetCount = targetVal,
                currentProgress = 0,
                reward = q.reward,
                completed = false,
                creatorName = "SYSTEM",
                isGuildQuest = true,
                period = "Weekly"
            })
            GU_GlobalDB.Contracts.nextId = GU_GlobalDB.Contracts.nextId + 1
        end

        for i = 1, math.min(3, #eligibleMonthly) do
            local q = eligibleMonthly[i]
            local titleText = q.item and string.format("Monthly: %dx %s", q.count, q.item) or q.name
            local targetVal = q.count or q.runsRequired or 1
            
            table.insert(GU_GlobalDB.Contracts.list, {
                id = GU_GlobalDB.Contracts.nextId,
                title = titleText,
                type = q.type,
                target = q.target,
                targetCount = targetVal,
                currentProgress = 0,
                reward = q.reward,
                completed = false,
                creatorName = "SYSTEM",
                isGuildQuest = true,
                period = "Monthly"
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
        m:SetSize(360, 200)
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
        contract.creatorName or "Guild Bank", contract.id, contract.creatorName or "Officer"
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

-- ============================================================================
-- CLEAR & REASSIGN SLASH COMMAND
-- ============================================================================
SLASH_GUILDUTILSCLEARCONTRACTS1 = "/guclearcontracts"
SlashCmdList["GUILDUTILSCLEARCONTRACTS"] = function()
    GU_GlobalDB.Contracts = { list = {}, nextId = 1 }
    GuildUtils.Contracts:InitializeDB()
    GuildUtils.Contracts:UpdateBoard()
    GuildUtils.Contracts:FilterEligibleQuests(GuildUtils.Contracts.RecurringQuests.Weekly)
    GuildUtils:Print("Bounty Board cleared, filtered by level/profession, and reassigned!", false)
end