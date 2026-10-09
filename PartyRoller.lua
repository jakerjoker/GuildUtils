local addonName, GuildUtils = ...

GuildUtils.PartyRoller = {}
GuildUtils.PartyRoller.ActiveBids = {}
GuildUtils.PartyRoller.CurrentItemData = nil
GuildUtils.PartyRoller.Queue = {}
GuildUtils.PartyRoller.QueueIndex = 0
GuildUtils.PartyRoller.QueueResults = {}
GuildUtils.PartyRoller.Duration = 5
GuildUtils.PartyRoller.ResultsDuration = 5
GuildUtils.PartyRoller.CountdownTimer = nil
GuildUtils.PartyRoller.HostTimer = nil
GuildUtils.PartyRoller.HasResponded = false
GuildUtils.PartyRoller.State = "IDLE"
GuildUtils.PartyRoller.ResultsAcks = {}
GuildUtils.PartyRoller.ResultsClosedSent = false

local GU_PendingLoot = {}
local GU_ReservedStatus = {}
local GU_LootCouncilTimer = nil

StaticPopupDialogs["GUILDUTILS_WAGER_MODAL"] = {
    text = "Enter LC Wager for %s:\n%s",
    button1 = "Submit Bid", button2 = "Cancel",
    hasEditBox = true, maxLetters = 6,
    OnAccept = function(self, data)
        local amount = tonumber(self.EditBox:GetText())
        if amount and amount >= 1 then
            GuildUtils.PartyRoller:SubmitRoll(data.bidType, amount)
        else GuildUtils:Print("Invalid wager amount.", true) end
    end,
    OnShow = function(self) self.EditBox:SetText("1") self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

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
    OnShow = function(self) self.EditBox:SetText("") self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDUTILS_PULL_TIMER"] = {
    text = "Enter Pull Timer (Seconds):",
    button1 = "Start", button2 = "Cancel",
    hasEditBox = true, maxLetters = 3,
    OnAccept = function(self)
        local secs = tonumber(self.EditBox:GetText())
        if secs and secs > 0 then
            C_PartyInfo.DoCountdown(secs)
        end
    end,
    OnShow = function(self) self.EditBox:SetText("10") self.EditBox:SetFocus() end,
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
            C_Timer.After(mins * 60, function()
                DoReadyCheck()
            end)
        end
    end,
    OnShow = function(self) self.EditBox:SetText("5") self.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

SLASH_GUILDUTILSLOOT1 = "/guloot"
SlashCmdList["GUILDUTILSLOOT"] = function()
    local f = GuildUtils.PartyRoller:InitializeUI()
    if f:IsShown() then
        f:Hide()
    else
        if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.ActiveSession then
            GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
        else
            GuildUtils.PartyRoller:SetUIState("IDLE_PANEL")
        end
    end
end

SLASH_GUILDUTILS_BID1 = "/gubid"
SlashCmdList["GUILDUTILS_BID"] = function(msg)
    if not GuildUtils.SoloMode then
        if not GuildUtilsDB or not GuildUtilsDB.Ledger or not GuildUtilsDB.Ledger.ActiveSession then
            GuildUtils:Print("You must start a group event (/gustartgroup) before rolling items.", true)
            return
        end
        local isLeader = UnitIsGroupLeader("player")
        local lootMethod, mlPartyID = nil, nil
        if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
        if not isLeader and not (lootMethod == "master" and mlPartyID == 0) then 
            GuildUtils:Print("Only the group leader or master looter can initiate rolls.", true) 
            return 
        end
    end

    GU_PendingLoot = {}
    GU_ReservedStatus = {}
    
    if msg == "" then GuildUtils:Print("Usage: /gubid [Item Link] or drop item in frame", true) return end

    for link in string.gmatch(msg, "(|c.-|Hitem:.-|h.-|h|r)") do table.insert(GU_PendingLoot, link) end
    if #GU_PendingLoot == 0 then
        for link in string.gmatch(msg, "(%b[])") do table.insert(GU_PendingLoot, link) end
    end
    if #GU_PendingLoot == 0 and msg:find(",") then
        for part in string.gmatch(msg, "([^,]+)") do
            local cleaned = part:match("^%s*(.-)%s*$")
            if cleaned ~= "" then table.insert(GU_PendingLoot, cleaned) end
        end
    end
    if #GU_PendingLoot == 0 and msg ~= "" then table.insert(GU_PendingLoot, msg) end
    
    if #GU_PendingLoot > 0 then
        for i = 1, #GU_PendingLoot do table.insert(GU_ReservedStatus, false) end
        GuildUtils.PartyRoller:ShowPhaseA()
    end
end

function GuildUtils.PartyRoller:InitializeUI()
    if self.frame then return self.frame end

    -- Ultra-slim width of 200 pixels
    local f = CreateFrame("Frame", "GuildUtilsGroupManagerFrame", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(200, 320)
    f:SetPoint("CENTER", 0, 100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    f.BgTexture = f:CreateTexture(nil, "BACKGROUND")
    f.BgTexture:SetAllPoints(f)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetText("GuildUtils: Loot")
    
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    f:SetScript("OnHide", function()
        GameTooltip:Hide()
        if self.CountdownTimer then self.CountdownTimer:Cancel() self.CountdownTimer = nil end
        if self.State == "RESULTS" then self:TriggerResultsClosed() end
        self.State = "IDLE"
    end)

    f.IdlePanel = CreateFrame("Frame", nil, f)
    f.IdlePanel:SetAllPoints(f)
    
    f.IdlePanel.info = f.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.IdlePanel.info:SetPoint("TOP", 0, -60)
    f.IdlePanel.info:SetText("No active group event.")
    
    f.IdlePanel.nameInput = CreateFrame("EditBox", nil, f.IdlePanel, "InputBoxTemplate")
    f.IdlePanel.nameInput:SetSize(150, 20)
    f.IdlePanel.nameInput:SetPoint("CENTER", 0, 20)
    f.IdlePanel.nameInput:SetAutoFocus(false)
    
    f.IdlePanel.nameLabel = f.IdlePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.IdlePanel.nameLabel:SetPoint("BOTTOM", f.IdlePanel.nameInput, "TOP", 0, 5)
    f.IdlePanel.nameLabel:SetText("Ledger Label:")
    
    f.IdlePanel.startBtn = CreateFrame("Button", nil, f.IdlePanel, "UIPanelButtonTemplate")
    f.IdlePanel.startBtn:SetSize(110, 24)
    f.IdlePanel.startBtn:SetPoint("TOP", f.IdlePanel.nameInput, "BOTTOM", 0, -20)
    f.IdlePanel.startBtn:SetText("Start Group")
    f.IdlePanel.startBtn:SetScript("OnClick", function()
        if not GuildUtils.SoloMode then
            if not IsInGroup() then GuildUtils:Print("You are not in a group.", true) return end
            local lootMethod, mlPartyID = nil, nil
            if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
            if lootMethod ~= "master" then GuildUtils:Print("You are not in a masterloot group.", true) return end
            if not UnitIsGroupLeader("player") and mlPartyID ~= 0 then GuildUtils:Print("You are not the leader/master looter.", true) return end
        end
        
        local groupName = f.IdlePanel.nameInput:GetText()
        if groupName == "" then groupName = "New Group Event" end
        
        GuildUtils.LootCoin:StartGroupEvent()
        GuildUtils:Print("Ledger Label Set: " .. groupName, false)
        GuildUtils.PartyRoller:SetUIState("HUB_PANEL")
    end)

    f.HubPanel = CreateFrame("Frame", nil, f)
    f.HubPanel:SetAllPoints(f)
    
    -- Compact button width of 160 pixels
    local function CreateHubButton(name, text, yOffset, onClick)
        local btn = CreateFrame("Button", name, f.HubPanel, "UIPanelButtonTemplate")
        btn:SetSize(160, 26)
        btn:SetPoint("TOP", 0, yOffset)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    f.HubPanel.btnRollCall = CreateHubButton(nil, "Roll Call", -45, function()
        DoReadyCheck()
    end)
    f.HubPanel.btnAnnounce = CreateHubButton(nil, "Announce", -80, function()
        StaticPopup_Show("GUILDUTILS_ANNOUNCE")
    end)
    f.HubPanel.btnPullTimer = CreateHubButton(nil, "Pull Timer", -115, function()
        StaticPopup_Show("GUILDUTILS_PULL_TIMER")
    end)
    f.HubPanel.btnBreak = CreateHubButton(nil, "Break", -150, function()
        StaticPopup_Show("GUILDUTILS_BREAK_TIMER")
    end)
    f.HubPanel.btnLoot = CreateHubButton(nil, "Loot", -185, function()
        GuildUtils.PartyRoller:ShowPhaseA()
    end)

    f.HubPanel.btnEndGroup = CreateFrame("Button", nil, f.HubPanel, "UIPanelButtonTemplate")
    f.HubPanel.btnEndGroup:SetSize(160, 26)
    f.HubPanel.btnEndGroup:SetPoint("BOTTOM", 0, 15)
    f.HubPanel.btnEndGroup:SetText("End Group")
    f.HubPanel.btnEndGroup:SetScript("OnClick", function()
        if not GuildUtilsDB or not GuildUtilsDB.Ledger or not GuildUtilsDB.Ledger.ActiveSession then
            GuildUtils:Print("No active group event found.", true)
            return
        end
        if not GuildUtils.SoloMode then
            local isLeader = UnitIsGroupLeader("player")
            local lootMethod, mlPartyID = nil, nil
            if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
            local isML = (lootMethod == "master" and mlPartyID == 0)
            if not isLeader and not isML then 
                GuildUtils:Print("You are not the group leader or master looter.", true) 
                return 
            end
        end
        GuildUtils.LootCoin:EndGroupEvent()
        GuildUtils.PartyRoller:SetUIState("IDLE_PANEL")
    end)

    f.PhaseA = CreateFrame("Frame", nil, f)
    f.PhaseA:SetAllPoints(f)
    f.PhaseA:EnableMouse(true)
    
    f.PhaseA.scrollFrame = CreateFrame("ScrollFrame", nil, f.PhaseA, "UIPanelScrollFrameTemplate")
    f.PhaseA.scrollFrame:SetPoint("TOPLEFT", 10, -40)
    f.PhaseA.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    f.PhaseA.scrollChild = CreateFrame("Frame")
    f.PhaseA.scrollChild:SetSize(160, 1)
    f.PhaseA.scrollFrame:SetScrollChild(f.PhaseA.scrollChild)
    
    f.PhaseA.confirmBtn = CreateFrame("Button", nil, f.PhaseA, "GameMenuButtonTemplate")
    f.PhaseA.confirmBtn:SetPoint("BOTTOM", 0, 12)
    f.PhaseA.confirmBtn:SetSize(110, 24)
    f.PhaseA.confirmBtn:SetText("Start Roll")
    f.PhaseA.confirmBtn:SetScript("OnClick", function()
        if #GU_PendingLoot == 0 then
            GuildUtils:Print("Cannot start roll: No items in the queue.", true)
            return
        end
        if GU_LootCouncilTimer then GU_LootCouncilTimer:Cancel() end
        local queueData = {}
        for i, item in ipairs(GU_PendingLoot) do
            table.insert(queueData, {link = item, reserved = GU_ReservedStatus[i]})
        end
        GuildUtils.PartyRoller:HostStartQueue(queueData, 5)
    end)

    f.PhaseA:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            table.insert(GU_PendingLoot, itemLink)
            table.insert(GU_ReservedStatus, false)
            ClearCursor()
            GuildUtils.PartyRoller:ShowPhaseA()
        end
    end)

    f.PhaseB = CreateFrame("Frame", nil, f)
    f.PhaseB:SetAllPoints(f)
    f.PhaseB.queueText = f.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.PhaseB.queueText:SetPoint("TOPLEFT", 10, -28)
    
    f.PhaseB.timerText = f.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.PhaseB.timerText:SetPoint("TOPRIGHT", -10, -28)
    f.PhaseB.timerText:SetTextColor(1, 0.8, 0)
    
    f.PhaseB.itemDisplay = CreateFrame("Button", nil, f.PhaseB)
    f.PhaseB.itemDisplay:SetSize(180, 30)
    f.PhaseB.itemDisplay:SetPoint("TOP", 0, -48)
    f.PhaseB.itemDisplay.text = f.PhaseB.itemDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.PhaseB.itemDisplay.text:SetPoint("CENTER", 0, 0)
    
    f.PhaseB.itemDisplay:SetScript("OnEnter", function(self)
        if GuildUtils.PartyRoller.CurrentItemData and GuildUtils.PartyRoller.CurrentItemData.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(function() GameTooltip:SetHyperlink(GuildUtils.PartyRoller.CurrentItemData.link) end)
            GameTooltip:Show()
        end
    end)
    f.PhaseB.itemDisplay:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.PhaseB.infoText = f.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.PhaseB.infoText:SetPoint("TOP", f.PhaseB.itemDisplay, "BOTTOM", 0, -8)
    
    f.PhaseB.leaderboardRows = {}
    for i = 1, 5 do
        local row = f.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOP", f.PhaseB.infoText, "BOTTOM", 0, -4 - ((i-1) * 14))
        row:SetSize(180, 14)
        row:SetJustifyH("CENTER")
        f.PhaseB.leaderboardRows[i] = row
    end

    f.PhaseB.reservedWarning = f.PhaseB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.PhaseB.reservedWarning:SetPoint("TOP", f.PhaseB.infoText, "BOTTOM", 0, -4)
    f.PhaseB.reservedWarning:SetTextColor(1, 0, 0)
    f.PhaseB.reservedWarning:SetText("RESERVED ITEM")

    -- Slimmer bidding buttons
    f.PhaseB.needBtn = CreateFrame("Button", nil, f.PhaseB, "UIPanelButtonTemplate")
    f.PhaseB.needBtn:SetSize(55, 22)
    f.PhaseB.needBtn:SetPoint("BOTTOMLEFT", 10, 15)
    f.PhaseB.needBtn:SetText("Need")
    f.PhaseB.needBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Need") end)

    f.PhaseB.greedBtn = CreateFrame("Button", nil, f.PhaseB, "UIPanelButtonTemplate")
    f.PhaseB.greedBtn:SetSize(55, 22)
    f.PhaseB.greedBtn:SetPoint("BOTTOM", 0, 15)
    f.PhaseB.greedBtn:SetText("Greed")
    f.PhaseB.greedBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Greed") end)

    f.PhaseB.passBtn = CreateFrame("Button", nil, f.PhaseB, "UIPanelButtonTemplate")
    f.PhaseB.passBtn:SetSize(55, 22)
    f.PhaseB.passBtn:SetPoint("BOTTOMRIGHT", -10, 15)
    f.PhaseB.passBtn:SetText("Pass")
    f.PhaseB.passBtn:SetScript("OnClick", function() GuildUtils.PartyRoller:TriggerWagerModal("Pass") end)

    f.PhaseB.closeBtn = CreateFrame("Button", nil, f.PhaseB, "UIPanelButtonTemplate")
    f.PhaseB.closeBtn:SetSize(110, 24)
    f.PhaseB.closeBtn:SetPoint("BOTTOM", 0, 15)
    f.PhaseB.closeBtn:SetScript("OnClick", function() 
        local isLeader = UnitIsGroupLeader("player") or GuildUtils.SoloMode
        local lootMethod, mlPartyID = nil, nil
        if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
        local wasResults = (GuildUtils.PartyRoller.State == "RESULTS")
        
        GuildUtils.PartyRoller:DismissResults() 
        if (isLeader or (lootMethod == "master" and mlPartyID == 0)) and wasResults then 
            GuildUtils.PartyRoller:HostNextItem() 
        end
    end)

    f.PhaseC = CreateFrame("Frame", nil, f)
    f.PhaseC:SetAllPoints(f)
    f.PhaseC.scrollFrame = CreateFrame("ScrollFrame", nil, f.PhaseC, "UIPanelScrollFrameTemplate")
    f.PhaseC.scrollFrame:SetPoint("TOPLEFT", 10, -40)
    f.PhaseC.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)
    f.PhaseC.scrollChild = CreateFrame("Frame")
    f.PhaseC.scrollChild:SetSize(160, 1)
    f.PhaseC.scrollFrame:SetScrollChild(f.PhaseC.scrollChild)
    
    f.PhaseC.closeBtn = CreateFrame("Button", nil, f.PhaseC, "UIPanelButtonTemplate")
    f.PhaseC.closeBtn:SetSize(110, 24)
    f.PhaseC.closeBtn:SetPoint("BOTTOM", 0, 12)
    f.PhaseC.closeBtn:SetText("Clear Queue")
    f.PhaseC.closeBtn:SetScript("OnClick", function() 
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        f:Hide() 
    end)

    self.frame = f
    
    GuildUtils:ApplyTheme()
    
    return f
end

function GuildUtils.PartyRoller:SetUIState(state)
    local f = self:InitializeUI()
    self.State = state
    f.IdlePanel:Hide() f.HubPanel:Hide() f.PhaseA:Hide() f.PhaseB:Hide() f.PhaseC:Hide()
    
    if state == "IDLE_PANEL" then f.IdlePanel:Show() f:Show()
    elseif state == "HUB_PANEL" then f.HubPanel:Show() f:Show()
    elseif state == "PHASE_A" then f.PhaseA:Show() f:Show()
    elseif state == "BIDDING" or state == "RESULTS" then f.PhaseB:Show() f:Show()
    elseif state == "PHASE_C" then f.PhaseC:Show() f:Show() end
end

function GuildUtils.PartyRoller:ShowPhaseA()
    self:SetUIState("PHASE_A")
    local f = self.frame.PhaseA
    for _, child in ipairs({f.scrollChild:GetChildren()}) do child:Hide() child:SetParent(nil) end
    
    local themeIndex = (GuildUtilsDB and GuildUtilsDB.Theme) or 1
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

    local yOffset = -5
    for i, itemLink in ipairs(GU_PendingLoot) do
        local row = CreateFrame("Frame", nil, f.scrollChild)
        row:SetSize(160, 30)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", 2, 0)
        text:SetWidth(110)
        text:SetJustifyH("LEFT")
        text:SetText(itemLink)
        text:SetTextColor(unpack(style.nameColor))
        
        local resCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        resCheck:SetScale(0.7)
        resCheck:SetPoint("RIGHT", 0, 0)
        resCheck:SetChecked(GU_ReservedStatus[i])
        resCheck:SetScript("OnClick", function(cbSelf) GU_ReservedStatus[i] = cbSelf:GetChecked() end)
        
        yOffset = yOffset - 35
    end
    f.scrollChild:SetHeight(math.max(50, math.abs(yOffset)))
    
    if GU_LootCouncilTimer then GU_LootCouncilTimer:Cancel() end
    GU_LootCouncilTimer = C_Timer.NewTimer(60, function()
        if self.frame and self.frame:IsShown() and self.State == "PHASE_A" then
            self.frame:Hide()
            GuildUtils:SendSync("QUEUE_ABORTED:TIMEOUT:" .. table.concat(GU_PendingLoot, ","))
            GuildUtils:Print("Loot Council timed out. Queue aborted.", true)
            GU_PendingLoot = {}
            GU_ReservedStatus = {}
        end
    end)
end

function GuildUtils.PartyRoller:ShowPhaseC()
    self:SetUIState("PHASE_C")
    local f = self.frame.PhaseC
    for _, child in ipairs({f.scrollChild:GetChildren()}) do child:Hide() child:SetParent(nil) end
    
    local themeIndex = (GuildUtilsDB and GuildUtilsDB.Theme) or 1
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

    local yOffset = -10
    for i, result in ipairs(self.QueueResults) do
        local row = CreateFrame("Frame", nil, f.scrollChild)
        row:SetSize(160, 30)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", 2, 0)
        itemText:SetWidth(90)
        itemText:SetJustifyH("LEFT")
        itemText:SetText(result.link)
        itemText:SetTextColor(unpack(style.nameColor))
        
        local winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        winnerText:SetPoint("RIGHT", -2, 0)
        if result.amount > 0 then winnerText:SetText(string.format("%s(%d)", result.winner, result.amount))
        else winnerText:SetText(result.winner) end
        winnerText:SetTextColor(unpack(style.balColor))
        
        yOffset = yOffset - 35
    end
    f.scrollChild:SetHeight(math.abs(yOffset))

    self.Queue = {}
    self.QueueIndex = 0
    self.QueueResults = {}
    GU_PendingLoot = {}
    GU_ReservedStatus = {}
end

function GuildUtils.PartyRoller:StartBidding(itemData, duration)
    self.CurrentItemData = itemData
    self.ActiveBids = {}
    self.ResultsAcks = {}
    self.HasResponded = false
    self.ResultsClosedSent = false
    
    self:SetUIState("BIDDING")
    local f = self.frame.PhaseB
    f.itemDisplay.text:SetText(itemData.link)
    
    f.passBtn:Show()
    f.greedBtn:Show()
    f.closeBtn:Hide()
    for i = 1, 5 do f.leaderboardRows[i]:Hide() end
    
    if itemData.reserved then
        f.needBtn:Hide()
        f.greedBtn:SetText("Gambit")
        f.reservedWarning:Show()
    else
        f.needBtn:Show()
        f.greedBtn:SetText("Greed")
        f.reservedWarning:Hide()
    end
    
    f.queueText:SetText(#self.Queue > 1 and string.format("Item %d of %d", self.QueueIndex, #self.Queue) or "Priority Roll")
    
    local myGuid = UnitGUID("player")
    local myBalance = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.balances and GuildUtilsDB.Ledger.balances[myGuid]) or 0
    local localSpent = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.LocalSessionSpent) or 0
    f.infoText:SetText("Avail: |cFF00FF00" .. math.max(0, myBalance + localSpent) .. "|r")
    
    pcall(function() 
        if SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK) else PlaySound("ReadyCheck") end
    end)
    GuildUtils:Print("Betting opened for: " .. itemData.link, false)
    
    local startTime = GetTime()
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    self.CountdownTimer = C_Timer.NewTicker(0.5, function()
        local remaining = math.ceil((duration or self.Duration) - (GetTime() - startTime))
        if remaining > 0 then f.timerText:SetText(string.format("%ds", remaining))
        else
            if self.CountdownTimer then self.CountdownTimer:Cancel() self.CountdownTimer = nil end
            if self.frame:IsShown() and self.State == "BIDDING" then
                if not self.HasResponded then
                    local delay = GuildUtils.SoloMode and 0 or (math.random() * 0.5)
                    C_Timer.After(delay, function()
                        if GuildUtils.SoloMode or UnitIsGroupLeader("player") then 
                            GuildUtils.PartyRoller:ProcessBidIntent(UnitName("player"), string.format("Pass:0:%s", myGuid))
                        else 
                            GuildUtils:SendSync(string.format("BID_INTENT:Pass:0:%s", myGuid)) 
                        end
                    end)
                end
                self:ShowResults()
            end
        end
    end)
end

function GuildUtils.PartyRoller:ShowResults()
    self.State = "RESULTS"
    if self.CountdownTimer then self.CountdownTimer:Cancel() self.CountdownTimer = nil end
    
    local f = self.frame.PhaseB
    f.needBtn:Hide()
    f.greedBtn:Hide()
    f.passBtn:Hide()
    f.reservedWarning:Hide()
    for i = 1, 5 do f.leaderboardRows[i]:Show() end
    
    self:SortBids()
    self:UpdateSpectatorBoard()
    
    local winnerBid = self.ActiveBids[1]
    if winnerBid and winnerBid.bidType == "Pass" then winnerBid = nil end
    self.QueueResults[self.QueueIndex] = {
        link = self.CurrentItemData.link,
        winner = winnerBid and winnerBid.player or "No Winner",
        amount = winnerBid and winnerBid.amount or 0
    }
    
    local isGroupLeader = UnitIsGroupLeader("player") or GuildUtils.SoloMode
    local lootMethod, mlPartyID = nil, nil
    if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
    local isML = (lootMethod == "master" and mlPartyID == 0)
    local hasPrivilege = isGroupLeader or isML
    
    local myGuid = UnitGUID("player")
    if winnerBid and winnerBid.guid == myGuid then
        GuildUtilsDB.Ledger.LocalSessionSpent = (GuildUtilsDB.Ledger.LocalSessionSpent or 0) - winnerBid.amount
    end
    if self.CurrentItemData.reserved then
        for _, bid in ipairs(self.ActiveBids) do
            if bid.guid == myGuid and bid.bidType == "Greed" and not (winnerBid and winnerBid.guid == myGuid) then
                GuildUtilsDB.Ledger.LocalSessionSpent = (GuildUtilsDB.Ledger.LocalSessionSpent or 0) - bid.amount
            end
        end
    end
    
    if isGroupLeader and GuildUtilsDB.Ledger.ActiveSession then
        if winnerBid then GuildUtils.LootCoin:UpdateTempLedger(winnerBid.guid, -winnerBid.amount) end
        if self.CurrentItemData.reserved then
            for _, bid in ipairs(self.ActiveBids) do
                if bid.bidType == "Greed" and not (winnerBid and winnerBid.guid == bid.guid) then GuildUtils.LootCoin:UpdateTempLedger(bid.guid, -bid.amount) end
            end
        end
    else
        if winnerBid and winnerBid.guid == myGuid and not GuildUtilsDB.Ledger.ActiveSession then 
            GuildUtils.LootCoin:ProcessTransaction(myGuid, UnitName("player"), -winnerBid.amount, "Won item: " .. self.CurrentItemData.link) 
        end
    end
    
    f.infoText:SetText(winnerBid and string.format("WINNER: |cFF00FF00%s|r", winnerBid.player) or "No Bids Placed")
    
    local isSingleItem = (#self.Queue == 1)
    
    if hasPrivilege then
        if isSingleItem then
            f.closeBtn:SetText("Close")
            f.timerText:SetText("Done")
        else
            f.closeBtn:SetText(self.QueueIndex < #self.Queue and "Next Item" or "Finish")
            f.timerText:SetText("Next")
        end
        f.closeBtn:Show()
    else
        f.closeBtn:SetText("Close")
        f.closeBtn:Show()
        
        if isSingleItem then
            f.timerText:SetText("Done")
        else
            local startTime = GetTime()
            f.timerText:SetText(string.format("%ds", self.ResultsDuration))
            self.CountdownTimer = C_Timer.NewTicker(0.5, function()
                local remaining = math.ceil(self.ResultsDuration - (GetTime() - startTime))
                if remaining > 0 then f.timerText:SetText(string.format("%ds", remaining))
                else
                    if self.CountdownTimer then self.CountdownTimer:Cancel() self.CountdownTimer = nil end
                    if self.frame:IsShown() then self:DismissResults() end
                end
            end)
        end
    end
end

function GuildUtils.PartyRoller:SortBids()
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
end

function GuildUtils.PartyRoller:UpdateSpectatorBoard()
    local f = self.frame.PhaseB
    if not f.leaderboardRows[1]:IsShown() then return end
    self:SortBids()
    
    local themeIndex = (GuildUtilsDB and GuildUtilsDB.Theme) or 1
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

    for i = 1, 5 do
        local bid = self.ActiveBids[i]
        local row = f.leaderboardRows[i]
        
        if bid then
            if bid.bidType == "Pass" then
                row:SetText(string.format("%d. %s - Pass", i, bid.player))
                row:SetTextColor(0.5, 0.5, 0.5) 
            else
                local isTied = false
                local prevBid = self.ActiveBids[i - 1]
                local nextBid = self.ActiveBids[i + 1]
                if prevBid and prevBid.totalScore == bid.totalScore and prevBid.bidType == bid.bidType and prevBid.amount == bid.amount then isTied = true end
                if nextBid and nextBid.totalScore == bid.totalScore and nextBid.bidType == bid.bidType and nextBid.amount == bid.amount then isTied = true end

                local tieText = isTied and string.format("[%d]", bid.tieRoll) or ""
                local color = bid.bidType == "Need" and "|cFF00FF00" or "|cFFFFFF00"
                
                row:SetText(string.format("%d. %s%s|r (%s|S:%d|R:%d+B:%d)%s", i, color, bid.player, bid.bidType:sub(1,1), bid.totalScore, bid.baseRoll, bid.amount, tieText))
                row:SetTextColor(unpack(style.nameColor))
            end
        else
            row:SetText("")
        end
    end
end

function GuildUtils.PartyRoller:SubmitRoll(bidType, amount)
    if self.HasResponded or self.State ~= "BIDDING" then return end
    self.HasResponded = true
    
    local f = self.frame.PhaseB
    f.needBtn:Hide() f.greedBtn:Hide() f.passBtn:Hide() f.reservedWarning:Hide()
    for i = 1, 5 do f.leaderboardRows[i]:Show() end
    
    local myGuid = UnitGUID("player")
    C_Timer.After(GuildUtils.SoloMode and 0 or (math.random() * 0.5), function()
        if GuildUtils.SoloMode or UnitIsGroupLeader("player") then 
            GuildUtils.PartyRoller:ProcessBidIntent(UnitName("player"), string.format("%s:%d:%s", bidType, amount, myGuid))
        else GuildUtils:SendSync(string.format("BID_INTENT:%s:%d:%s", bidType, amount, myGuid)) end
    end)
end

function GuildUtils.PartyRoller:TriggerWagerModal(bidType)
    if bidType == "Pass" then self:SubmitRoll("Pass", 0) return end
    local warningTxt = (bidType == "Greed" and self.CurrentItemData.reserved) and "|cFFFF0000WARNING: Thief's Gambit active. LC is permanently burned.|r" or "Standard Roll"
    StaticPopup_Show("GUILDUTILS_WAGER_MODAL", bidType, warningTxt, {bidType = bidType})
end

function GuildUtils.PartyRoller:ProcessBidIntent(senderName, payload)
    local bidType, amtStr, guid = strsplit(":", payload)
    local amount = tonumber(amtStr) or 0

    if bidType ~= "Pass" then
        local sessionSpent = (GuildUtilsDB.Ledger.ActiveSession and GuildUtilsDB.Ledger.ActiveSession.members[guid]) and GuildUtilsDB.Ledger.ActiveSession.members[guid].change or 0
        local realAvailable = (GuildUtilsDB.Ledger.balances[guid] or 0) + sessionSpent
        if amount > realAvailable then
            GuildUtils:SendSync(string.format("BID_REJECTED:%s:Insufficient funds (Available: %d LC)", guid, realAvailable))
            return
        end
    else amount = 0 end
    
    local baseRoll = 0
    if bidType == "Need" then baseRoll = math.random(1, 100)
    elseif bidType == "Greed" then
        if self.CurrentItemData.reserved then
            baseRoll = math.random(1, math.max(1, amount))
            GuildUtils:Print(senderName .. " took the Thief's Gambit. Wager burned.", true)
        else baseRoll = math.random(1, 90) end
    end
    
    local tieRoll = math.random(1, 100)
    local confirmMsg = string.format("BID_CONFIRMED:%s:%s:%d:%d:%s:%d", senderName, bidType, amount, baseRoll, guid, tieRoll)
    
    GuildUtils:SendSync(confirmMsg)
    if not GuildUtils.SoloMode then GuildUtils:HandleSyncMessage(UnitName("player"), confirmMsg) end
end

function GuildUtils.PartyRoller:OnBidReceived(player, bidType, amount, baseRoll, senderGuid, tieRoll)
    if not self.CurrentItemData then return end
    for _, bid in ipairs(self.ActiveBids) do if bid.guid == senderGuid then return end end
    
    amount, baseRoll, tieRoll = tonumber(amount) or 0, tonumber(baseRoll) or 0, tonumber(tieRoll) or 0
    table.insert(self.ActiveBids, {player = player, guid = senderGuid, bidType = bidType, amount = amount, baseRoll = baseRoll, totalScore = amount + baseRoll, tieRoll = tieRoll})
    
    if (self.HasResponded and self.State == "BIDDING") or self.State == "RESULTS" then self:UpdateSpectatorBoard() end
    if GuildUtils.Host == UnitName("player") then
        if bidType == "Pass" then GuildUtils:Print(string.format("%s passed.", player), false)
        else GuildUtils:Print(string.format("%s rolled %s for %d LC. (Score: %d)", player, bidType, amount, amount + baseRoll), false) end
    end
end

function GuildUtils.PartyRoller:OnBidRejected(reason)
    self.HasResponded = false
    GuildUtils:Print("Roll Rejected: " .. reason, true)
    local f = self.frame.PhaseB
    for i = 1, 5 do f.leaderboardRows[i]:Hide() end
    f.passBtn:Show() f.greedBtn:Show()
    if not self.CurrentItemData.reserved then f.needBtn:Show() else f.reservedWarning:Show() end
end

function GuildUtils.PartyRoller:HostStartQueue(queueData, duration)
    self.Queue = queueData
    self.QueueIndex = 1
    self.Duration = duration or 5
    self.ResultsDuration = duration or 5
    GuildUtils:Print(string.format("Starting roll queue with %d items (%ds timer).", #queueData, self.Duration), false)
    GuildUtils:TriggerDesktopAlert()
    self:BroadcastQueueState()
end

function GuildUtils.PartyRoller:BroadcastQueueState()
    if GuildUtils.SoloMode then self:ClientStartQueue(self.Queue, self.Duration) return end
    local parts = {}
    for _, itemData in ipairs(self.Queue) do table.insert(parts, itemData.link .. "@@" .. tostring(itemData.reserved)) end
    GuildUtils:SendSync("START_QUEUE:" .. string.format("%d:%s", self.Duration, table.concat(parts, ";;")))
    self:StartBidding(self.Queue[self.QueueIndex], self.Duration)
    self:ResetHostTimer()
end

function GuildUtils.PartyRoller:HostNextItem()
    if #self.Queue == 0 then return end
    if self.HostTimer then self.HostTimer:Cancel() end
    
    self.QueueIndex = self.QueueIndex + 1
    if self.QueueIndex > #self.Queue then
        GuildUtils:Print("Roll queue finished.", false)
        if #self.Queue > 1 then 
            self:ShowPhaseC() 
        else 
            -- ADDED CLEANUP LOGIC HERE
            self.Queue = {}
            self.QueueIndex = 0
            self.QueueResults = {}
            GU_PendingLoot = {}
            GU_ReservedStatus = {}
            if self.frame then self.frame:Hide() end 
        end
        if not GuildUtils.SoloMode then GuildUtils:SendSync("QUEUE_FINISHED") end
        return
    end
    
    if GuildUtils.SoloMode then
        self:ClientAdvanceQueue(self.QueueIndex)
        self:ResetHostTimer()
        return
    end
    GuildUtils:SendSync("NEXT_ITEM:" .. self.QueueIndex)
    self:StartBidding(self.Queue[self.QueueIndex], self.Duration)
    self:ResetHostTimer()
end

function GuildUtils.PartyRoller:ClientStartQueue(queueData, duration)
    self.Queue = queueData
    self.QueueIndex = 1
    self.QueueResults = {}
    self.Duration = duration or 5
    self.ResultsDuration = duration or 5
    self:StartBidding(self.Queue[1], self.Duration)
end

function GuildUtils.PartyRoller:ClientAdvanceQueue(index)
    self.QueueIndex = index
    if self.Queue[self.QueueIndex] then self:StartBidding(self.Queue[self.QueueIndex], self.Duration) end
end

function GuildUtils.PartyRoller:ClientFinishQueue()
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    if #self.Queue > 1 then 
        self:ShowPhaseC() 
    else 
        -- ADDED CLEANUP LOGIC HERE
        self.Queue = {}
        self.QueueIndex = 0
        self.QueueResults = {}
        GU_PendingLoot = {}
        GU_ReservedStatus = {}
        if self.frame then self.frame:Hide() end 
    end
end

function GuildUtils.PartyRoller:ResetHostTimer()
    if self.HostTimer then self.HostTimer:Cancel() end
    local isLeader = UnitIsGroupLeader("player") or GuildUtils.SoloMode
    local lootMethod, mlPartyID = nil, nil
    if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
    if isLeader or (lootMethod == "master" and mlPartyID == 0) then return end 

    self.HostTimer = C_Timer.NewTimer(self.Duration + self.ResultsDuration + 20, function()
        GuildUtils:Print("Safety timeout reached. Forcing advance to next item.", true)
        self:HostNextItem()
    end)
end

function GuildUtils.PartyRoller:DismissResults()
    if self.State ~= "RESULTS" then return end
    if self.CountdownTimer then self.CountdownTimer:Cancel() self.CountdownTimer = nil end
    self:TriggerResultsClosed()
    if self.frame then self.frame:Hide() end
end

function GuildUtils.PartyRoller:TriggerResultsClosed()
    if self.ResultsClosedSent then return end
    self.ResultsClosedSent = true
    local myName = UnitName("player")
    if GuildUtils.Host == myName or GuildUtils.SoloMode then self:OnResultsClosed(myName, self.QueueIndex) end
    if not GuildUtils.SoloMode then GuildUtils:SendSync("RESULTS_CLOSED:" .. self.Index) end
end

function GuildUtils.PartyRoller:OnResultsClosed(sender, index)
    if index ~= self.QueueIndex then return end
    local isLeader = UnitIsGroupLeader("player") or GuildUtils.SoloMode
    local lootMethod, mlPartyID = nil, nil
    if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
    if isLeader or (lootMethod == "master" and mlPartyID == 0) then return end 
    
    local hostName = GuildUtils.Host or UnitName("player")
    if hostName == UnitName("player") or GuildUtils.SoloMode then
        if self.ResultsAcks[sender] then return end
        self.ResultsAcks[sender] = true
        local totalExpected = (not GuildUtils.SoloMode and IsInGroup()) and GetNumGroupMembers() or 1
        local count = 0
        for _ in pairs(self.ResultsAcks) do count = count + 1 end
        
        if count >= totalExpected then
            if self.HostTimer then self.HostTimer:Cancel() end
            C_Timer.After(0.1, function() self:HostNextItem() end)
        end
    end
end