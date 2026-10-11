local addonName, GuildUtils = ...
GuildUtils.PartyRoller = {}
GuildUtils.PartyRoller.ActiveBids = {}
GuildUtils.PartyRoller.RollQueue = {}
GuildUtils.PartyRoller.State = "IDLE"

StaticPopupDialogs["GUILDUTILS_WAGER_MODAL"] = {
    text = "Enter LC Wager for %s:",
    button1 = "Submit Bid", button2 = "Cancel",
    hasEditBox = true, maxLetters = 6,
    OnAccept = function(selfPopup, data)
        local amount = tonumber(selfPopup.EditBox:GetText())
        if amount and amount >= 0 then GuildUtils.PartyRoller:SubmitRoll(data, amount)
        else GuildUtils:Print("Invalid wager amount.", true) end
    end,
    OnShow = function(selfPopup) selfPopup.EditBox:SetText("1"); selfPopup.EditBox:SetFocus() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function GuildUtils.PartyRoller:Toggle()
    if not self.Frame then
        self.Frame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsGLFrame", UIParent, 280, 500)
        self.Frame:Hide()
        self.Frame:SetPoint("CENTER", 320, 0)
        
        local f = self.Frame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.title:SetPoint("TOP", 0, -12)
        f.title:SetText("GuildUtils: Gear & Loot Manager")
        
        f.content = CreateFrame("Frame", nil, f)
        f.content:SetPoint("TOPLEFT", 10, -35)
        f.content:SetPoint("BOTTOMRIGHT", -10, 10)
        
        -- HOST CONTROLS
        f.hostSection = CreateFrame("Frame", nil, f.content)
        f.hostSection:SetSize(260, 60)
        f.hostSection:SetPoint("TOP", 0, 0)
        
        f.hostLabel = f.hostSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.hostLabel:SetPoint("TOPLEFT", 5, 0)
        f.hostLabel:SetText("Host Controls: Shift-Click Item to Roll")
        f.hostLabel:SetTextColor(0, 1, 0)
        
        f.itemInput = CreateFrame("EditBox", nil, f.hostSection, "InputBoxTemplate")
        f.itemInput:SetSize(140, 20)
        f.itemInput:SetPoint("TOPLEFT", 10, -20)
        f.itemInput:SetAutoFocus(false)
        f.itemInput:SetScript("OnEscapePressed", function(selfEb) selfEb:ClearFocus() end)
        
        f.startBtn = CreateFrame("Button", nil, f.hostSection, "UIPanelButtonTemplate")
        f.startBtn:SetSize(90, 22)
        f.startBtn:SetPoint("LEFT", f.itemInput, "RIGHT", 10, 0)
        f.startBtn:SetText("Queue Item")
        f.startBtn:SetScript("OnClick", function()
            local link = f.itemInput:GetText()
            if link and link ~= "" then 
                GuildUtils.PartyRoller:EnqueueItem(link)
                f.itemInput:SetText("")
                f.itemInput:ClearFocus()
            end
        end)
        
        local div = f.content:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.3, 0.3, 0.3, 1)
        div:SetSize(260, 1)
        div:SetPoint("TOP", f.hostSection, "BOTTOM", 0, -5)

        -- ACTIVE ROLL UI & DYNAMIC TOOLTIP
        f.timerText = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.timerText:SetPoint("TOPRIGHT", -5, -80)
        f.timerText:SetTextColor(1, 0.8, 0)
        
        -- Interactive Item Link Button
        f.itemButton = CreateFrame("Button", nil, f.content)
        f.itemButton:SetSize(240, 24)
        f.itemButton:SetPoint("TOP", div, "BOTTOM", 0, -5)
        f.itemButton.text = f.itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.itemButton.text:SetPoint("CENTER")
        f.itemButton:SetScript("OnClick", function()
            if GuildUtils.PartyRoller.CurrentItem and ChatEdit_InsertLink then
                ChatEdit_InsertLink(GuildUtils.PartyRoller.CurrentItem)
            end
        end)

        f.embeddedTooltip = CreateFrame("GameTooltip", "GuildUtilsRollTooltip", f.content, "GameTooltipTemplate")
        f.embeddedTooltip:SetPoint("TOP", f.itemButton, "BOTTOM", 0, -5)
        f.embeddedTooltip:SetScale(0.85)
        f.embeddedTooltip:Hide()

        f.infoText = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.infoText:SetPoint("TOP", f.embeddedTooltip, "BOTTOM", 0, -10)
        f.infoText:SetText("Awaiting Group Event...")
        
        -- Spectator Leaderboard
        f.leaderboardRows = {}
        for i = 1, 5 do
            local row = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetPoint("TOP", f.infoText, "BOTTOM", 0, -10 - ((i-1) * 16))
            row:SetSize(240, 14)
            row:SetJustifyH("LEFT")
            f.leaderboardRows[i] = row
        end

        local function CreateBidBtn(text, point, bidType)
            local btn = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
            btn:SetSize(75, 22)
            btn:SetPoint(unpack(point))
            btn:SetText(text)
            btn:SetScript("OnClick", function() 
                if bidType == "Pass" then GuildUtils.PartyRoller:SubmitRoll("Pass", 0)
                else StaticPopup_Show("GUILDUTILS_WAGER_MODAL", bidType, nil, bidType) end
            end)
            return btn
        end

        f.btnNeed = CreateBidBtn("Need", {"BOTTOMLEFT", 10, 10}, "Need")
        f.btnGreed = CreateBidBtn("Greed", {"BOTTOM", 0, 10}, "Greed")
        f.btnPass = CreateBidBtn("Pass", {"BOTTOMRIGHT", -10, 10}, "Pass")
    end

    if self.Frame:IsShown() then self.Frame:Hide() else self.Frame:Show() end
end

function GuildUtils.PartyRoller:EnqueueItem(itemLink)
    if not GuildUtils:IsAuthoritativeHost() then return GuildUtils:Print("Only Host can queue items.", true) end
    table.insert(self.RollQueue, itemLink)
    GuildUtils:Print("Item queued for roll: " .. itemLink .. " (Queue size: " .. #self.RollQueue .. ")", false)
    if self.State == "IDLE" or self.State == "RESULTS" then
        self:AdvanceQueue()
    end
end

function GuildUtils.PartyRoller:AdvanceQueue()
    if #self.RollQueue > 0 then
        local nextItem = table.remove(self.RollQueue, 1)
        self:HostStartRoll(nextItem)
    end
end

function GuildUtils.PartyRoller:HostStartRoll(itemLink)
    if not GuildUtils:IsAuthoritativeHost() then return end
    GuildUtils:QueueMessage("START_ROLL:" .. itemLink, "GUILD")
    self:ClientStartRoll(itemLink)
end

function GuildUtils.PartyRoller:ClientStartRoll(itemLink)
    if not self.Frame then self:Toggle() end
    if not self.Frame:IsShown() then self.Frame:Show() end
    
    self.State = "BIDDING"
    self.CurrentItem = itemLink
    self.ActiveBids = {}
    self.HasResponded = false
    
    local f = self.Frame.content
    f.itemButton.text:SetText(itemLink)
    f.embeddedTooltip:SetOwner(f, "ANCHOR_PRESERVE")
    f.embeddedTooltip:ClearAllPoints()
    f.embeddedTooltip:SetPoint("TOP", f.itemButton, "BOTTOM", 0, -5)
    f.embeddedTooltip:SetHyperlink(itemLink)
    f.embeddedTooltip:Show()
    
    local baseHeight = 300
    local ttHeight = f.embeddedTooltip:GetHeight() or 0
    self.Frame:SetHeight(baseHeight + ttHeight)
    
    f.infoText:SetPoint("TOP", f.embeddedTooltip, "BOTTOM", 0, -10)
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(UnitGUID("player")) or UnitGUID("player")
    f.infoText:SetText("Avail LC: |cFF00FF00" .. (GU_GlobalDB.Ledger.balances[effGuid] or 0) .. "|r")
    for i = 1, 5 do f.leaderboardRows[i]:SetText("") end
    f.btnNeed:Enable(); f.btnGreed:Enable(); f.btnPass:Enable()

    local duration, startTime = 10, GetTime()
    if self.CountdownTimer then self.CountdownTimer:Cancel() end
    self.CountdownTimer = C_Timer.NewTicker(0.5, function()
        local remaining = math.ceil(duration - (GetTime() - startTime))
        if remaining > 0 then f.timerText:SetText(string.format("%ds", remaining))
        else
            if self.CountdownTimer then self.CountdownTimer:Cancel(); self.CountdownTimer = nil end
            self:ShowResults()
        end
    end)
end

function GuildUtils.PartyRoller:SubmitRoll(bidType, amount)
    if self.HasResponded or self.State ~= "BIDDING" then return end
    self.HasResponded = true
    self.Frame.content.btnNeed:Disable(); self.Frame.content.btnGreed:Disable(); self.Frame.content.btnPass:Disable()
    self.Frame.content.infoText:SetText("|cFFFFFF00Bid Submitted. Waiting...|r")
    
    local payload = string.format("%s:%d:%s", bidType, amount, UnitGUID("player"))
    C_Timer.After(GuildUtils.SoloMode and 0 or (math.random() * 0.5), function()
        if GuildUtils:IsAuthoritativeHost() then self:HostProcessBid(GuildUtils:FormatName(UnitName("player")), payload)
        else GuildUtils:QueueMessage("BID_INTENT:" .. payload, "GUILD") end
    end)
end

function GuildUtils.PartyRoller:HostProcessBid(senderName, payload)
    local bidType, amtStr, guid = strsplit(":", payload)
    local amount = tonumber(amtStr) or 0
    local effGuid = GuildUtils.LootCoin and GuildUtils.LootCoin:GetEffectiveGuid(guid) or guid
    if bidType ~= "Pass" then
        if amount > (GU_GlobalDB.Ledger.balances[effGuid] or 0) then return end
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
    if not self.Frame or not self.Frame:IsShown() then return end
    local typeRank = { Need = 2, Greed = 1, Pass = 0 }
    table.sort(self.ActiveBids, function(a, b)
        if a.bidType == "Pass" and b.bidType ~= "Pass" then return false end
        if b.bidType == "Pass" and a.bidType ~= "Pass" then return true end
        if a.totalScore ~= b.totalScore then return a.totalScore > b.totalScore end
        if typeRank[a.bidType] ~= typeRank[b.bidType] then return typeRank[a.bidType] > typeRank[b.bidType] end
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.guid > b.guid
    end)
    
    for i = 1, 5 do
        local bid, row = self.ActiveBids[i], self.Frame.content.leaderboardRows[i]
        if bid then
            if bid.bidType == "Pass" then row:SetText(string.format("%d. %s - Pass", i, bid.player)); row:SetTextColor(0.5, 0.5, 0.5) 
            else row:SetText(string.format("%d. %s%s|r (%s|S:%d)", i, bid.bidType == "Need" and "|cFF00FF00" or "|cFFFFFF00", bid.player, bid.bidType:sub(1,1), bid.totalScore)); row:SetTextColor(1, 0.82, 0) end
        else row:SetText("") end
    end
end

function GuildUtils.PartyRoller:AutomateMasterLootHandout(winnerName)
    if not IsInGroup() or not winnerName then return end
    local lootMethod, masterLooterPartyID = GetLootMethod()
    if lootMethod ~= "master" then return end
    
    for slot = 1, (GetNumLootItems() or 0) do
        local slotLink = GetLootSlotLink(slot)
        if slotLink == self.CurrentItem then
            for ci = 1, 40 do
                local candidate = GetMasterLootCandidate(slot, ci)
                if candidate and GuildUtils:FormatName(candidate) == GuildUtils:FormatName(winnerName) then
                    GiveMasterLoot(slot, ci)
                    GuildUtils:Print(string.format("Automatically assigned %s to %s via Master Loot.", slotLink, winnerName), false)
                    return
                end
            end
        end
    end
end

function GuildUtils.PartyRoller:ShowResults()
    self.State = "RESULTS"
    self.Frame.content.timerText:SetText("Done")
    self:UpdateSpectatorBoard()
    local winnerBid = self.ActiveBids[1]
    if winnerBid and winnerBid.bidType == "Pass" then winnerBid = nil end
    if winnerBid then
        self.Frame.content.infoText:SetText(string.format("WINNER: |cFF00FF00%s|r", winnerBid.player))
        if GuildUtils:IsAuthoritativeHost() and GuildUtils.LootCoin then 
            GuildUtils.LootCoin:ProcessTransaction(winnerBid.guid, winnerBid.player, -winnerBid.amount, "Won item: " .. tostring(self.CurrentItem))
            self:AutomateMasterLootHandout(winnerBid.player)
        end
    else 
        self.Frame.content.infoText:SetText("No Bids Placed.") 
    end

    if #self.RollQueue > 0 then
        C_Timer.After(3, function() self:AdvanceQueue() end)
    end
end

-- Boss Kill Attendance Tracker
local encounterWatcher = CreateFrame("Frame")
encounterWatcher:RegisterEvent("ENCOUNTER_END")
encounterWatcher:SetScript("OnEvent", function(self, event, encounterID, encounterName, difficultyID, groupSize, success)
    if success == 1 and GuildUtils:IsAuthoritativeHost() then
        GuildUtils:Print("Boss Defeated: " .. tostring(encounterName) .. "! Processing raid attendance...", false)
        if GuildUtils.LootCoin then
            GuildUtils.LootCoin:AwardRaidAttendance(GU_GlobalDB.Settings.AttendanceReward or 10, "Boss Defeated: " .. tostring(encounterName))
        end
    end
end)