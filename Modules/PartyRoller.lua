local addonName, GuildUtils = ...
GuildUtils.PartyRoller = {}

GuildUtils.PartyRoller.State = "IDLE_PANEL"
GuildUtils.PartyRoller.Queue = {}
GuildUtils.PartyRoller.QueueIndex = 0
GuildUtils.PartyRoller.QueueResults = {}
GuildUtils.PartyRoller.ActiveBids = {}
GuildUtils.PartyRoller.Duration = 10
GuildUtils.PartyRoller.HasResponded = false
GuildUtils.PartyRoller.CurrentItemData = nil
GuildUtils.PartyRoller.CountdownTimer = nil
GuildUtils.PartyRoller.PendingBidType = nil
GuildUtils.PartyRoller.MaxAvailable = 0

GU_PendingLoot = {}
GU_ReservedStatus = {}

StaticPopupDialogs["GUILDUTILS_WAGER_MODAL"] = {
    text = "Enter LC Wager for %s:\n%s",
    button1 = "Submit Bid",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 5,
    editBoxWidth = 60,
    OnAccept = function(self)
        local box = self.editBox or _G[self:GetName().."EditBox"]
        local amount = box and tonumber(box:GetText()) or 0
        if GuildUtils.PartyRoller.PendingBidType then
            GuildUtils.PartyRoller:SubmitRoll(GuildUtils.PartyRoller.PendingBidType, amount)
        end
    end,
    OnShow = function(self)
        local box = self.editBox or _G[self:GetName().."EditBox"]
        if box then
            box:SetNumeric(true)
            local def = (GuildUtils.PartyRoller.MaxAvailable and GuildUtils.PartyRoller.MaxAvailable > 0) and 1 or 0
            box:SetText(tostring(def))
            box:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local amount = tonumber(self:GetText()) or 0
        if GuildUtils.PartyRoller.PendingBidType then
            GuildUtils.PartyRoller:SubmitRoll(GuildUtils.PartyRoller.PendingBidType, amount)
        end
        StaticPopup_Hide("GUILDUTILS_WAGER_MODAL")
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("GUILDUTILS_WAGER_MODAL")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function GuildUtils.PartyRoller:RefreshState()
    local s = self.State
    if s == "BIDDING" or s == "RESULTS" then 
        self:SetUIState(s)
    elseif s == "PHASE_A" then 
        self:ShowPhaseA()
    elseif s == "PHASE_C" then 
        self:ShowPhaseC()
    else
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then 
            self:SetUIState("HUB_PANEL")
        else 
            self:SetUIState("IDLE_PANEL") 
        end 
    end
end

-- FIXED: Completely wipe selection state and force dropdown text back to default
function GuildUtils.PartyRoller:ResetIdlePanel()
    if not self.DashboardFrame then return end
    local c = self.DashboardFrame.GLContainer
    if c and c.IdlePanel then
        c.IdlePanel.selectedEventId = nil
        c.IdlePanel.selectedEventBasePay = 0
        c.IdlePanel.selectedEventEarlyBonus = 0
        c.IdlePanel.nameInput:SetText("New Group Event")
        c.IdlePanel.eventDropdown:SetText("Link to Event: None")
    end
end

function GuildUtils.PartyRoller:Toggle()
    local f = self:InitializeUI()
    if f:IsShown() and GuildUtils.ActiveTab == "GL" then
        f:Hide()
    else
        f:Show()
        f.tabGL:Click()
    end
end

function GuildUtils.PartyRoller:InitializeUI()
    if GuildUtils.DashboardFrame then return GuildUtils.DashboardFrame end

    local f = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsDashboardFrame", UIParent, 260, 480)
    f:Hide()
    f:SetPoint("CENTER", 320, 0)
    GuildUtils.DashboardFrame = f

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("GuildUtils: Gear & Loot Manager")

    f.tabGL = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabGL:SetSize(80, 24)
    f.tabGL:SetPoint("BOTTOMLEFT", 10, 10)
    f.tabGL:SetText("Gear & Loot")

    f.tabBounty = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabBounty:SetSize(80, 24)
    f.tabBounty:SetPoint("LEFT", f.tabGL, "RIGHT", 5, 0)
    f.tabBounty:SetText("Bounty")

    f.tabEvents = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabEvents:SetSize(80, 24)
    f.tabEvents:SetPoint("LEFT", f.tabBounty, "RIGHT", 5, 0)
    f.tabEvents:SetText("Events")

    f.GLContainer = CreateFrame("Frame", nil, f)
    f.GLContainer:SetPoint("TOPLEFT", 0, -25)
    f.GLContainer:SetPoint("BOTTOMRIGHT", 0, 40)
    f.GLContainer:Hide()

    f.BountyContainer = CreateFrame("Frame", nil, f)
    f.BountyContainer:SetPoint("TOPLEFT", 0, -25)
    f.BountyContainer:SetPoint("BOTTOMRIGHT", 0, 40)
    f.BountyContainer:Hide()

    f.EventsContainer = CreateFrame("Frame", nil, f)
    f.EventsContainer:SetPoint("TOPLEFT", 0, -25)
    f.EventsContainer:SetPoint("BOTTOMRIGHT", 0, 40)
    f.EventsContainer:Hide()

    f.tabGL:SetScript("OnClick", function()
        f.BountyContainer:Hide()
        f.EventsContainer:Hide()
        f.GLContainer:Show()
        f:SetWidth(260)
        GuildUtils.PartyRoller:RefreshState()
        f.title:SetText("GuildUtils: Gear & Loot Manager")
        GuildUtils.ActiveTab = "GL"
    end)

    f.tabBounty:SetScript("OnClick", function()
        f.GLContainer:Hide()
        f.EventsContainer:Hide()
        f.BountyContainer:Show()
        f:SetSize(600, 440)
        f.title:SetText("GuildUtils: Bounty Board")
        GuildUtils.ActiveTab = "BOUNTY"
        if GuildUtils.Contracts and GuildUtils.Contracts.InitializeUI then GuildUtils.Contracts:InitializeUI() end
        if GuildUtils.Contracts and GuildUtils.Contracts.UpdateBoard then GuildUtils.Contracts:UpdateBoard() end
    end)

    f.tabEvents:SetScript("OnClick", function()
        f.GLContainer:Hide()
        f.BountyContainer:Hide()
        f.EventsContainer:Show()
        f:SetSize(520, 420)
        f.title:SetText("GuildUtils: Raid Events")
        GuildUtils.ActiveTab = "EVENTS"
        if GuildUtils.Events and GuildUtils.Events.InitializeUI then GuildUtils.Events:InitializeUI() end
        if GuildUtils.Events and GuildUtils.Events.UpdateEventList then GuildUtils.Events:UpdateEventList() end
    end)

    local c = f.GLContainer

    c.IdlePanel = CreateFrame("Frame", nil, c)
    c.IdlePanel:SetAllPoints(c)
    c.IdlePanel:Hide()
    
    c.IdlePanel.info = c.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.IdlePanel.info:SetPoint("TOP", 0, -40)
    c.IdlePanel.info:SetText("No active group event.")
    
    c.IdlePanel.nameInput = CreateFrame("EditBox", nil, c.IdlePanel, "InputBoxTemplate")
    c.IdlePanel.nameInput:SetSize(150, 20)
    c.IdlePanel.nameInput:SetPoint("CENTER", 0, 40)
    c.IdlePanel.nameInput:SetAutoFocus(false)
    c.IdlePanel.nameInput:SetText("New Group Event")
    
    c.IdlePanel.nameLabel = c.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.IdlePanel.nameLabel:SetPoint("BOTTOM", c.IdlePanel.nameInput, "TOP", 0, 5)
    c.IdlePanel.nameLabel:SetText("Ledger Label (Group Name):")

    c.IdlePanel.eventDropdown = CreateFrame("Button", nil, c.IdlePanel, "UIPanelButtonTemplate")
    c.IdlePanel.eventDropdown:SetSize(180, 24)
    c.IdlePanel.eventDropdown:SetPoint("TOP", c.IdlePanel.nameInput, "BOTTOM", 0, -20)
    c.IdlePanel.eventDropdown:SetText("Link to Event: None")
    
    c.IdlePanel.selectedEventId = nil
    c.IdlePanel.selectedEventBasePay = 0
    c.IdlePanel.selectedEventEarlyBonus = 0

    c.IdlePanel.eventDropdown:SetScript("OnClick", function(selfBtn)
        MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Upcoming Event (Next 30 Mins)")
            
            rootDescription:CreateButton("None (Ad-Hoc Group)", function()
                c.IdlePanel.selectedEventId = nil
                c.IdlePanel.selectedEventBasePay = 0
                c.IdlePanel.selectedEventEarlyBonus = 0
                c.IdlePanel.nameInput:SetText("New Group Event")
                selfBtn:SetText("Link to Event: None")
            end)
            
            if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
                local currentTime = time()
                local validEvents = 0
                for _, eventData in ipairs(GU_GlobalDB.Events.list) do
                    if eventData.timestamp then
                        local diff = eventData.timestamp - currentTime
                        -- FIXED: Only show future events within a 30 minute window (exclude past/concluded raids)
                        if diff >= 0 and diff <= 1800 then
                            validEvents = validEvents + 1
                            local evName = string.format("%s (%s)", eventData.title, date("%I:%M %p", eventData.timestamp))
                            rootDescription:CreateButton(evName, function()
                                c.IdlePanel.selectedEventId = eventData.id
                                c.IdlePanel.selectedEventBasePay = eventData.basePay or 0
                                c.IdlePanel.selectedEventEarlyBonus = eventData.earlyBonus or 0
                                c.IdlePanel.nameInput:SetText(eventData.title)
                                selfBtn:SetText("Linked: " .. eventData.title)
                            end)
                        end
                    end
                end
                if validEvents == 0 then
                    rootDescription:CreateTitle("- No upcoming events in next 30m -")
                end
            end
        end)
    end)
    
    c.IdlePanel.startBtn = CreateFrame("Button", nil, c.IdlePanel, "UIPanelButtonTemplate")
    c.IdlePanel.startBtn:SetSize(140, 24)
    c.IdlePanel.startBtn:SetPoint("TOP", c.IdlePanel.eventDropdown, "BOTTOM", 0, -15)
    c.IdlePanel.startBtn:SetText("Start Group Event")
    c.IdlePanel.startBtn:SetScript("OnClick", function()
        if not GuildUtils:IsMasterLootActive() and not GuildUtils.SoloMode then 
            return GuildUtils:Print("You are not the leader/master looter.", true) 
        end
        
        local groupName = c.IdlePanel.nameInput:GetText()
        if groupName == "" then groupName = "New Group Event" end
        
        local linkedId = c.IdlePanel.selectedEventId
        local basePay = c.IdlePanel.selectedEventBasePay
        local earlyBonus = c.IdlePanel.selectedEventEarlyBonus
        
        GuildUtils.LootCoin:StartGroupEvent(groupName, linkedId, basePay, earlyBonus)
        GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
    end)

    c.HubPanel = CreateFrame("Frame", nil, c)
    c.HubPanel:SetAllPoints(c)
    c.HubPanel:Hide()

    c.HubPanel.btnRollCall = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnRollCall:SetSize(160, 26)
    c.HubPanel.btnRollCall:SetPoint("TOP", 0, -35)
    c.HubPanel.btnRollCall:SetText("Roll Call")
    c.HubPanel.btnRollCall:SetScript("OnClick", function() DoReadyCheck() end)

    c.HubPanel.btnAnnounce = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnAnnounce:SetSize(160, 26)
    c.HubPanel.btnAnnounce:SetPoint("TOP", 0, -70)
    c.HubPanel.btnAnnounce:SetText("Announce")
    c.HubPanel.btnAnnounce:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_ANNOUNCE") end)

    c.HubPanel.btnPullTimer = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnPullTimer:SetSize(160, 26)
    c.HubPanel.btnPullTimer:SetPoint("TOP", 0, -105)
    c.HubPanel.btnPullTimer:SetText("Pull Timer")
    c.HubPanel.btnPullTimer:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_PULL_TIMER") end)

    c.HubPanel.btnBreak = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnBreak:SetSize(160, 26)
    c.HubPanel.btnBreak:SetPoint("TOP", 0, -140)
    c.HubPanel.btnBreak:SetText("Break")
    c.HubPanel.btnBreak:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_BREAK_TIMER") end)

    c.HubPanel.btnLoot = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnLoot:SetSize(160, 26)
    c.HubPanel.btnLoot:SetPoint("TOP", 0, -175)
    c.HubPanel.btnLoot:SetText("Loot")
    c.HubPanel.btnLoot:SetScript("OnClick", function() GuildUtils.PartyRoller:ShowPhaseA() end)

    c.HubPanel.btnEndGroup = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnEndGroup:SetSize(160, 26)
    c.HubPanel.btnEndGroup:SetPoint("BOTTOM", 0, 10)
    c.HubPanel.btnEndGroup:SetText("End Group Event")
    c.HubPanel.btnEndGroup:SetScript("OnClick", function() 
        GuildUtils.LootCoin:EndGroupEvent()
        
        GuildUtils.PartyRoller:ResetIdlePanel()
        GuildUtils.PartyRoller:SetUIState("IDLE_PANEL") 
    end)

    c.PhaseA = CreateFrame("Frame", nil, c)
    c.PhaseA:SetAllPoints(c)
    c.PhaseA:EnableMouse(true)
    c.PhaseA:Hide()

    c.PhaseA.scrollFrame = CreateFrame("ScrollFrame", nil, c.PhaseA, "UIPanelScrollFrameTemplate")
    c.PhaseA.scrollFrame:SetPoint("TOPLEFT", 10, -40)
    c.PhaseA.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    c.PhaseA.scrollChild = CreateFrame("Frame")
    c.PhaseA.scrollChild:SetSize(160, 1)
    c.PhaseA.scrollFrame:SetScrollChild(c.PhaseA.scrollChild)

    c.PhaseA.confirmBtn = CreateFrame("Button", nil, c.PhaseA, "UIPanelButtonTemplate")
    c.PhaseA.confirmBtn:SetSize(120, 24)
    c.PhaseA.confirmBtn:SetPoint("BOTTOM", 0, 10)
    c.PhaseA.confirmBtn:SetText("Start Roll")
    c.PhaseA.confirmBtn:SetScript("OnClick", function()
        local duration = tonumber(c.PhaseA.timerInput:GetText()) or 10
        local queueData = {}
        for i, item in ipairs(GU_PendingLoot) do 
            table.insert(queueData, { link = item, reserved = GU_ReservedStatus[i] }) 
        end
        if #queueData > 0 then
            GuildUtils.PartyRoller:HostStartQueue(queueData, duration)
        else
            GuildUtils:Print("No items in queue to roll.", true)
        end
    end)

    c.PhaseA.timerInput = CreateFrame("EditBox", nil, c.PhaseA, "InputBoxTemplate")
    c.PhaseA.timerInput:SetSize(35, 20)
    c.PhaseA.timerInput:SetPoint("BOTTOMRIGHT", c.PhaseA.confirmBtn, "TOPRIGHT", -5, 5)
    c.PhaseA.timerInput:SetNumeric(true)
    c.PhaseA.timerInput:SetAutoFocus(false)
    c.PhaseA.timerInput:SetText("10")

    c.PhaseA.timerLabel = c.PhaseA:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.PhaseA.timerLabel:SetPoint("RIGHT", c.PhaseA.timerInput, "LEFT", -5, 0)
    c.PhaseA.timerLabel:SetText("Timer (s):")

    c.PhaseA:SetScript("OnReceiveDrag", function()
        local infoType, _, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            table.insert(GU_PendingLoot, itemLink)
            table.insert(GU_ReservedStatus, false)
            ClearCursor()
            GuildUtils.PartyRoller:ShowPhaseA()
        end
    end)

    c.PhaseB = CreateFrame("Frame", nil, c)
    c.PhaseB:SetAllPoints(c)
    c.PhaseB:Hide()
    
    local cb = c.PhaseB
    cb.queueText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.queueText:SetPoint("TOPLEFT", 15, -8)
    
    cb.timerText = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cb.timerText:SetPoint("TOPRIGHT", -15, -8)

    cb.embeddedTooltip = CreateFrame("GameTooltip", "GuildUtilsRollTooltip", cb, "GameTooltipTemplate")
    cb.embeddedTooltip:SetPoint("TOP", cb, "TOP", 0, -25)
    cb.embeddedTooltip:SetScale(0.85) 
    cb.embeddedTooltip:Hide()

    cb.passBtn = CreateFrame("Button", nil, cb, "UIPanelButtonTemplate")
    cb.passBtn:SetSize(75, 24)
    cb.passBtn:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -15, 50)
    cb.passBtn:SetText("Pass")
    cb.passBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Pass") end)

    cb.greedBtn = CreateFrame("Button", nil, cb, "UIPanelButtonTemplate")
    cb.greedBtn:SetSize(75, 24)
    cb.greedBtn:SetPoint("RIGHT", cb.passBtn, "LEFT", -5, 0)
    cb.greedBtn:SetText("Greed")
    cb.greedBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Greed") end)

    cb.needBtn = CreateFrame("Button", nil, cb, "UIPanelButtonTemplate")
    cb.needBtn:SetSize(75, 24)
    cb.needBtn:SetPoint("RIGHT", cb.greedBtn, "LEFT", -5, 0)
    cb.needBtn:SetText("Need")
    cb.needBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Need") end)

    cb.infoText = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.infoText:SetPoint("BOTTOM", cb.greedBtn, "TOP", 0, 10)
    cb.infoText:SetWidth(230)
    cb.infoText:SetJustifyH("CENTER")

    cb.reservedWarning = cb:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    cb.reservedWarning:SetPoint("BOTTOM", cb.infoText, "TOP", 0, 5)
    cb.reservedWarning:SetText("RESERVED ITEM: Gambit Active")
    cb.reservedWarning:Hide()

    cb.leaderboardRows = {}
    for i = 1, 5 do
        local r = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT", 20, 100 + ((5 - i) * 16)) 
        r:SetWidth(220)
        r:SetJustifyH("LEFT")
        r:Hide()
        cb.leaderboardRows[i] = r
    end

    cb.closeBtn = CreateFrame("Button", nil, cb, "UIPanelButtonTemplate")
    cb.closeBtn:SetSize(130, 24)
    cb.closeBtn:SetPoint("BOTTOM", 0, 15)
    cb.closeBtn:SetText("Next Item")
    cb.closeBtn:Hide()
    cb.closeBtn:SetScript("OnClick", function()
        if GuildUtils:IsMasterLootActive() or GuildUtils.SoloMode then
            GuildUtils.PartyRoller:HostNextItem()
        end
    end)

    c.PhaseC = CreateFrame("Frame", nil, c)
    c.PhaseC:SetAllPoints(c)
    c.PhaseC:Hide()
    c.PhaseC.scroll = CreateFrame("ScrollFrame", nil, c.PhaseC, "UIPanelScrollFrameTemplate")
    c.PhaseC.scroll:SetPoint("TOPLEFT", 10, -10)
    c.PhaseC.scroll:SetPoint("BOTTOMRIGHT", -30, 45)
    c.PhaseC.scrollChild = CreateFrame("Frame", nil, c.PhaseC.scroll)
    c.PhaseC.scrollChild:SetSize(210, 200)
    c.PhaseC.scroll:SetScrollChild(c.PhaseC.scrollChild)

    c.PhaseC.closeBtn = CreateFrame("Button", nil, c.PhaseC, "UIPanelButtonTemplate")
    c.PhaseC.closeBtn:SetSize(120, 24)
    c.PhaseC.closeBtn:SetPoint("BOTTOM", 0, 15)
    c.PhaseC.closeBtn:SetText("Close Summary")
    c.PhaseC.closeBtn:SetScript("OnClick", function()
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then 
            GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
        else 
            GuildUtils.PartyRoller:ResetIdlePanel()
            GuildUtils.PartyRoller:SetUIState("IDLE_PANEL") 
        end 
    end)

    f:SetScript("OnHide", function()
        if GuildUtils.PartyRoller.State == "RESULTS" then GuildUtils.PartyRoller:TriggerResultsClosed() end
    end)

    return f
end

function GuildUtils.PartyRoller:SetUIState(state)
    local f = self:InitializeUI()
    self.State = state
    local c = f.GLContainer
    c.IdlePanel:Hide()
    c.HubPanel:Hide()
    c.PhaseA:Hide()
    c.PhaseB:Hide()
    c.PhaseC:Hide()

    if state == "IDLE_PANEL" then c.IdlePanel:Show(); f:Show()
    elseif state == "HUB_PANEL" then c.HubPanel:Show(); f:Show()
    elseif state == "PHASE_A" then c.PhaseA:Show(); f:Show()
    elseif state == "BIDDING" or state == "RESULTS" then 
        c.PhaseB:Show(); f:Show()
        f:SetHeight(480)
    elseif state == "PHASE_C" then c.PhaseC:Show(); f:Show() end
    
    if state ~= "BIDDING" and state ~= "RESULTS" then
        f:SetHeight(480)
    end
end

function GuildUtils.PartyRoller:ShowPhaseA()
    self:SetUIState("PHASE_A")
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseA
    for _, child in ipairs({c.scrollChild:GetChildren()}) do child:Hide() end
    
    local themeIndex = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = (GuildUtils.Styles and GuildUtils.Styles[themeIndex]) or {nameColor={1,0.96,0.41,1}, balColor={1,1,1,1}}

    local yOffset = -5
    for i, itemLink in ipairs(GU_PendingLoot) do
        local row = CreateFrame("Frame", nil, c.scrollChild)
        row:SetSize(160, 30); row:SetPoint("TOPLEFT", 0, yOffset)
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", 2, 0); text:SetWidth(110); text:SetJustifyH("LEFT"); text:SetText(itemLink); text:SetTextColor(unpack(style.nameColor))
        local resCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        resCheck:SetScale(0.7); resCheck:SetPoint("RIGHT", 0, 0); resCheck:SetChecked(GU_ReservedStatus[i]); resCheck:SetScript("OnClick", function(cbSelf) GU_ReservedStatus[i] = cbSelf:GetChecked() end)
        yOffset = yOffset - 35
    end
    c.scrollChild:SetHeight(math.max(50, math.abs(yOffset)))
end

function GuildUtils.PartyRoller:ShowPhaseC()
    self:SetUIState("PHASE_C")
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseC
    for _, child in ipairs({c.scrollChild:GetChildren()}) do child:Hide() end
    
    local themeIndex = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = (GuildUtils.Styles and GuildUtils.Styles[themeIndex]) or {nameColor={1,0.96,0.41,1}, balColor={1,1,1,1}}

    local yOffset = -10
    for _, result in ipairs(self.QueueResults) do
        local row = CreateFrame("Frame", nil, c.scrollChild)
        row:SetSize(160, 30); row:SetPoint("TOPLEFT", 0, yOffset)
        local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); itemText:SetPoint("LEFT", 2, 0); itemText:SetWidth(90); itemText:SetJustifyH("LEFT"); itemText:SetText(result.link); itemText:SetTextColor(unpack(style.nameColor))
        local winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); winnerText:SetPoint("RIGHT", -2, 0); winnerText:SetTextColor(unpack(style.balColor))
        if result.amount > 0 then winnerText:SetText(string.format("%s(%d)", result.winner, result.amount))
        else winnerText:SetText(result.winner) end
        yOffset = yOffset - 35
    end
    c.scrollChild:SetHeight(math.abs(yOffset))
end

function GuildUtils.PartyRoller:TriggerWagerModal(bidType)
    if bidType == "Pass" then self:SubmitRoll("Pass", 0) return end
    
    self.PendingBidType = bidType
    local itemLink = self.CurrentItemData and self.CurrentItemData.link or "Unknown Item"
    local warningTxt = (bidType == "Greed" and self.CurrentItemData and self.CurrentItemData.reserved) 
        and "|cFFFF0000WARNING: Thief's Gambit active. LC is permanently burned.|r" 
        or "Standard Roll"
        
    StaticPopup_Show("GUILDUTILS_WAGER_MODAL", itemLink, warningTxt)
end

function GuildUtils.PartyRoller:HostStartQueue(queueData, duration)
    self.Queue = queueData
    self.QueueIndex = 1
    self.Duration = duration or 10
    
    local parts = {}
    for _, itemData in ipairs(self.Queue) do table.insert(parts, itemData.link .. "@@" .. tostring(itemData.reserved)) end
    
    if GuildUtils.SoloMode then 
        self:ClientStartQueue(string.format("%d:%s", self.Duration, table.concat(parts, ";;"))) 
        return 
    end
    
    GuildUtils:QueueMessage("START_QUEUE:" .. string.format("%d:%s", self.Duration, table.concat(parts, ";;")), "GUILD")
    self:ClientStartQueue(string.format("%d:%s", self.Duration, table.concat(parts, ";;")))
end

function GuildUtils.PartyRoller:ClientStartQueue(payload)
    local durationStr, linksBlob = string.match(payload, "^([^:]+):(.*)$")
    self.Duration = tonumber(durationStr) or 10
    self.Queue = {}
    if linksBlob then
        for chunk in string.gmatch(linksBlob, "([^;;]+)") do
            local link, reservedStr = string.match(chunk, "^(.*)@@(.*)$")
            if link and link ~= "" then table.insert(self.Queue, {link = link, reserved = (reservedStr == "true")}) end
        end
    end
    self.QueueIndex = 1
    self.QueueResults = {}
    if #self.Queue > 0 then self:StartBidding(self.Queue[1]) end
end

function GuildUtils.PartyRoller:ClientAdvanceQueue(index)
    self.QueueIndex = index
    if self.Queue[self.QueueIndex] then self:StartBidding(self.Queue[self.QueueIndex]) end
end

function GuildUtils.PartyRoller:ClientFinishQueue()
    if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
    
    if #self.Queue > 1 then 
        self:ShowPhaseC() 
    else 
        self.Queue = {}
        self.QueueIndex = 0
        self.QueueResults = {}
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        self.HasResponded = false
        
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then
            self:SetUIState("HUB_PANEL")
        else
            self:ResetIdlePanel()
            self:SetUIState("IDLE_PANEL")
        end
    end
end

function GuildUtils.PartyRoller:HostNextItem()
    if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
    self.QueueIndex = self.QueueIndex + 1
    if self.QueueIndex > #self.Queue then
        if not GuildUtils.SoloMode then GuildUtils:QueueMessage("QUEUE_FINISHED", "GUILD") end
        self:ClientFinishQueue()
    else
        if not GuildUtils.SoloMode then GuildUtils:QueueMessage("NEXT_ITEM:" .. self.QueueIndex, "GUILD") end
        self:StartBidding(self.Queue[self.QueueIndex])
    end
end

function GuildUtils.PartyRoller:StartBidding(itemData)
    self.CurrentItemData = itemData
    self.ActiveBids = {}
    self.HasResponded = false
    self:SetUIState("BIDDING")
    
    local f = GuildUtils.DashboardFrame
    local c = f.GLContainer.PhaseB
    
    c.embeddedTooltip:SetOwner(c, "ANCHOR_PRESERVE")
    c.embeddedTooltip:ClearAllPoints()
    c.embeddedTooltip:SetPoint("TOP", c, "TOP", 0, -25)
    c.embeddedTooltip:SetHyperlink(itemData.link)
    c.embeddedTooltip:Show()
    
    c.passBtn:Enable()
    c.passBtn:Show()
    c.greedBtn:Enable()
    c.greedBtn:Show()
    c.needBtn:Enable()
    c.needBtn:Show()
    c.closeBtn:Hide()
    for i = 1, 5 do c.leaderboardRows[i]:Hide() end
    
    if itemData.reserved then
        c.needBtn:Hide()
        c.greedBtn:SetText("Gambit")
        c.reservedWarning:Show()
    else
        c.greedBtn:SetText("Greed")
        c.reservedWarning:Hide()
    end
    
    c.queueText:SetText(#self.Queue > 1 and string.format("Item %d of %d", self.QueueIndex, #self.Queue) or "Priority Roll")
    
    local myBalance = 0
    local localSpent = 0
    if GU_GlobalDB and GU_GlobalDB.Ledger then
        local myGuid = UnitGUID("player")
        if GU_GlobalDB.Ledger.balances then
            myBalance = GU_GlobalDB.Ledger.balances[myGuid] or 0
        end
        if GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members and GU_GlobalDB.Ledger.ActiveSession.members[myGuid] then
            localSpent = GU_GlobalDB.Ledger.ActiveSession.members[myGuid].change or 0
        end
    end
    
    self.MaxAvailable = math.max(0, myBalance + localSpent)
    c.infoText:SetText("Avail: |cFF00FF00" .. self.MaxAvailable .. "|r")

    local startTime = GetTime()
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    self.CountdownTimer = C_Timer.NewTicker(0.5, function()
        local remaining = math.ceil(self.Duration - (GetTime() - startTime))
        if remaining > 0 then c.timerText:SetText(string.format("%ds", remaining))
        else
            if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
            self:ShowResults()
        end
    end)
end

function GuildUtils.PartyRoller:SubmitRoll(bidType, amount)
    if self.HasResponded or self.State ~= "BIDDING" then return end
    
    if bidType ~= "Pass" and amount > (self.MaxAvailable or 0) then
        GuildUtils:Print("Insufficient LC for this wager. You have " .. (self.MaxAvailable or 0) .. " LC.", true)
        return
    end

    self.HasResponded = true
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseB
    c.needBtn:Hide(); c.greedBtn:Hide(); c.passBtn:Hide(); c.reservedWarning:Hide()
    for i = 1, 5 do c.leaderboardRows[i]:Show() end
    c.infoText:SetText("|cFFFFFF00Bid Submitted. Waiting on others...|r")
    
    local payload = string.format("%s:%d:%s", bidType, amount, UnitGUID("player"))
    C_Timer.After(GuildUtils.SoloMode and 0 or (math.random() * 0.5), function()
        if GuildUtils:IsMasterLootActive() then self:HostProcessBid(UnitName("player"), payload)
        else GuildUtils:QueueMessage("BID_INTENT:" .. payload, "GUILD") end
    end)
end

function GuildUtils.PartyRoller:HostProcessBid(senderName, payload)
    local bidType, amtStr, guid = strsplit(":", payload)
    local amount = tonumber(amtStr) or 0

    if bidType ~= "Pass" then
        local sessionSpent = 0
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members and GU_GlobalDB.Ledger.ActiveSession.members[guid] then
            sessionSpent = GU_GlobalDB.Ledger.ActiveSession.members[guid].change or 0
        end
        local realAvailable = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.balances and GU_GlobalDB.Ledger.balances[guid] or 0) + sessionSpent
        if amount > realAvailable then return end
    else amount = 0 end
    
    local baseRoll = bidType == "Need" and math.random(1, 100) or (bidType == "Greed" and math.random(1, 90) or 0)
    local confirmMsg = string.format("%s:%s:%d:%d:%s:%d", senderName, bidType, amount, baseRoll, guid, math.random(1, 100))
    GuildUtils:QueueMessage("BID_CONFIRMED:" .. confirmMsg, "GUILD")
    self:OnBidConfirmed(confirmMsg)
end

function GuildUtils.PartyRoller:OnBidConfirmed(payload)
    local player, bidType, amtStr, baseStr, guid, tieStr = strsplit(":", payload)
    for _, bid in ipairs(self.ActiveBids) do if bid.guid == guid then return end end
    table.insert(self.ActiveBids, {player = player, guid = guid, bidType = bidType, amount = tonumber(amtStr) or 0, baseRoll = tonumber(baseStr) or 0, totalScore = (tonumber(amtStr) or 0) + (tonumber(baseStr) or 0), tieRoll = tonumber(tieStr) or 0})
    self:UpdateSpectatorBoard()
end

function GuildUtils.PartyRoller:UpdateSpectatorBoard()
    if not GuildUtils.DashboardFrame or not GuildUtils.DashboardFrame:IsShown() then return end
    local typeRank = { Need = 2, Greed = 1, Pass = 0 }
    
    table.sort(self.ActiveBids, function(a, b)
        if a.bidType == "Pass" and b.bidType ~= "Pass" then return false end
        if b.bidType == "Pass" and a.bidType ~= "Pass" then return true end
        if a.totalScore ~= b.totalScore then return a.totalScore > b.totalScore end
        
        local rankA = typeRank[a.bidType] or -1
        local rankB = typeRank[b.bidType] or -1
        if rankA ~= rankB then return rankA > rankB end
        
        if a.amount ~= b.amount then return a.amount > b.amount end
        if a.tieRoll ~= b.tieRoll then return a.tieRoll > b.tieRoll end
        return a.guid > b.guid
    end)
    
    local themeIndex = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = (GuildUtils.Styles and GuildUtils.Styles[themeIndex]) or {nameColor={1,0.96,0.41,1}, balColor={1,1,1,1}}
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseB

    for i = 1, 5 do
        local bid, row = self.ActiveBids[i], c.leaderboardRows[i]
        if bid then
            row:Show() 
            if bid.bidType == "Pass" then row:SetText(string.format("%d. %s - Pass", i, bid.player)); row:SetTextColor(0.5, 0.5, 0.5)
            else row:SetText(string.format("%d. %s%s|r (%s|S:%d)", i, bid.bidType == "Need" and "|cFF00FF00" or "|cFFFFFF00", bid.player, bid.bidType:sub(1,1), bid.totalScore)); row:SetTextColor(unpack(style.nameColor)) end
        else 
            row:SetText("")
            row:Hide()
        end
    end
end

function GuildUtils.PartyRoller:ShowResults()
    self.State = "RESULTS"
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseB
    
    if c.needBtn then c.needBtn:Hide(); c.needBtn:Disable() end
    if c.greedBtn then c.greedBtn:Hide(); c.greedBtn:Disable() end
    if c.passBtn then c.passBtn:Hide(); c.passBtn:Disable() end
    if c.reservedWarning then c.reservedWarning:Hide() end

    self:UpdateSpectatorBoard()
    
    local winnerBid = self.ActiveBids[1]
    if winnerBid and winnerBid.bidType == "Pass" then winnerBid = nil end
    
    local itemLink = self.CurrentItemData and self.CurrentItemData.link or "Unknown Item"
    self.QueueResults[self.QueueIndex] = { link = itemLink, winner = winnerBid and winnerBid.player or "No Winner", amount = winnerBid and winnerBid.amount or 0 }
    
    for _, bid in ipairs(self.ActiveBids) do
        if bid.bidType == "Greed" and self.CurrentItemData and self.CurrentItemData.reserved then
            if not winnerBid or winnerBid.guid ~= bid.guid then
                local bidGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(bid.guid) or bid.guid
                if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then 
                    GuildUtils.LootCoin:UpdateTempLedger(bidGuid, -bid.amount)
                elseif GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then 
                    GuildUtils.LootCoin:ProcessTransaction(bidGuid, bid.player, -bid.amount, "Gambit Lost: " .. itemLink) 
                end
            end
        end
    end
    
    if winnerBid then
        local winnerGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(winnerBid.guid) or winnerBid.guid
        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then 
            GuildUtils.LootCoin:UpdateTempLedger(winnerGuid, -winnerBid.amount)
        elseif GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then 
            GuildUtils.LootCoin:ProcessTransaction(winnerGuid, winnerBid.player, -winnerBid.amount, "Won item: " .. itemLink) 
        end
        if GuildUtils:IsMasterLootActive() then self:AutomateMasterLootHandout(winnerBid.player) end
    end
    
    c.infoText:SetText(winnerBid and string.format("WINNER: |cFF00FF00%s|r", winnerBid.player) or "No Bids Placed.")
    
    c.closeBtn:SetText(#self.Queue > 1 and "Next Item" or "Finish")
    c.closeBtn:Show()
    
    local resultsDuration = 5
    local startTime = GetTime()
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    self.CountdownTimer = C_Timer.NewTicker(0.5, function()
        local remaining = math.ceil(resultsDuration - (GetTime() - startTime))
        if remaining > 0 then
            c.timerText:SetText(#self.Queue > 1 and string.format("Next in %ds", remaining) or string.format("Finishing in %ds", remaining))
        else
            if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
            if GuildUtils:IsMasterLootActive() or GuildUtils.SoloMode then 
                self:HostNextItem() 
            else
                c.timerText:SetText("Waiting on Host...")
                C_Timer.After(15, function() if self.State == "RESULTS" then self:ClientFinishQueue() end end)
            end
        end
    end)
end

function GuildUtils.PartyRoller:TriggerResultsClosed()
    if GuildUtils.SoloMode then return end
    GuildUtils:QueueMessage("RESULTS_CLOSED:" .. self.QueueIndex, "GUILD")
end

function GuildUtils.PartyRoller:AutomateMasterLootHandout(winnerName)
    if not GuildUtils:IsMasterLootActive() or not winnerName then return end
    for slot = 1, (GetNumLootItems() or 0) do
        if GetLootSlotLink(slot) == self.CurrentItemData.link then
            for ci = 1, 40 do
                local candidate = GetMasterLootCandidate(slot, ci)
                if candidate and GuildUtils:FormatName(candidate) == GuildUtils:FormatName(winnerName) then
                    GiveMasterLoot(slot, ci)
                    GuildUtils:Print(string.format("Automatically assigned %s to %s via Master Loot.", self.CurrentItemData.link, winnerName), false)
                    return
                end
            end
        end
    end
end

function GuildUtils.PartyRoller:ShowRaidResultsModal(rosterData)
    if not StaticPopupDialogs["GUILDUTILS_GENERIC_RESULTS"] then
        StaticPopupDialogs["GUILDUTILS_GENERIC_RESULTS"] = {
            text = "Group event ended.\nSession deductions have been merged into the master ledger.",
            button1 = "OK",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end
    StaticPopup_Show("GUILDUTILS_GENERIC_RESULTS")
end