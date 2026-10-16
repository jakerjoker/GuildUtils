local addonName, GuildUtils = ...
GuildUtils.PartyRoller = {}
GuildUtils.PartyRoller.Queue = {}
GuildUtils.PartyRoller.State = "IDLE"
GuildUtils.PartyRoller.QueueIndex = 1
GuildUtils.PartyRoller.ActiveBids = {}
GuildUtils.PartyRoller.QueueLocked = false
GuildUtils.PartyRoller.AuthorizedPlayers = {}

local function IsTrueLeader()
    if GuildUtils.SoloMode then return true end
    return UnitIsGroupLeader("player") or UnitIsRaidOfficer("player") or (IsInRaid() and C_PartyInfo.IsPartyLeader("player"))
end

function GuildUtils.PartyRoller:InitializeUI()
    if self.frame then return self.frame end
    
    local f = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsDashboardFrame", UIParent, 600, 480)
    f:Hide()
    f:SetPoint("CENTER", 320, 0)
    GuildUtils.DashboardFrame = f
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("GuildUtils: Gear & Loot Manager")
    
    f.tabGL = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabGL:SetSize(100, 24)
    f.tabGL:SetPoint("BOTTOMLEFT", 15, 10)
    f.tabGL:SetText("Gear & Loot")

    f.tabBounty = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabBounty:SetSize(100, 24)
    f.tabBounty:SetPoint("LEFT", f.tabGL, "RIGHT", 5, 0)
    f.tabBounty:SetText("Bounty Board")

    f.tabEvents = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabEvents:SetSize(100, 24)
    f.tabEvents:SetPoint("LEFT", f.tabBounty, "RIGHT", 5, 0)
    f.tabEvents:SetText("Raid Events")

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

    -- ========================================================================
    -- TAB BEHAVIOR
    -- ========================================================================
    f.tabGL:SetScript("OnClick", function()
        f.BountyContainer:Hide()
        f.EventsContainer:Hide()
        f.GLContainer:Show()
        f:SetWidth(260)
        GuildUtils.PartyRoller:RefreshState()
        f.title:SetText("GuildUtils: Gear & Loot Manager")
        GuildUtils.ActiveTab = "GL"
        f.tabEvents:Hide()
        
        GuildUtils.PartyRoller:SyncUpcomingEvents(f.GLContainer)
    end)

    f.tabBounty:SetScript("OnClick", function()
        if IsInGroup() or IsInRaid() or GuildUtils.SoloMode then
            f.tabGL:Click()
            GuildUtils:Print("The Bounty Board is disabled while in an active group.", true)
            return
        end

        f.GLContainer:Hide()
        f.EventsContainer:Hide()
        f.BountyContainer:Show()
        f:SetSize(600, 440)
        f.title:SetText("GuildUtils: Bounty Board")
        GuildUtils.ActiveTab = "BOUNTY"
        f.tabEvents:Show()          
        
        if GuildUtils.Contracts and GuildUtils.Contracts.InitializeUI then 
            GuildUtils.Contracts:InitializeUI() 
            if GuildUtils.Contracts.Frame then GuildUtils.Contracts.Frame:Show() end
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
        f.tabEvents:Show()          
        
        if GuildUtils.Events and GuildUtils.Events.UpdateEventList then
            GuildUtils.Events:UpdateEventList()
        end
    end)

    -- ========================================================================
    -- GEAR & LOOT CONTAINERS
    -- ========================================================================
    local c = f.GLContainer

    -- IDLE PANEL (Out of group)
    c.IdlePanel = CreateFrame("Frame", nil, c)
    c.IdlePanel:SetAllPoints(c)
    c.IdlePanel:Hide()
    
    c.statusText = c.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.statusText:SetPoint("TOP", 0, -40)
    c.statusText:SetText("No active group event.")
    
    c.nameInput = CreateFrame("EditBox", nil, c.IdlePanel, "InputBoxTemplate")
    c.nameInput:SetSize(160, 20)
    c.nameInput:SetPoint("TOP", c.statusText, "BOTTOM", 0, -10)
    c.nameInput:SetAutoFocus(false)
    c.nameInput:SetText("Raid / Group Name")
    
    c.startBtn = CreateFrame("Button", nil, c.IdlePanel, "UIPanelButtonTemplate")
    c.startBtn:SetSize(140, 26)
    c.startBtn:SetPoint("TOP", c.nameInput, "BOTTOM", 0, -15)
    c.startBtn:SetText("Start Group")
    c.startBtn:SetScript("OnClick", function()
        if GuildUtils.LootCoin and GuildUtils.LootCoin.StartGroupEvent then
            local name = c.nameInput:GetText()
            GuildUtils.LootCoin:StartGroupEvent(name ~= "" and name or nil)
            GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
        end
    end)

    -- HUB PANEL (Active Group Manager)
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
    c.HubPanel.btnEndGroup:SetScript("OnClick", function() 
        if GuildUtils.LootCoin then 
            local sessionRoster = (GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.members) or {}
            local linkedEvId = GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.linkedEventId
            local bPay = GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.basePay or 0
            local eBonus = GU_GlobalDB.Ledger.ActiveSession and GU_GlobalDB.Ledger.ActiveSession.earlyBonus or 0
            
            GuildUtils.LootCoin:EndGroupEvent()
            
            if GuildUtils.SoloMode and next(sessionRoster) then
                GuildUtils.LastRaidResults = sessionRoster
                if linkedEvId and GuildUtils.Verification and GuildUtils.Verification.ShowVerificationScreen then
                    GuildUtils.Verification:ShowVerificationScreen({id = linkedEvId, basePay = bPay, earlyBonus = eBonus}, sessionRoster)
                elseif GuildUtils.PartyRoller and GuildUtils.PartyRoller.ShowRaidResultsModal then
                    GuildUtils.PartyRoller:ShowRaidResultsModal(sessionRoster)
                end
            end
        end
        GuildUtils.PartyRoller:SetUIState("IDLE_PANEL") 
    end)

    -- PHASE A (Drag & Drop)
    c.PhaseA = CreateFrame("Frame", nil, c); c.PhaseA:SetAllPoints(c); c.PhaseA:EnableMouse(true); c.PhaseA:Hide()
    c.PhaseA.scrollFrame = CreateFrame("ScrollFrame", nil, c.PhaseA, "UIPanelScrollFrameTemplate")
    c.PhaseA.scrollFrame:SetPoint("TOPLEFT", 10, -40); c.PhaseA.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    c.PhaseA.scrollChild = CreateFrame("Frame"); c.PhaseA.scrollChild:SetSize(160, 1); c.PhaseA.scrollFrame:SetScrollChild(c.PhaseA.scrollChild)
    
    c.PhaseA.confirmBtn = CreateFrame("Button", nil, c.PhaseA, "UIPanelButtonTemplate")
    c.PhaseA.confirmBtn:SetSize(140, 24); c.PhaseA.confirmBtn:SetPoint("BOTTOM", 0, 10); c.PhaseA.confirmBtn:SetText("Start Roll Queue")
    c.PhaseA.confirmBtn:SetScript("OnClick", function()
        local duration = tonumber(c.PhaseA.timerInput:GetText()) or 10
        local queueData = {}
        for i, item in ipairs(GU_PendingLoot or {}) do 
            table.insert(queueData, {link = item, reserved = GU_ReservedStatus[i]}) 
        end
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
            GU_PendingLoot = GU_PendingLoot or {}
            GU_ReservedStatus = GU_ReservedStatus or {}
            table.insert(GU_PendingLoot, itemLink); 
            table.insert(GU_ReservedStatus, false); 
            ClearCursor(); 
            GuildUtils.PartyRoller:ShowPhaseA()
        end
    end)

    -- PHASE B (Active Bidding)
    c.PhaseB = CreateFrame("Frame", nil, c); c.PhaseB:SetAllPoints(c); c.PhaseB:Hide()
    c.PhaseB.queueText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.PhaseB.queueText:SetPoint("TOPLEFT", 10, -10)
    c.PhaseB.timerText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.PhaseB.timerText:SetPoint("TOPRIGHT", -10, -10)
    
    c.PhaseB.embeddedTooltip = CreateFrame("GameTooltip", "GuildUtilsRollTooltip", c.PhaseB, "GameTooltipTemplate")
    c.PhaseB.embeddedTooltip:SetPoint("TOP", c.PhaseB, "TOP", 0, -25)
    c.PhaseB.embeddedTooltip:SetScale(0.85)
    c.PhaseB.embeddedTooltip:Hide()

    c.PhaseB.infoText = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.PhaseB.infoText:SetPoint("TOP", c.PhaseB.embeddedTooltip, "BOTTOM", 0, -8)
    
    c.PhaseB.reservedWarning = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.PhaseB.reservedWarning:SetPoint("TOP", c.PhaseB.infoText, "BOTTOM", 0, -4)
    c.PhaseB.reservedWarning:SetTextColor(1, 0, 0)
    c.PhaseB.reservedWarning:SetText("RESERVED ITEM")
    
    c.PhaseB.leaderboardRows = {}
    for i = 1, 5 do
        local row = c.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOP", c.PhaseB.infoText, "BOTTOM", 0, -24 - ((i-1) * 14))
        row:SetSize(240, 14); row:SetJustifyH("CENTER")
        c.PhaseB.leaderboardRows[i] = row
    end

    self.frame = f
    return f
end

function GuildUtils.PartyRoller:SyncUpcomingEvents(glContainer)
    if not glContainer then return end
    
    if self.EventSyncFrames then
        for _, f in ipairs(self.EventSyncFrames) do f:Hide() end
    end
    self.EventSyncFrames = {}
    
    local currentTime = time()
    local topOffset = -15
    local foundEvent = false
    
    if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
        for _, event in ipairs(GU_GlobalDB.Events.list) do
            if event.timestamp and math.abs(event.timestamp - currentTime) <= (4 * 3600) then
                foundEvent = true
                local frame = CreateFrame("Frame", nil, glContainer.IdlePanel)
                frame:SetSize(240, 45)
                frame:SetPoint("TOP", 0, topOffset)
                
                local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                header:SetPoint("TOP", 0, 0)
                local displayTime = date("%I:%M %p", event.timestamp)
                header:SetText(string.format("|cFF00FF00Upcoming:|r %s @ %s", event.title, displayTime))
                
                local startBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
                startBtn:SetSize(160, 24)
                startBtn:SetPoint("TOP", header, "BOTTOM", 0, -2)
                startBtn:SetText("Start Raid Event")
                
                startBtn:SetScript("OnClick", function()
                    if GuildUtils.LootCoin and GuildUtils.LootCoin.StartGroupEvent then
                        GuildUtils.LootCoin:StartGroupEvent(event.title)
                        
                        if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then
                            GU_GlobalDB.Ledger.ActiveSession.linkedEventId = event.id
                            GU_GlobalDB.Ledger.ActiveSession.basePay = event.basePay or 0
                            GU_GlobalDB.Ledger.ActiveSession.earlyBonus = event.earlyBonus or 0
                        end
                        GuildUtils:Print("Linked Event Session Started: " .. event.title, false)
                        GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
                    end
                end)
                
                table.insert(self.EventSyncFrames, frame)
                topOffset = topOffset - 50 
            end
        end
    end
    
    if glContainer.statusText then glContainer.statusText:Hide() end
    
    if glContainer.nameInput and glContainer.startBtn then
        glContainer.nameInput:ClearAllPoints()
        
        if foundEvent then
            glContainer.nameInput:SetPoint("TOP", 0, topOffset - 20)
        else
            glContainer.statusText:Show()
            glContainer.nameInput:SetPoint("TOP", glContainer.statusText, "BOTTOM", 0, -10)
        end
        
        glContainer.startBtn:ClearAllPoints()
        glContainer.startBtn:SetPoint("TOP", glContainer.nameInput, "BOTTOM", 0, -15)
    end
end

function GuildUtils.PartyRoller:RefreshState()
    local s = self.State
    if s == "BIDDING" or s == "RESULTS" then 
        self:SetUIState(s)
    elseif s == "PHASE_A" then 
        self:ShowPhaseA()
    elseif GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.ActiveSession then 
        self:SetUIState("HUB_PANEL")
    else 
        self:SetUIState("IDLE_PANEL") 
    end
end

function GuildUtils.PartyRoller:SetUIState(state)
    local f = self:InitializeUI()
    self.State = state
    local c = f.GLContainer
    
    c.IdlePanel:Hide()
    c.HubPanel:Hide()
    c.PhaseA:Hide()
    c.PhaseB:Hide()
    
    if state == "IDLE_PANEL" then 
        c.IdlePanel:Show()
        self:SyncUpcomingEvents(c) 
    elseif state == "HUB_PANEL" then 
        if IsInRaid() or GuildUtils.SoloMode then
            c.HubPanel.btnEndGroup:SetText("End Raid Event")
        else
            c.HubPanel.btnEndGroup:SetText("End Group Event")
        end
        c.HubPanel:Show()
    elseif state == "PHASE_A" then 
        c.PhaseA:Show()
    elseif state == "BIDDING" or state == "RESULTS" then 
        c.PhaseB:Show() 
    end
    
    if GuildUtils.ActiveTab == "GL" then f:Show() end
end

function GuildUtils.PartyRoller:Toggle()
    local f = self:InitializeUI()
    if f:IsShown() and GuildUtils.ActiveTab == "GL" then 
        f:Hide()
    else
        f:Show()
        if IsInGroup() or IsInRaid() or GuildUtils.SoloMode then
            f.tabGL:Click()
        else
            if GuildUtils.Contracts then f.tabBounty:Click() end
        end
    end
end

function GuildUtils.PartyRoller:ShowPhaseA()
    self:SetUIState("PHASE_A")
    local c = self.frame.GLContainer.PhaseA
    
    if not c.Rows then c.Rows = {} end
    for _, row in ipairs(c.Rows) do row:Hide() end
    
    GU_PendingLoot = GU_PendingLoot or {}
    GU_ReservedStatus = GU_ReservedStatus or {}
    
    local yOffset = -5
    for i, link in ipairs(GU_PendingLoot) do
        local row = c.Rows[i]
        if not row then
            row = CreateFrame("Frame", nil, c.scrollChild)
            row:SetSize(230, 24)
            
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(20, 20)
            row.check:SetPoint("LEFT", 0, 0)
            
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row.check, "RIGHT", 5, 0)
            row.text:SetWidth(150)
            row.text:SetJustifyH("LEFT")
            
            row.delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.delBtn:SetSize(24, 24)
            row.delBtn:SetPoint("RIGHT", 0, 0)
            
            c.Rows[i] = row
        end
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row.text:SetText(link)
        row.check:SetChecked(GU_ReservedStatus[i])
        
        row.check:SetScript("OnClick", function(selfBtn)
            GU_ReservedStatus[i] = selfBtn:GetChecked()
        end)
        
        row.delBtn:SetScript("OnClick", function()
            table.remove(GU_PendingLoot, i)
            table.remove(GU_ReservedStatus, i)
            GuildUtils.PartyRoller:ShowPhaseA()
        end)
        
        row:Show()
        yOffset = yOffset - 28
    end
    c.scrollChild:SetHeight(math.abs(yOffset))
end

function GuildUtils.PartyRoller:HostStartQueue(queueData, duration)
    self.Queue = queueData
    self.Duration = duration or 10
    self.QueueIndex = 1
    self:HostNextItem()
end

function GuildUtils.PartyRoller:HostNextItem()
    if self.QueueIndex > #self.Queue then
        GuildUtils:Print("Roll queue finished.", false)
        self:SetUIState("HUB_PANEL")
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        return
    end
    
    local itemData = self.Queue[self.QueueIndex]
    self.ActiveBids = {}
    
    local payload = string.format("START_ROLL:%d:%d:%s:%d:%s", 
        self.QueueIndex, #self.Queue, tostring(itemData.reserved), self.Duration, itemData.link)
        
    GuildUtils:QueueMessage(payload, "GUILD")
end

SLASH_GUILDUTILSLOOT1 = "/guloot"
SlashCmdList["GUILDUTILSLOOT"] = function()
    GuildUtils.PartyRoller:Toggle()
end

-- ============================================================================
-- PARTY LEADER VERIFICATION SCREEN & RAID RESULTS
-- ============================================================================

GuildUtils.Verification = GuildUtils.Verification or {}

function GuildUtils.Verification:CreateUI()
    if self.Frame then return end
    
    local f = CreateFrame("Frame", "GuildUtilsVerificationFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(420, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:Hide()
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("End Event: Roster & Instance Verification")
    
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.desc:SetPoint("TOP", 0, -25)
    f.desc:SetText("Boxes auto-check for 30+ min in raid or valid Instance Journal clears.")
    
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 10, -50)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
    f.scrollChild:SetSize(380, 1)
    f.scrollFrame:SetScrollChild(f.scrollChild)
    
    f.submitBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.submitBtn:SetSize(140, 25)
    f.submitBtn:SetPoint("BOTTOM", 0, 15)
    f.submitBtn:SetText("Sign Off & Payout")
    
    f.submitBtn:SetScript("OnClick", function()
        local approvedList, payoutTotal = GuildUtils.Verification:ProcessSignOff()
        f:Hide()
        
        if payoutTotal and payoutTotal > 0 and approvedList and GuildUtils.LastRaidResults then
            for _, pName in ipairs(approvedList) do
                for _, data in pairs(GuildUtils.LastRaidResults) do
                    if data.name == pName then
                        data.change = (data.change or 0) + payoutTotal
                        break
                    end
                end
            end
        end
        
        if GuildUtils.PartyRoller and GuildUtils.PartyRoller.ShowRaidResultsModal then
            GuildUtils.PartyRoller:ShowRaidResultsModal(GuildUtils.LastRaidResults)
        end
    end)
    
    self.Frame = f
    self.RosterRows = {}
end

function GuildUtils.Verification:ShowVerificationScreen(eventData, activeSessionRoster)
    self:CreateUI()
    self.CurrentEvent = eventData
    
    for _, row in ipairs(self.RosterRows) do row:Hide() end
    
    local yOffset = -5
    local rowIndex = 1
    
    for guid, data in pairs(activeSessionRoster) do
        local row = self.RosterRows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, self.Frame.scrollChild)
            row:SetSize(360, 30)
            
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetPoint("LEFT", 5, 0)
            row.check:SetSize(24, 24)
            
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
            row.nameText:SetWidth(110)
            row.nameText:SetJustifyH("LEFT")
            
            row.metricText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.metricText:SetPoint("LEFT", row.nameText, "RIGHT", 5, 0)
            row.metricText:SetWidth(180)
            row.metricText:SetJustifyH("LEFT")
            
            self.RosterRows[rowIndex] = row
        end
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        local classColor = RAID_CLASS_COLORS[data.class] or RAID_CLASS_COLORS["PRIEST"]
        row.nameText:SetText(data.name or "Unknown")
        row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        
        local timeInSec = data.timeInInstance or (GuildUtils.SoloMode and 1801 or 0)
        local timeMins = math.floor(timeInSec / 60)
        
        local journalValid = false
        if GuildUtils.InstanceJournal and GuildUtils.InstanceJournal.HasValidClear then
            journalValid = GuildUtils.InstanceJournal:HasValidClear(guid)
        end
        
        local shouldAutoCheck = (timeMins >= 30) or journalValid
        row.check:SetChecked(shouldAutoCheck)
        
        local statusStr = string.format("%d min", timeMins)
        if journalValid then statusStr = statusStr .. " [Boss Cleared]" end
        row.metricText:SetText(statusStr)
        row.metricText:SetTextColor(shouldAutoCheck and 0 or 1, shouldAutoCheck and 1 or 0.3, 0)
        
        row.playerName = data.name
        row:Show()
        
        yOffset = yOffset - 35
        rowIndex = rowIndex + 1
    end
    
    self.Frame.scrollChild:SetHeight(math.max(150, math.abs(yOffset)))
    self.Frame:Show()
end

function GuildUtils.Verification:ProcessSignOff()
    if not self.CurrentEvent then return {}, 0 end
    
    local approvedPlayers = {}
    for _, row in ipairs(self.RosterRows) do
        if row:IsShown() and row.check:GetChecked() then
            table.insert(approvedPlayers, row.playerName)
        end
    end
    
    local payout = (self.CurrentEvent.basePay or 0) + (self.CurrentEvent.earlyBonus or 0)
    
    local payload = string.format("GU_LEADER_SIGNOFF:%s:%s", 
        tostring(self.CurrentEvent.id or "UnknownEvent"), 
        table.concat(approvedPlayers, ",")
    )
    
    GuildUtils:QueueMessage(payload, "PARTY")
    if IsInRaid() then GuildUtils:QueueMessage(payload, "RAID") end
    
    GuildUtils:Print("Event finalized. Sign-offs broadcasted to participants.", false)
    
    return approvedPlayers, payout
end

function GuildUtils.PartyRoller:ShowRaidResultsModal(resultsData)
    if not self.RaidResultsModal then
        local m = CreateFrame("Frame", "GuildUtilsRaidResultsFrame", UIParent, "BasicFrameTemplateWithInset")
        m:SetSize(360, 320)
        m:SetPoint("CENTER")
        m:SetFrameStrata("DIALOG")
        m:Hide()
        
        m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        m.title:SetPoint("TOP", 0, -6)
        m.title:SetText("Raid Results & Ledger Summary")
        
        m.scrollArea = CreateFrame("ScrollFrame", nil, m, "UIPanelScrollFrameTemplate")
        m.scrollArea:SetPoint("TOPLEFT", 12, -32)
        m.scrollArea:SetPoint("BOTTOMRIGHT", -30, 45)
        
        m.child = CreateFrame("Frame", nil, m.scrollArea)
        m.child:SetSize(300, 1)
        m.scrollArea:SetScrollChild(m.child)
        
        m.closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        m.closeBtn:SetSize(100, 24)
        m.closeBtn:SetPoint("BOTTOM", 0, 12)
        m.closeBtn:SetText("Close")
        m.closeBtn:SetScript("OnClick", function() m:Hide() end)
        
        self.RaidResultsModal = m
    end
    
    local m = self.RaidResultsModal
    m.Rows = m.Rows or {}
    for _, r in ipairs(m.Rows) do r:Hide() end
    
    local yOffset, rowIndex = 0, 1
    if resultsData then
        for guid, data in pairs(resultsData) do
            local row = m.Rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, m.child)
                row:SetSize(300, 24)
                
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetPoint("LEFT", 5, 0)
                row.text:SetWidth(200)
                row.text:SetJustifyH("LEFT")
                
                row.val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.val:SetPoint("RIGHT", -5, 0)
                
                m.Rows[rowIndex] = row
            end
            
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, yOffset)
            row.text:SetText(tostring(data.name or "Unknown"))
            
            local change = data.change or 0
            if change > 0 then
                row.val:SetText("+" .. change .. " LC")
                row.val:SetTextColor(0, 1, 0)
            elseif change < 0 then
                row.val:SetText(change .. " LC")
                row.val:SetTextColor(1, 0, 0)
            else
                row.val:SetText("0 LC")
                row.val:SetTextColor(0.7, 0.7, 0.7)
            end
            
            row:Show()
            yOffset = yOffset - 28
            rowIndex = rowIndex + 1
        end
    end
    
    m.child:SetHeight(math.max(150, math.abs(yOffset)))
    m:Show()
end