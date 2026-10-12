local addonName, GuildUtils = ...
GuildUtils.PartyRoller = {}
GuildUtils.PartyRoller.ActiveBids = {}
GuildUtils.PartyRoller.CurrentItemData = nil
GuildUtils.PartyRoller.Queue = {}
GuildUtils.PartyRoller.QueueIndex = 0
GuildUtils.PartyRoller.QueueResults = {}
GuildUtils.PartyRoller.Duration = 10
GuildUtils.PartyRoller.State = "IDLE"

local GU_PendingLoot = {}
local GU_ReservedStatus = {}

local function SafeAnnounce(msg)
    if IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        SendChatMessage(msg, "RAID_WARNING")
    elseif IsInGroup() then
        SendChatMessage(msg, "PARTY")
    else
        GuildUtils:Print("Announce: " .. msg, false)
    end
end

StaticPopupDialogs["GUILDUTILS_ANNOUNCE"] = {
    text = "Enter Announcement:",
    button1 = "Send", button2 = "Cancel",
    hasEditBox = true, maxLetters = 255,
    OnAccept = function(self)
        local text = self.EditBox:GetText()
        if text ~= "" then SafeAnnounce(text) end
    end,
    OnShow = function(self) self.EditBox:SetText(""); self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_PULL_TIMER"] = {
    text = "Enter Pull Timer (Seconds):",
    button1 = "Start", button2 = "Cancel",
    hasEditBox = true, maxLetters = 3,
    OnAccept = function(self)
        local secs = tonumber(self.EditBox:GetText())
        if secs and secs > 0 and C_PartyInfo and C_PartyInfo.DoCountdown then
            C_PartyInfo.DoCountdown(secs)
        end
    end,
    OnShow = function(self) self.EditBox:SetText("10"); self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_BREAK_TIMER"] = {
    text = "Enter Break Duration (Minutes):",
    button1 = "Start Break", button2 = "Cancel",
    hasEditBox = true, maxLetters = 3,
    OnAccept = function(self)
        local mins = tonumber(self.EditBox:GetText())
        if mins and mins > 0 then
            local timeText = string.format("%d minute%s", mins, mins > 1 and "s" or "")
            SafeAnnounce("Take a Break (" .. timeText .. ")")
            GuildUtils:Print("Break timer started for " .. timeText .. ".", false)
            C_Timer.After(mins * 60, function() DoReadyCheck() end)
        end
    end,
    OnShow = function(self) self.EditBox:SetText("5"); self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_WAGER_MODAL"] = {
    text = "Enter LC Wager for %s:\n%s",
    button1 = "Submit Bid", button2 = "Cancel",
    hasEditBox = true, maxLetters = 6,
    OnAccept = function(selfPopup, data)
        local amount = tonumber(selfPopup.EditBox:GetText())
        if amount and amount >= 0 then GuildUtils.PartyRoller:SubmitRoll(data.bidType, amount)
        else GuildUtils:Print("Invalid wager amount.", true) end
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText("1"); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function GuildUtils.PartyRoller:ParseBidCommand(msg)
    if not GuildUtils.SoloMode then
        if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.ActiveSession then
            GuildUtils:Print("You must start a group event (/gustartgroup) before rolling items.", true) return
        end
        if not GuildUtils:IsMasterLootActive() then GuildUtils:Print("Only the group leader or master looter can initiate rolls.", true) return end
    end

    GU_PendingLoot = {}
    GU_ReservedStatus = {}
    if msg == "" then GuildUtils:Print("Usage: /gubid [Item Link] or drop item in frame", true) return end

    for link in string.gmatch(msg, "(|c.-|Hitem:.-|h.-|h|r)") do table.insert(GU_PendingLoot, link) end
    if #GU_PendingLoot == 0 then table.insert(GU_PendingLoot, msg) end
    
    if #GU_PendingLoot > 0 then
        for i = 1, #GU_PendingLoot do table.insert(GU_ReservedStatus, false) end
        self:ShowPhaseA()
    end
end

function GuildUtils.PartyRoller:RefreshState()
    local s = self.State
    if s == "BIDDING" or s == "RESULTS" then self:SetUIState(s)
    elseif s == "PHASE_A" then self:ShowPhaseA()
    elseif s == "PHASE_C" then self:ShowPhaseC()
    elseif GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then self:SetUIState("HUB_PANEL")
    else self:SetUIState("IDLE_PANEL") end
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
    f:Hide(); f:SetPoint("CENTER", 320, 0)
    GuildUtils.DashboardFrame = f
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("GuildUtils: Gear & Loot Manager")
    
    -- UI TABS ----------------------------------------------------
    f.tabGL = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabGL:SetSize(100, 24)
    f.tabGL:SetPoint("BOTTOMLEFT", 15, 10)
    f.tabGL:SetText("Gear & Loot")

    f.tabBounty = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabBounty:SetSize(100, 24)
    f.tabBounty:SetPoint("LEFT", f.tabGL, "RIGHT", 5, 0)
    f.tabBounty:SetText("Bounty Board")

    -- Task 3: Raid Events Tab
    f.tabEvents = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabEvents:SetSize(100, 24)
    f.tabEvents:SetPoint("LEFT", f.tabBounty, "RIGHT", 5, 0)
    f.tabEvents:SetText("Raid Events")

    -- CONTAINERS -------------------------------------------------
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

    -- TAB CLICK HANDLERS -----------------------------------------
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
        
        if GuildUtils.Contracts and GuildUtils.Contracts.InitializeUI then 
            GuildUtils.Contracts:InitializeUI() 
        end
        if GuildUtils.Contracts and GuildUtils.Contracts.UpdateBoard then 
            GuildUtils.Contracts:UpdateBoard() 
        end
    end)

    f.tabEvents:SetScript("OnClick", function()
        f.GLContainer:Hide()
        f.BountyContainer:Hide()
        
        if GuildUtils.Events and GuildUtils.Events.InitializeUI then 
            GuildUtils.Events:InitializeUI() 
        end
        
        f.EventsContainer:Show()
        f:SetSize(600, 440)
        f.title:SetText("GuildUtils: Raid & Event Signups")
        GuildUtils.ActiveTab = "EVENTS"
        
        -- Trigger the render
        if GuildUtils.Events and GuildUtils.Events.UpdateEventList then
            GuildUtils.Events:UpdateEventList()
        end
    end)

    -- GL CONTAINER PANELS ----------------------------------------
    local c = f.GLContainer

    c.IdlePanel = CreateFrame("Frame", nil, c); c.IdlePanel:SetAllPoints(c); c.IdlePanel:Hide()
    c.IdlePanel.info = c.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.IdlePanel.info:SetPoint("TOP", 0, -60)
    c.IdlePanel.info:SetText("No active group event.")
    c.IdlePanel.startBtn = CreateFrame("Button", nil, c.IdlePanel, "UIPanelButtonTemplate")
    c.IdlePanel.startBtn:SetSize(140, 24)
    c.IdlePanel.startBtn:SetPoint("CENTER", 0, 20)
    c.IdlePanel.startBtn:SetText("Start Group Event")
    c.IdlePanel.startBtn:SetScript("OnClick", function()
        if not GuildUtils:IsMasterLootActive() then return GuildUtils:Print("You are not the leader/master looter.", true) end
        GuildUtils.LootCoin:StartGroupEvent()
        GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
    end)

    c.HubPanel = CreateFrame("Frame", nil, c); c.HubPanel:SetAllPoints(c); c.HubPanel:Hide()
    
    c.HubPanel.btnRollCall = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnRollCall:SetSize(160, 26); c.HubPanel.btnRollCall:SetPoint("TOP", 0, -45)
    c.HubPanel.btnRollCall:SetText("Roll Call")
    c.HubPanel.btnRollCall:SetScript("OnClick", function() DoReadyCheck() end)

    c.HubPanel.btnAnnounce = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnAnnounce:SetSize(160, 26); c.HubPanel.btnAnnounce:SetPoint("TOP", 0, -80)
    c.HubPanel.btnAnnounce:SetText("Announce")
    c.HubPanel.btnAnnounce:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_ANNOUNCE") end)

    c.HubPanel.btnPullTimer = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnPullTimer:SetSize(160, 26); c.HubPanel.btnPullTimer:SetPoint("TOP", 0, -115)
    c.HubPanel.btnPullTimer:SetText("Pull Timer")
    c.HubPanel.btnPullTimer:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_PULL_TIMER") end)

    c.HubPanel.btnBreak = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnBreak:SetSize(160, 26); c.HubPanel.btnBreak:SetPoint("TOP", 0, -150)
    c.HubPanel.btnBreak:SetText("Break")
    c.HubPanel.btnBreak:SetScript("OnClick", function() StaticPopup_Show("GUILDUTILS_BREAK_TIMER") end)

    c.HubPanel.btnLoot = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnLoot:SetSize(160, 26); c.HubPanel.btnLoot:SetPoint("TOP", 0, -185)
    c.HubPanel.btnLoot:SetText("Loot")
    c.HubPanel.btnLoot:SetScript("OnClick", function() GuildUtils.PartyRoller:ShowPhaseA() end)

    c.HubPanel.btnEndGroup = CreateFrame("Button", nil, c.HubPanel, "UIPanelButtonTemplate")
    c.HubPanel.btnEndGroup:SetSize(160, 26); c.HubPanel.btnEndGroup:SetPoint("BOTTOM", 0, 10)
    c.HubPanel.btnEndGroup:SetText("End Group Event")
    c.HubPanel.btnEndGroup:SetScript("OnClick", function() GuildUtils.LootCoin:EndGroupEvent(); GuildUtils.PartyRoller:SetUIState("IDLE_PANEL") end)

    c.PhaseA = CreateFrame("Frame", nil, c); c.PhaseA:SetAllPoints(c); c.PhaseA:EnableMouse(true); c.PhaseA:Hide()
    c.PhaseA.scrollFrame = CreateFrame("ScrollFrame", nil, c.PhaseA, "UIPanelScrollFrameTemplate")
    c.PhaseA.scrollFrame:SetPoint("TOPLEFT", 10, -40); c.PhaseA.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    c.PhaseA.scrollChild = CreateFrame("Frame"); c.PhaseA.scrollChild:SetSize(160, 1); c.PhaseA.scrollFrame:SetScrollChild(c.PhaseA.scrollChild)
    
    c.PhaseA.confirmBtn = CreateFrame("Button", nil, c.PhaseA, "UIPanelButtonTemplate"); c.PhaseA.confirmBtn:SetSize(140, 24); c.PhaseA.confirmBtn:SetPoint("BOTTOM", 0, 10); c.PhaseA.confirmBtn:SetText("Start Roll Queue")
    c.PhaseA.confirmBtn:SetScript("OnClick", function()
        local duration = tonumber(c.PhaseA.timerInput:GetText()) or 10
        local queueData = {}
        for i, item in ipairs(GU_PendingLoot) do table.insert(queueData, {link = item, reserved = GU_ReservedStatus[i]}) end
        GuildUtils.PartyRoller:HostStartQueue(queueData, duration)
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
    
    c.PhaseA:SetScript("OnReceiveDrag", function(selfFrm)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            table.insert(GU_PendingLoot, itemLink); table.insert(GU_ReservedStatus, false); ClearCursor(); GuildUtils.PartyRoller:ShowPhaseA()
        end
    end)

    c.PhaseB = CreateFrame("Frame", nil, c); c.PhaseB:SetAllPoints(c); c.PhaseB:Hide()
    c.PhaseB.queueText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.PhaseB.queueText:SetPoint("TOPLEFT", 10, -10)
    c.PhaseB.timerText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.PhaseB.timerText:SetPoint("TOPRIGHT", -10, -10); c.PhaseB.timerText:SetTextColor(1, 0.8, 0)
    
    c.PhaseB.embeddedTooltip = CreateFrame("GameTooltip", "GuildUtilsRollTooltip", c.PhaseB, "GameTooltipTemplate")
    c.PhaseB.embeddedTooltip:SetPoint("TOP", c.PhaseB, "TOP", 0, -25)
    c.PhaseB.embeddedTooltip:SetScale(0.85)
    c.PhaseB.embeddedTooltip:Hide()

    c.PhaseB.infoText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.PhaseB.infoText:SetPoint("TOP", c.PhaseB.embeddedTooltip, "BOTTOM", 0, -8)
    c.PhaseB.reservedWarning = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.PhaseB.reservedWarning:SetPoint("TOP", c.PhaseB.infoText, "BOTTOM", 0, -4); c.PhaseB.reservedWarning:SetTextColor(1, 0, 0); c.PhaseB.reservedWarning:SetText("RESERVED ITEM")
    
    c.PhaseB.leaderboardRows = {}
    for i = 1, 5 do
        local row = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOP", c.PhaseB.infoText, "BOTTOM", 0, -24 - ((i-1) * 14))
        row:SetSize(240, 14); row:SetJustifyH("CENTER")
        c.PhaseB.leaderboardRows[i] = row
    end

    c.PhaseB.needBtn = CreateFrame("Button", nil, c.PhaseB, "UIPanelButtonTemplate"); c.PhaseB.needBtn:SetSize(65, 22); c.PhaseB.needBtn:SetPoint("BOTTOMLEFT", 10, 10); c.PhaseB.needBtn:SetText("Need"); c.PhaseB.needBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Need") end)
    c.PhaseB.greedBtn = CreateFrame("Button", nil, c.PhaseB, "UIPanelButtonTemplate"); c.PhaseB.greedBtn:SetSize(65, 22); c.PhaseB.greedBtn:SetPoint("BOTTOM", 0, 10); c.PhaseB.greedBtn:SetText("Greed"); c.PhaseB.greedBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Greed") end)
    c.PhaseB.passBtn = CreateFrame("Button", nil, c.PhaseB, "UIPanelButtonTemplate"); c.PhaseB.passBtn:SetSize(65, 22); c.PhaseB.passBtn:SetPoint("BOTTOMRIGHT", -10, 10); c.PhaseB.passBtn:SetText("Pass"); c.PhaseB.passBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:SubmitRoll("Pass", 0) end)
    c.PhaseB.closeBtn = CreateFrame("Button", nil, c.PhaseB, "UIPanelButtonTemplate"); c.PhaseB.closeBtn:SetSize(110, 24); c.PhaseB.closeBtn:SetPoint("BOTTOM", 0, 10); c.PhaseB.closeBtn:SetScript("OnClick", function() if GuildUtils:IsMasterLootActive() then GuildUtils.PartyRoller:HostNextItem() end end)

    c.PhaseC = CreateFrame("Frame", nil, c); c.PhaseC:SetAllPoints(c); c.PhaseC:Hide()
    c.PhaseC.scrollFrame = CreateFrame("ScrollFrame", nil, c.PhaseC, "UIPanelScrollFrameTemplate")
    c.PhaseC.scrollFrame:SetPoint("TOPLEFT", 10, -40); c.PhaseC.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    c.PhaseC.scrollChild = CreateFrame("Frame"); c.PhaseC.scrollChild:SetSize(160, 1); c.PhaseC.scrollFrame:SetScrollChild(c.PhaseC.scrollChild)
    c.PhaseC.closeBtn = CreateFrame("Button", nil, c.PhaseC, "UIPanelButtonTemplate"); c.PhaseC.closeBtn:SetSize(110, 24); c.PhaseC.closeBtn:SetPoint("BOTTOM", 0, 10); c.PhaseC.closeBtn:SetText("Clear Queue"); c.PhaseC.closeBtn:SetScript("OnClick", function() GU_PendingLoot = {}; GU_ReservedStatus = {}; GuildUtils.PartyRoller.State = "HUB_PANEL"; GuildUtils.PartyRoller:RefreshState() end)

    GuildUtils.UI:ApplyTheme()
    return f
end

function GuildUtils.PartyRoller:SetUIState(state)
    local f = self:InitializeUI()
    self.State = state
    local c = f.GLContainer
    c.IdlePanel:Hide(); c.HubPanel:Hide(); c.PhaseA:Hide(); c.PhaseB:Hide(); c.PhaseC:Hide()
    
    if state == "IDLE_PANEL" then c.IdlePanel:Show(); f:Show()
    elseif state == "HUB_PANEL" then c.HubPanel:Show(); f:Show()
    elseif state == "PHASE_A" then c.PhaseA:Show(); f:Show()
    elseif state == "BIDDING" or state == "RESULTS" then 
        c.PhaseB:Show(); f:Show()
        if self.CurrentItemData then
            f:SetHeight(340 + (c.PhaseB.embeddedTooltip:GetHeight() or 0))
        end
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
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

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
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

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
    self.Queue = {}; self.QueueIndex = 0; self.QueueResults = {}; GU_PendingLoot = {}; GU_ReservedStatus = {}
end

function GuildUtils.PartyRoller:TriggerWagerModal(bidType)
    if bidType == "Pass" then self:SubmitRoll("Pass", 0) return end
    local warningTxt = (bidType == "Greed" and self.CurrentItemData.reserved) and "|cFFFF0000WARNING: Thief's Gambit active. LC is permanently burned.|r" or "Standard Roll"
    StaticPopup_Show("GUILDUTILS_WAGER_MODAL", bidType, warningTxt, {bidType = bidType})
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
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    
    if #self.Queue > 1 then 
        self:ShowPhaseC() 
    else 
        self.Queue = {}
        self.QueueIndex = 0
        self.QueueResults = {}
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        self.HasResponded = false
        
        self:SetUIState("HUB_PANEL") 
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
    
    if GuildUtils.ActiveTab == "GL" or GuildUtils.ActiveTab == nil then
        f:SetHeight(340 + (c.embeddedTooltip:GetHeight() or 0))
    end
    
    -- Re-enable the buttons for the new roll phase
    c.passBtn:Enable()
    c.passBtn:Show()
    c.greedBtn:Enable()
    c.greedBtn:Show()
    c.closeBtn:Hide()
    for i = 1, 5 do c.leaderboardRows[i]:Hide() end
    
    if itemData.reserved then
        c.needBtn:Hide()
        c.greedBtn:SetText("Gambit")
        c.reservedWarning:Show()
    else
        c.needBtn:Enable()
        c.needBtn:Show()
        c.greedBtn:SetText("Greed")
        c.reservedWarning:Hide()
    end
    
    c.queueText:SetText(#self.Queue > 1 and string.format("Item %d of %d", self.QueueIndex, #self.Queue) or "Priority Roll")
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(UnitGUID("player")) or UnitGUID("player")
    local myBalance = (GU_GlobalDB.Ledger.balances[effGuid] or 0)
    local localSpent = (GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members[effGuid]) and GU_GlobalDB.Ledger.ActiveSession.members[effGuid].change or 0
    c.infoText:SetText("Avail: |cFF00FF00" .. math.max(0, myBalance + localSpent) .. "|r")

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
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(guid) or guid

    if bidType ~= "Pass" then
        local sessionSpent = (GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members[effGuid]) and GU_GlobalDB.Ledger.ActiveSession.members[effGuid].change or 0
        local realAvailable = (GU_GlobalDB.Ledger.balances[effGuid] or 0) + sessionSpent
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
        if typeRank[a.bidType] ~= typeRank[b.bidType] then return typeRank[a.bidType] > typeRank[b.bidType] end
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.guid > b.guid
    end)
    
    local themeIndex = (GU_CharDB and GU_CharDB.Theme) or 1
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseB

    for i = 1, 5 do
        local bid, row = self.ActiveBids[i], c.leaderboardRows[i]
        if bid then
            if bid.bidType == "Pass" then row:SetText(string.format("%d. %s - Pass", i, bid.player)); row:SetTextColor(0.5, 0.5, 0.5)
            else row:SetText(string.format("%d. %s%s|r (%s|S:%d)", i, bid.bidType == "Need" and "|cFF00FF00" or "|cFFFFFF00", bid.player, bid.bidType:sub(1,1), bid.totalScore)); row:SetTextColor(unpack(style.nameColor)) end
        else row:SetText("") end
    end
end

function GuildUtils.PartyRoller:ShowResults()
    self.State = "RESULTS"
    local c = GuildUtils.DashboardFrame.GLContainer.PhaseB
	
    c.needBtn:Hide()
    c.needBtn:Disable()
    c.greedBtn:Hide()
    c.greedBtn:Disable()
    c.passBtn:Hide()
    c.passBtn:Disable()
    c.reservedWarning:Hide()
	
    self:UpdateSpectatorBoard()
    
    local winnerBid = self.ActiveBids[1]
    if winnerBid and winnerBid.bidType == "Pass" then winnerBid = nil end
    self.QueueResults[self.QueueIndex] = { link = self.CurrentItemData.link, winner = winnerBid and winnerBid.player or "No Winner", amount = winnerBid and winnerBid.amount or 0 }
    
    if winnerBid then
        local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(winnerBid.guid) or winnerBid.guid
        if GU_GlobalDB.Ledger.ActiveSession then GuildUtils.LootCoin:UpdateTempLedger(effGuid, -winnerBid.amount)
        else GuildUtils.LootCoin:ProcessTransaction(effGuid, winnerBid.player, -winnerBid.amount, "Won item: " .. self.CurrentItemData.link) end
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
            c.timerText:SetText(string.format("Next in %ds", remaining))
        else
            if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
            if GuildUtils:IsMasterLootActive() then self:HostNextItem() end
        end
    end)
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

local encounterWatcher = CreateFrame("Frame")
encounterWatcher:RegisterEvent("ENCOUNTER_END")
encounterWatcher:SetScript("OnEvent", function(self, event, encounterID, encounterName, difficultyID, groupSize, success)
    if success == 1 and GuildUtils:IsAuthoritativeHost() then
        GuildUtils:Print("Boss Defeated: " .. tostring(encounterName) .. "! Processing raid attendance...", false)
        local amt = (GU_GlobalDB.Settings and GU_GlobalDB.Settings.AttendanceReward) or 10
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local guid = UnitGUID("raid" .. i)
                if guid then GuildUtils.LootCoin:ProcessTransaction(guid, GuildUtils:FormatName(UnitName("raid" .. i)), amt, "Boss Defeated: " .. tostring(encounterName)) end
            end
        end
    end
end)