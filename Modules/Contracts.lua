local addonName, GuildUtils = ...
GuildUtils.Contracts = {}
GuildUtils.Contracts.Rows = {}

StaticPopupDialogs["GUILDUTILS_CREATE_CONTRACT_MODAL"] = {
    text = "Post Bounty: Item Name or Link:",
    button1 = "Next", button2 = "Cancel",
    hasEditBox = true, maxLetters = 64,
    OnAccept = function(selfPopup)
        local itemInput = selfPopup.EditBox:GetText()
        if itemInput and itemInput ~= "" then
            StaticPopup_Show("GUILDUTILS_CONTRACT_DETAILS_MODAL", itemInput, nil, {item = itemInput})
        end
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText(""); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_CONTRACT_DETAILS_MODAL"] = {
    text = "Enter [Count]:[Reward LC] for %s (e.g. 10:50):",
    button1 = "Publish Bounty", button2 = "Cancel",
    hasEditBox = true, maxLetters = 16,
    OnAccept = function(selfPopup, data)
        local input = selfPopup.EditBox:GetText()
        local countStr, rewardStr = strsplit(":", input)
        local count, reward = tonumber(countStr) or 1, tonumber(rewardStr) or 10
        GuildUtils.Contracts:PublishContract(data.item, count, reward, false)
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText("5:25"); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function GuildUtils.Contracts:GetGracePeriod(guid)
    GU_GlobalDB.Ledger.joinDates = GU_GlobalDB.Ledger.joinDates or {}
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(guid) or guid
    local joinTime = GU_GlobalDB.Ledger.joinDates[effGuid]
    
    if not joinTime then
        if GuildUtils.LootCoin then 
            GuildUtils.LootCoin:BootstrapPlayer(guid, GU_GlobalDB.Ledger.roster[effGuid] or UnitName("player")) 
        end
        joinTime = time()
    end

    local timeActive = time() - joinTime
    local gracePeriod = 48 * 60 * 60 
    
    if timeActive < gracePeriod then
        return true, gracePeriod - timeActive
    end
    return false, 0
end

function GuildUtils.Contracts:PublishContract(item, count, reward, isGuildQuest)
    local myGuid = UnitGUID("player")
    
    -- TASK 2 CHECK: Restrict contract creation during the 48-hour grace period
    local inGrace, timeRemaining = self:GetGracePeriod(myGuid)
    if inGrace then
        local hoursLeft = math.ceil(timeRemaining / 3600)
        GuildUtils:Print(string.format("Bounty Board restricted during your 48-hour onboarding grace period (%d hours remaining).", hoursLeft), true)
        return
    end

    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(myGuid) or myGuid
    local balance = (GU_GlobalDB.Ledger.balances[effGuid] or 0)
    
    if balance < reward then
        GuildUtils:Print("Insufficient LootCoin to place bounty escrow.", true)
        return
    end

    if GuildUtils.LootCoin then
        GuildUtils.LootCoin:ProcessTransaction(myGuid, UnitName("player"), -reward, "Contract Escrow Deposit")
    end

    local cId = (GU_GlobalDB.Contracts.nextId or 1)
    GU_GlobalDB.Contracts.nextId = cId + 1

    local newContract = {
        id = cId, title = item, count = count, reward = reward,
        creatorGuid = myGuid, creatorName = GuildUtils:FormatName(UnitName("player")),
        isGuildQuest = isGuildQuest or false, completed = false
    }
    table.insert(GU_GlobalDB.Contracts.list, newContract)

    local payload = string.format("%d:%s:%d:%d:%s:%s", cId, item, count, reward, myGuid, newContract.creatorName)
    GuildUtils:QueueMessage("CONTRACT_NEW:" .. payload, "GUILD")
    GuildUtils:Print("Contract #" .. cId .. " successfully published!", false)
    self:UpdateBoard()
end

function GuildUtils.Contracts:InitializeUI()
    if self.initialized then return end
    
    local mainFrame = GuildUtils.PartyRoller:InitializeUI()
    local f = mainFrame.BountyContainer
    self.Container = f
    
    f.colLeftText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colLeftText:SetPoint("TOPLEFT", 20, -10)
    f.colLeftText:SetText("Open Guild Quests")

    f.colRightText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colRightText:SetPoint("TOPLEFT", 300, -10)
    f.colRightText:SetText("Personal Contracts")

    local midDiv = f:CreateTexture(nil, "ARTWORK")
    midDiv:SetColorTexture(0.3, 0.3, 0.3, 1)
    midDiv:SetSize(1, 330)
    midDiv:SetPoint("TOP", 0, -10)

    -- FIX: Removed conflicting BOTTOMLEFT anchor and explicitly set the Width
    f.scrollLeft = CreateFrame("ScrollFrame", nil, f)
    f.scrollLeft:SetPoint("TOPLEFT", 10, -40)
    f.scrollLeft:SetPoint("BOTTOMLEFT", 10, 50)
    f.scrollLeft:SetWidth(270) 
    
    f.childLeft = CreateFrame("Frame", nil, f.scrollLeft)
    f.childLeft:SetSize(250, 1)
    f.scrollLeft:SetScrollChild(f.childLeft)

    f.scrollRight = CreateFrame("ScrollFrame", nil, f)
    f.scrollRight:SetPoint("TOPLEFT", 300, -40)
    f.scrollRight:SetPoint("BOTTOMRIGHT", -10, 50)
    
    f.childRight = CreateFrame("Frame", nil, f.scrollRight)
    f.childRight:SetSize(250, 1)
    f.scrollRight:SetScrollChild(f.childRight)

    f.createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.createBtn:SetSize(160, 24)
    f.createBtn:SetPoint("BOTTOM", 0, 10)
    f.createBtn:SetText("Post New Bounty")
    f.createBtn:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_CREATE_CONTRACT_MODAL") end)
    
    self.initialized = true
end

function GuildUtils.Contracts:Toggle()
    local f = GuildUtils.PartyRoller:InitializeUI()
    if not self.initialized then self:InitializeUI() end
    
    if f:IsShown() and GuildUtils.ActiveTab == "BOUNTY" then 
        f:Hide() 
    else 
        f:Show()
        f.tabBounty:Click()
        self:UpdateBoard()
    end
end

function GuildUtils.Contracts:UpdateBoard()
    if not self.initialized or not GuildUtils.DashboardFrame or not GuildUtils.DashboardFrame:IsShown() then return end
    
    -- Hide all existing rows first
    for _, r in ipairs(self.Rows or {}) do r:Hide() end
    
    local yLeft, yRight = -15, -15
    local rowIndex = 1
    
    for _, c in ipairs(GU_GlobalDB.Contracts.list or {}) do
        if not c.completed then
            local parent = c.isGuildQuest and self.Container.childLeft or self.Container.childRight
            local yOffset = c.isGuildQuest and yLeft or yRight
            
            local row = self.Rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, parent)
                row:SetSize(260, 36)
                
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.text:SetPoint("TOPLEFT", 0, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWidth(190) -- Prevent long system quest titles from breaking the frame
                row.text:SetWordWrap(false)
                
                row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.detail:SetPoint("BOTTOMLEFT", 0, 2)
                
                row.actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.actionBtn:SetSize(60, 18)
                row.actionBtn:SetPoint("RIGHT", -5, 0)
                
                self.Rows[rowIndex] = row
            end

            -- CRITICAL: Must clear previous anchors before reusing a frame in a scrolling list
            row:ClearAllPoints()
            row:SetParent(parent)
            row:SetPoint("TOPLEFT", 5, yOffset)
            
            row.text:SetText(string.format("#%d: %dx %s", c.id, c.count, c.title))
            row.detail:SetText(string.format("By: %s | Reward: |cFF00FF00%d LC|r", c.creatorName, c.reward))
            
            if c.creatorGuid == UnitGUID("player") then
                row.actionBtn:SetText("Cancel")
                row.actionBtn:SetScript("OnClick", function()
                    c.completed = true
                    if GuildUtils.LootCoin then GuildUtils.LootCoin:ProcessTransaction(c.creatorGuid, c.creatorName, c.reward, "Bounty Cancelled Refund") end
                    GuildUtils:QueueMessage("CONTRACT_FULFILL:" .. c.id .. ":CANCELLED", "GUILD")
                    GuildUtils.Contracts:UpdateBoard()
                end)
            else
                row.actionBtn:SetText("Mail")
                row.actionBtn:SetScript("OnClick", function()
                    GuildUtils:Print("To fulfill: Mail " .. c.count .. "x " .. c.title .. " to " .. c.creatorName .. " with subject: <GU_CONTRACT:" .. c.id .. ">", false)
                end)
            end
            
            row:Show()
            rowIndex = rowIndex + 1
            
            if c.isGuildQuest then 
                yLeft = yLeft - 40 
            else 
                yRight = yRight - 40 
            end
        end
    end
    
    self.Container.childLeft:SetHeight(math.max(300, math.abs(yLeft)))
    self.Container.childRight:SetHeight(math.max(300, math.abs(yRight)))
end

function GuildUtils.Contracts:OnNetworkContract(cmd, payload)
    if cmd == "CONTRACT_NEW" then
        local idStr, item, cntStr, rewStr, cGuid, cName = strsplit(":", payload)
        local id = tonumber(idStr) or 1
        for _, existing in ipairs(GU_GlobalDB.Contracts.list) do if existing.id == id then return end end
        table.insert(GU_GlobalDB.Contracts.list, {
            id = id, title = item, count = tonumber(cntStr) or 1, reward = tonumber(rewStr) or 0,
            creatorGuid = cGuid, creatorName = cName, isGuildQuest = false, completed = false
        })
        self:UpdateBoard()
    elseif cmd == "CONTRACT_FULFILL" then
        local idStr = strsplit(":", payload)
        local id = tonumber(idStr)
        for _, c in ipairs(GU_GlobalDB.Contracts.list) do
            if c.id == id then c.completed = true; break end
        end
        self:UpdateBoard()
    end
end

local mailMonitor = CreateFrame("Frame")
mailMonitor:RegisterEvent("MAIL_INBOX_UPDATE")
mailMonitor:SetScript("OnEvent", function(self, event)
    for i = 1, (GetInboxNumItems() or 0) do
        local _, _, sender, subject = GetInboxHeaderInfo(i)
        local contractID = subject and string.match(subject, "<GU_CONTRACT:(%d+)>")
        if contractID then
            local cIdNum = tonumber(contractID)
            for _, c in ipairs(GU_GlobalDB.Contracts.list or {}) do
                if c.id == cIdNum and not c.completed then
                    local _, _, count = GetInboxItem(i, 1)
                    if count and count >= c.count then
                        c.completed = true
                        GuildUtils:Print(string.format("Contract #%d fulfilled by %s via Mail! Releasing %d LC escrow.", c.id, sender, c.reward), false)
                        if GuildUtils.LootCoin and GuildUtils:IsAuthoritativeHost() then
                            GuildUtils.LootCoin:ProcessTransaction(sender, sender, c.reward, "Bounty Reward Contract #" .. c.id)
                        end
                        GuildUtils:QueueMessage("CONTRACT_FULFILL:" .. c.id .. ":" .. sender, "GUILD")
                        GuildUtils.Contracts:UpdateBoard()
                    end
                end
            end
        end
    end
end)

local tradeMonitor = CreateFrame("Frame")
tradeMonitor:RegisterEvent("TRADE_ACCEPT_UPDATE")
tradeMonitor:RegisterEvent("UI_INFO_MESSAGE")

local pendingTradeContract = nil
tradeMonitor:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_ACCEPT_UPDATE" then
        local targetName = GuildUtils:FormatName(UnitName("NPC") or UnitName("target"))
        for _, c in ipairs(GU_GlobalDB.Contracts.list or {}) do
            if not c.completed and c.creatorName == UnitName("player") then
                for slot = 1, 6 do
                    local link = GetTradeTargetItemLink(slot)
                    local _, _, qty = GetTradeTargetItemInfo(slot)
                    if link and link:find(c.title) and (qty or 1) >= c.count then
                        pendingTradeContract = { contract = c, fulfiller = targetName }
                    end
                end
            end
        end
    elseif event == "UI_INFO_MESSAGE" then
        local _, msg = ...
        if msg == LE_GAME_ERR_TRADE_COMPLETE and pendingTradeContract then
            local c = pendingTradeContract.contract
            c.completed = true
            GuildUtils:Print(string.format("Contract #%d completed via Trade! Releasing %d LC to %s.", c.id, c.reward, pendingTradeContract.fulfiller), false)
            if GuildUtils.LootCoin and GuildUtils:IsAuthoritativeHost() then
                GuildUtils.LootCoin:ProcessTransaction(pendingTradeContract.fulfiller, pendingTradeContract.fulfiller, c.reward, "Bounty Reward Trade Contract #" .. c.id)
            end
            GuildUtils:QueueMessage("CONTRACT_FULFILL:" .. c.id .. ":" .. pendingTradeContract.fulfiller, "GUILD")
            pendingTradeContract = nil
            GuildUtils.Contracts:UpdateBoard()
        end
    end
end)
-- Calculates if a player is still within their 48-hour onboarding window
function GuildUtils.Contracts:GetGracePeriod(guid)
    GU_GlobalDB.Ledger.joinDates = GU_GlobalDB.Ledger.joinDates or {}
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(guid) or guid
    local joinTime = GU_GlobalDB.Ledger.joinDates[effGuid]
    
    -- Auto-bootstrap the player if they don't have a join date yet
    if not joinTime then
        if GuildUtils.LootCoin then 
            GuildUtils.LootCoin:BootstrapPlayer(guid, GU_GlobalDB.Ledger.roster[effGuid] or UnitName("player")) 
        end
        joinTime = time()
    end

    local timeActive = time() - joinTime
    local gracePeriod = 48 * 60 * 60 -- 48 hours in seconds
    
    if timeActive < gracePeriod then
        return true, gracePeriod - timeActive
    end
    return false, 0
end
-- Define the default onboarding quests
GuildUtils.Contracts.RecurringQuests = {
    Weekly = {
        { item = "Flask of Supreme Power", count = 5, reward = 100 },
        { item = "Major Mana Potion", count = 20, reward = 50 },
        { item = "Dense Grinding Stone", count = 40, reward = 25 }
    },
    Monthly = {
        { item = "Arcane Crystal", count = 5, reward = 400 },
        { item = "Black Lotus", count = 2, reward = 500 }
    }
}

-- Dispatch function for new joiners (bypasses personal escrow deduction)
function GuildUtils.Contracts:DispatchOnboardingQuests(playerName)
    local hostName = GuildUtils.Host or UnitName("player")
    
    local function PublishSystemQuest(questType, q)
        local cId = (GU_GlobalDB.Contracts.nextId or 1)
        GU_GlobalDB.Contracts.nextId = cId + 1
        
        local newContract = {
            id = cId,
            title = string.format("[%s] %s (For: %s)", questType, q.item, playerName),
            count = q.count,
            reward = q.reward,
            creatorGuid = "SYSTEM_QUEST", 
            creatorName = hostName, -- Routes the mail to the active Host/Bank
            isGuildQuest = true,
            completed = false
        }
        table.insert(GU_GlobalDB.Contracts.list, newContract)
        
        -- Broadcast to the guild
        local payload = string.format("%d:%s:%d:%d:%s:%s", cId, newContract.title, q.count, q.reward, "SYSTEM_QUEST", hostName)
        GuildUtils:QueueMessage("CONTRACT_NEW:" .. payload, "GUILD")
    end

    for _, q in ipairs(self.RecurringQuests.Weekly) do PublishSystemQuest("Weekly", q) end
    for _, q in ipairs(self.RecurringQuests.Monthly) do PublishSystemQuest("Monthly", q) end
    
    GuildUtils:Print("Onboarding Guild Quests automatically dispatched for " .. playerName, false)
    if self.UpdateBoard then self:UpdateBoard() end
end
GuildUtils.Contracts.RecurringQuests = {
    Weekly = {
        { item = "Flask of Supreme Power", count = 5, reward = 100 },
        { item = "Major Mana Potion", count = 20, reward = 50 },
        { item = "Dense Grinding Stone", count = 40, reward = 25 }
    },
    Monthly = {
        { item = "Arcane Crystal", count = 5, reward = 400 },
        { item = "Black Lotus", count = 2, reward = 500 }
    }
}

function GuildUtils.Contracts:DispatchOnboardingQuests(playerName)
    local hostName = GuildUtils.Host or UnitName("player")
    
    local function PublishSystemQuest(questType, q)
        local cId = (GU_GlobalDB.Contracts.nextId or 1)
        GU_GlobalDB.Contracts.nextId = cId + 1
        
        local newContract = {
            id = cId,
            title = string.format("[%s] %s (For: %s)", questType, q.item, playerName),
            count = q.count, reward = q.reward,
            creatorGuid = "SYSTEM_QUEST", 
            creatorName = hostName,
            isGuildQuest = true, completed = false
        }
        table.insert(GU_GlobalDB.Contracts.list, newContract)
        
        local payload = string.format("%d:%s:%d:%d:%s:%s", cId, newContract.title, q.count, q.reward, "SYSTEM_QUEST", hostName)
        GuildUtils:QueueMessage("CONTRACT_NEW:" .. payload, "GUILD")
    end

    for _, q in ipairs(self.RecurringQuests.Weekly) do PublishSystemQuest("Weekly", q) end
    for _, q in ipairs(self.RecurringQuests.Monthly) do PublishSystemQuest("Monthly", q) end
    
    GuildUtils:Print("Onboarding Guild Quests automatically dispatched for " .. playerName, false)
    if self.UpdateBoard then self:UpdateBoard() end
end