local addonName, GuildUtils = ...
GuildUtils.Events = {}
GuildUtils.Events.initialized = false
GuildUtils.Events.SelectedEventId = nil

function GuildUtils.Events:CanManageEvents()
    local isGM = IsGuildLeader and IsGuildLeader() or (select(3, GetGuildInfo("player")) == 0)
    local rankIndex = select(3, GetGuildInfo("player")) or 99
    return isGM or (rankIndex <= 2)
end

function GuildUtils.Events:InitializeUI()
    if self.initialized then return end
    
    local mainFrame = GuildUtils.PartyRoller:InitializeUI()
    local f = mainFrame.EventsContainer
    self.Container = f

    f.colLeftText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colLeftText:SetPoint("TOPLEFT", 20, -10)
    f.colLeftText:SetText("Upcoming Events")

    f.colRightText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colRightText:SetPoint("TOPLEFT", 250, -10)
    f.colRightText:SetText("Event Details & Signups")

    local midDiv = f:CreateTexture(nil, "ARTWORK")
    midDiv:SetColorTexture(0.3, 0.3, 0.3, 1)
    midDiv:SetSize(1, 330)
    midDiv:SetPoint("TOP", 0, -10)
    midDiv:SetPoint("LEFT", f, "LEFT", 230, 0) 
    
    f.scrollLeft = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollLeft:SetPoint("TOPLEFT", 10, -40)
    f.scrollLeft:SetPoint("BOTTOMLEFT", 10, 50)
    f.scrollLeft:SetWidth(190) 
    
    f.childLeft = CreateFrame("Frame", nil, f.scrollLeft)
    f.childLeft:SetSize(190, 1)
    f.scrollLeft:SetScrollChild(f.childLeft)

    f.createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.createBtn:SetSize(110, 24)
    f.createBtn:SetPoint("BOTTOMLEFT", 10, 10)
    f.createBtn:SetText("Create Event")
    f.createBtn:SetScript("OnClick", function()
        if not GuildUtils.Events:CanManageEvents() then
            GuildUtils:Print("Access Denied: Only the Guild Master and Raid Leaders can create events.", true)
            return
        end
        local modal = GuildUtils.Events:GetCreateModal()
        modal.titleBox:SetText("")
        modal.titleBox:SetFocus()
        modal:Show()
    end)

    f.eventTitle = f:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    f.eventTitle:SetPoint("TOPLEFT", 245, -35)
    f.eventTitle:SetWidth(290)
    f.eventTitle:SetJustifyH("LEFT")
    f.eventTitle:SetTextColor(0, 0, 0)
    f.eventTitle:SetText("No Event Selected")
    
    f.eventInfo = f:CreateFontString(nil, "OVERLAY", "QuestFont")
    f.eventInfo:SetPoint("TOPLEFT", f.eventTitle, "BOTTOMLEFT", 0, -10)
    f.eventInfo:SetWidth(280)
    f.eventInfo:SetJustifyH("LEFT")
    f.eventInfo:SetTextColor(0.15, 0.15, 0.15)
    f.eventInfo:SetText("Select an event from the list to view details.")

    f.scrollRight = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollRight:SetPoint("TOPLEFT", 245, -160)
    f.scrollRight:SetPoint("BOTTOMRIGHT", -30, 50)
    
    f.childRight = CreateFrame("Frame", nil, f.scrollRight)
    f.childRight:SetSize(300, 1)
    f.scrollRight:SetScrollChild(f.childRight)

    f.deleteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.deleteBtn:SetSize(110, 24)
    f.deleteBtn:SetPoint("BOTTOMRIGHT", -30, 10)
    f.deleteBtn:SetText("Delete Event")
    f.deleteBtn:SetScript("OnClick", function()
        local eventId = GuildUtils.Events.SelectedEventId
        if not eventId then return end
        
        if not GuildUtils.Events:CanManageEvents() then
            GuildUtils:Print("Access Denied: Only the Guild Master and Raid Leaders can delete events.", true)
            return
        end
        
        for i, event in ipairs(GU_GlobalDB.Events.list) do
            if event.id == eventId then
                table.remove(GU_GlobalDB.Events.list, i)
                GuildUtils:Print("Event deleted: " .. event.title, false)
                GuildUtils:QueueMessage("EVENT_DELETE:" .. eventId, "GUILD")
                
                GuildUtils.Events.SelectedEventId = nil
                GuildUtils.Events:UpdateEventList()
                f.eventTitle:SetText("No Event Selected")
                f.eventInfo:SetText("Select an event from the list to view details.")
                
                if GuildUtils.Events.RosterRows then
                    for _, r in ipairs(GuildUtils.Events.RosterRows) do r:Hide() end
                end
                break
            end
        end
    end)

    f.signupBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.signupBtn:SetSize(100, 24)
    f.signupBtn:SetPoint("RIGHT", f.deleteBtn, "LEFT", -5, 0)
    f.signupBtn:SetText("Sign Up")
    f.signupBtn:SetScript("OnClick", function()
        if not GuildUtils.Events.SelectedEventId then return end
        local modal = GuildUtils.Events:GetRoleModal()
        modal:Show()
    end)

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(100, 24)
    f.cancelBtn:SetPoint("RIGHT", f.signupBtn, "LEFT", -5, 0)
    f.cancelBtn:SetText("Withdraw")
    f.cancelBtn:SetScript("OnClick", function()
        if not GuildUtils.Events.SelectedEventId then return end
        GuildUtils.Events:HostProcessWithdraw(GuildUtils.Events.SelectedEventId, UnitName("player"))
    end)

    self.initialized = true
end

function GuildUtils.Events:GetCreateModal()
    if self.CreateModal then return self.CreateModal end
    
    local m = CreateFrame("Frame", "GuildUtilsEventCreateModal", UIParent, "BasicFrameTemplateWithInset")
    m:SetSize(320, 460)
    m:SetPoint("CENTER")
    m:SetFrameStrata("DIALOG")
    m:Hide()
    
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    m.title:SetPoint("TOP", 0, -6)
    m.title:SetText("Create Raid Event")
    
    local titleLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", 25, -35)
    titleLabel:SetText("Event Title:")
    
    m.titleBox = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
    m.titleBox:SetSize(270, 20)
    m.titleBox:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 5, -5)
    m.titleBox:SetAutoFocus(false)
    m.titleBox:SetText("Molten Core")

    local dateLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateLabel:SetPoint("TOPLEFT", 25, -90)
    dateLabel:SetText("Date (Month / Day):")

    local monthDropdown = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    monthDropdown:SetSize(130, 24)
    monthDropdown:SetPoint("TOPLEFT", 25, -115)
    
    local months = {"01 - Jan", "02 - Feb", "03 - Mar", "04 - Apr", "05 - May", "06 - Jun", "07 - Jul", "08 - Aug", "09 - Sep", "10 - Oct", "11 - Nov", "12 - Dec"}
    local selectedMonthNum = tonumber(date("%m")) or 1
    monthDropdown:SetText(months[selectedMonthNum])

    monthDropdown:SetScript("OnClick", function(selfBtn)
        MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Month")
            for idx, mName in ipairs(months) do
                rootDescription:CreateRadio(mName, 
                    function(i) return selectedMonthNum == i end, 
                    function(i) 
                        selectedMonthNum = i 
                        monthDropdown:SetText(months[i])
                    end, idx)
            end
        end)
    end)

    m.dayBox = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
    m.dayBox:SetSize(125, 20)
    m.dayBox:SetPoint("LEFT", monthDropdown, "RIGHT", 15, 0)
    m.dayBox:SetAutoFocus(false)
    m.dayBox:SetNumeric(true)
    m.dayBox:SetText(date("%d"))

    local timeLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", 25, -155)
    timeLabel:SetText("Time (Local Time - 12hr):")

    local hourDropdown = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    hourDropdown:SetSize(85, 24)
    hourDropdown:SetPoint("TOPLEFT", 25, -180)
    local selectedHour = 7
    hourDropdown:SetText("07")

    hourDropdown:SetScript("OnClick", function(selfBtn)
        MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Hour")
            for h = 1, 12 do
                local hStr = string.format("%02d", h)
                rootDescription:CreateRadio(hStr, 
                    function(val) return selectedHour == h end, 
                    function(val) 
                        selectedHour = h 
                        hourDropdown:SetText(hStr)
                    end, h)
            end
        end)
    end)

    local minuteDropdown = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    minuteDropdown:SetSize(90, 24)
    minuteDropdown:SetPoint("LEFT", hourDropdown, "RIGHT", 5, 0)
    local selectedMin = "00"
    minuteDropdown:SetText(":00 min")

    minuteDropdown:SetScript("OnClick", function(selfBtn)
        MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Minute")
            for mVal = 0, 55, 5 do
                local minStr = string.format("%02d", mVal)
                rootDescription:CreateRadio(":" .. minStr, 
                    function(val) return selectedMin == minStr end, 
                    function(val) 
                        selectedMin = minStr 
                        minuteDropdown:SetText(":" .. minStr)
                    end, minStr)
            end
        end)
    end)

    local ampmDropdown = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    ampmDropdown:SetSize(85, 24)
    ampmDropdown:SetPoint("LEFT", minuteDropdown, "RIGHT", 5, 0)
    local selectedAmPm = "PM"
    ampmDropdown:SetText("PM")

    ampmDropdown:SetScript("OnClick", function(selfBtn)
        MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Period")
            for _, period in ipairs({"AM", "PM"}) do
                rootDescription:CreateRadio(period, 
                    function(val) return selectedAmPm == val end, 
                    function(val) 
                        selectedAmPm = val 
                        ampmDropdown:SetText(val)
                    end, period)
            end
        end)
    end)

    local serverNote = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    serverNote:SetPoint("TOPLEFT", 25, -215)
    serverNote:SetTextColor(0, 1, 0)
    serverNote:SetText("*Note: Time is auto-converted for all players.")

    local sizeLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 25, -245)
    sizeLabel:SetText("Max Players:")

    m.sizeBox = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
    m.sizeBox:SetSize(270, 20)
    m.sizeBox:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 5, -5)
    m.sizeBox:SetAutoFocus(false)
    m.sizeBox:SetNumeric(true)
    m.sizeBox:SetText("40")
    
    m.basePayLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.basePayLabel:SetPoint("TOPLEFT", m.sizeBox, "BOTTOMLEFT", -5, -15)
    m.basePayLabel:SetText("Base Pay (LC):")

    m.basePayInput = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
    m.basePayInput:SetSize(100, 20)
    m.basePayInput:SetPoint("TOPLEFT", m.basePayLabel, "BOTTOMLEFT", 5, -5)
    m.basePayInput:SetNumeric(true)
    m.basePayInput:SetAutoFocus(false)
    m.basePayInput:SetText("25")

    m.earlyBonusLabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.earlyBonusLabel:SetPoint("LEFT", m.basePayLabel, "RIGHT", 50, 0)
    m.earlyBonusLabel:SetText("Early Start Bonus (LC):")

    m.earlyBonusInput = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
    m.earlyBonusInput:SetSize(100, 20)
    m.earlyBonusInput:SetPoint("TOPLEFT", m.earlyBonusLabel, "BOTTOMLEFT", 5, -5)
    m.earlyBonusInput:SetNumeric(true)
    m.earlyBonusInput:SetAutoFocus(false)
    m.earlyBonusInput:SetText("10")
    
    m.confirmBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    m.confirmBtn:SetSize(110, 24)
    m.confirmBtn:SetPoint("BOTTOMLEFT", 35, 15)
    m.confirmBtn:SetText("Create")
    
    m.cancelBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    m.cancelBtn:SetSize(110, 24)
    m.cancelBtn:SetPoint("BOTTOMRIGHT", -35, 15)
    m.cancelBtn:SetText("Cancel")
    m.cancelBtn:SetScript("OnClick", function() m:Hide() end)
    
    m.confirmBtn:SetScript("OnClick", function()
        local title = m.titleBox:GetText()
        local dayStr = m.dayBox:GetText()
        if dayStr == "" or tonumber(dayStr) > 31 then dayStr = "01" end
        
        local hour24 = selectedHour
        if selectedAmPm == "PM" and selectedHour < 12 then
            hour24 = selectedHour + 12
        elseif selectedAmPm == "AM" and selectedHour == 12 then
            hour24 = 0
        end
        
        local currentLocalData = date("*t")
        local eventYear = currentLocalData.year
        if selectedMonthNum < currentLocalData.month then
            eventYear = eventYear + 1
        end
        
        local eventTimestamp = time({
            year = eventYear, 
            month = selectedMonthNum, 
            day = tonumber(dayStr), 
            hour = hour24, 
            min = tonumber(selectedMin) or 0, 
            sec = 0
        })
        
        local maxSize = tonumber(m.sizeBox:GetText()) or 40
        local basePay = tonumber(m.basePayInput:GetText()) or 0
        local earlyBonus = tonumber(m.earlyBonusInput:GetText()) or 0
        
        if title == "" then
            GuildUtils:Print("Event Title is required.", true)
            return
        end
        
        GuildUtils.Events:HostCreateEvent(title, eventTimestamp, maxSize, basePay, earlyBonus)
        m:Hide()
    end)
    
    self.CreateModal = m
    return m
end

function GuildUtils.Events:HostCreateEvent(title, eventTimestamp, maxSize, basePay, earlyBonus)
    local id = GU_GlobalDB.Events.nextId
    GU_GlobalDB.Events.nextId = id + 1
    local newEvent = { 
        id = id, 
        title = title, 
        timestamp = eventTimestamp, 
        maxSize = maxSize, 
        basePay = basePay, 
        earlyBonus = earlyBonus, 
        roster = {}, 
        creator = UnitName("player") 
    }
    table.insert(GU_GlobalDB.Events.list, newEvent)
    GuildUtils:Print("Event Created: " .. title, false)
    GuildUtils:QueueMessage(string.format("EVENT_ADD:%d:%s:%d:%d:%d:%d", id, title, eventTimestamp, maxSize, basePay, earlyBonus), "GUILD")
    if self.UpdateEventList then self:UpdateEventList() end
end

function GuildUtils.Events:UpdateEventList()
    if not self.initialized or not self.Container:IsShown() then return end
    local child = self.Container.childLeft
    self.EventRows = self.EventRows or {}
    for _, r in ipairs(self.EventRows) do r:Hide() end
    
    local yOffset, rowIndex = -5, 1
    for _, event in ipairs(GU_GlobalDB.Events.list or {}) do
        local row = self.EventRows[rowIndex]
        if not row then
            row = CreateFrame("Button", nil, child)
            row:SetSize(170, 40)
            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.title:SetPoint("TOPLEFT", 5, -5); row.title:SetWidth(160); row.title:SetJustifyH("LEFT")
            row.date = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.date:SetPoint("BOTTOMLEFT", 5, 5)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            self.EventRows[rowIndex] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 5, yOffset)
        row.title:SetText(event.title)
        
        local displayDate = event.timestamp and date("%b %d", event.timestamp) or (event.date or "Unknown")
        local displayTime = event.timestamp and date("%I:%M %p", event.timestamp) or (event.time or "")
        row.date:SetText(string.format("%s @ %s", displayDate, displayTime))
        
        row:SetScript("OnClick", function()
            GuildUtils.Events.SelectedEventId = event.id
            GuildUtils.Events:UpdateEventList()
            GuildUtils.Events:UpdateEventDetails(event)
        end)
        row.bg:SetColorTexture(GuildUtils.Events.SelectedEventId == event.id and 0.2 or 0.1, GuildUtils.Events.SelectedEventId == event.id and 0.4 or 0.1, GuildUtils.Events.SelectedEventId == event.id and 0.8 or 0.1, 0.6)
        row:Show()
        rowIndex = rowIndex + 1; yOffset = yOffset - 45
    end
    child:SetHeight(math.max(300, math.abs(yOffset)))
end

function GuildUtils.Events:UpdateEventDetails(event)
    if not self.initialized or not event then return end
    local f = self.Container
    
    f.eventTitle:SetText(event.title)
    
    local displayDate = event.timestamp and date("%b %d", event.timestamp) or (event.date or "Unknown")
    local displayTime = event.timestamp and date("%I:%M %p", event.timestamp) or (event.time or "Unknown")
    
    local infoText = string.format(
        "|cFF000000Date:|r %s\n" ..
        "|cFF000000Time:|r %s (Local)\n" ..
        "|cFF000000Max Players:|r %d\n\n" ..
        "|cFF000000Base Pay:|r %d LC\n" ..
        "|cFF000000Early Bonus:|r %d LC", 
        displayDate, displayTime, event.maxSize, event.basePay or 0, event.earlyBonus or 0
    )
    
    f.eventInfo:SetText(infoText)
    f.eventInfo:SetSpacing(4)
        
    f.signupBtn:Enable()
    f.cancelBtn:Enable()

    self.RosterRows = self.RosterRows or {}
    for _, r in ipairs(self.RosterRows) do r:Hide() end

    local child = f.childRight
    local yOffset = -5
    local rowIndex = 1

    local rosterHeader = self.RosterRows[rowIndex]
    if not rosterHeader then
        rosterHeader = child:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
        self.RosterRows[rowIndex] = rosterHeader
    end
    rosterHeader:ClearAllPoints()
    rosterHeader:SetPoint("TOPLEFT", 0, yOffset)
    rosterHeader:SetTextColor(0, 0, 0)
    
    local currentCount = 0
    for _ in pairs(event.roster or {}) do currentCount = currentCount + 1 end
    rosterHeader:SetText(string.format("Current Roster (%d/%d):", currentCount, event.maxSize))
    rosterHeader:Show()
    
    yOffset = yOffset - 25
    rowIndex = rowIndex + 1

    local roles = {"Tank", "Healer", "DPS"}
    for _, role in ipairs(roles) do
        local roleHeader = self.RosterRows[rowIndex]
        if not roleHeader then
            roleHeader = child:CreateFontString(nil, "OVERLAY", "QuestFont")
            self.RosterRows[rowIndex] = roleHeader
        end
        roleHeader:ClearAllPoints()
        roleHeader:SetPoint("TOPLEFT", 5, yOffset)
        roleHeader:SetTextColor(0, 0, 0)
        roleHeader:SetText(role .. "s:")
        roleHeader:Show()

        yOffset = yOffset - 15
        rowIndex = rowIndex + 1

        local hasPlayers = false
        for pName, pData in pairs(event.roster or {}) do
            if pData.role == role then
                hasPlayers = true
                local pRow = self.RosterRows[rowIndex]
                if not pRow then
                    pRow = child:CreateFontString(nil, "OVERLAY", "QuestFont")
                    self.RosterRows[rowIndex] = pRow
                end
                pRow:ClearAllPoints()
                pRow:SetPoint("TOPLEFT", 20, yOffset)
                
                local cColor = RAID_CLASS_COLORS[pData.class] or RAID_CLASS_COLORS["PRIEST"]
                pRow:SetText(string.format("- %s", pName))
                pRow:SetTextColor(cColor.r, cColor.g, cColor.b)
                pRow:Show()
                
                yOffset = yOffset - 15
                rowIndex = rowIndex + 1
            end
        end
        
        if not hasPlayers then
            local eRow = self.RosterRows[rowIndex]
            if not eRow then
                eRow = child:CreateFontString(nil, "OVERLAY", "QuestFont")
                self.RosterRows[rowIndex] = eRow
            end
            eRow:ClearAllPoints()
            eRow:SetPoint("TOPLEFT", 20, yOffset)
            eRow:SetText("- Empty")
            eRow:SetTextColor(0.5, 0.5, 0.5)
            eRow:Show()
            yOffset = yOffset - 15
            rowIndex = rowIndex + 1
        end
        
        yOffset = yOffset - 10
    end

    child:SetHeight(math.abs(yOffset))
end

function GuildUtils.Events:GetRoleModal()
    if self.RoleModal then return self.RoleModal end
    local m = CreateFrame("Frame", "GuildUtilsEventRoleModal", UIParent, "BasicFrameTemplateWithInset")
    m:SetSize(260, 100); m:SetPoint("CENTER"); m:SetFrameStrata("DIALOG"); m:Hide()
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); m.title:SetPoint("TOP", 0, -5); m.title:SetText("Select Your Role")
    
    local function HandleRoleClick(role)
        if not GuildUtils.Events.SelectedEventId then return end
        GuildUtils.Events:HostProcessSignup(GuildUtils.Events.SelectedEventId, UnitName("player"), UnitClass("player"), role)
        m:Hide()
    end
    
    m.tankBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate"); m.tankBtn:SetSize(70, 24); m.tankBtn:SetPoint("BOTTOMLEFT", 15, 15); m.tankBtn:SetText("Tank"); m.tankBtn:SetScript("OnClick", function() HandleRoleClick("Tank") end)
    m.healerBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate"); m.healerBtn:SetSize(70, 24); m.healerBtn:SetPoint("LEFT", m.tankBtn, "RIGHT", 5, 0); m.healerBtn:SetText("Healer"); m.healerBtn:SetScript("OnClick", function() HandleRoleClick("Healer") end)
    m.dpsBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate"); m.dpsBtn:SetSize(70, 24); m.dpsBtn:SetPoint("LEFT", m.healerBtn, "RIGHT", 5, 0); m.dpsBtn:SetText("DPS"); m.dpsBtn:SetScript("OnClick", function() HandleRoleClick("DPS") end)
    self.RoleModal = m
    return m
end

function GuildUtils.Events:HostProcessSignup(eventId, playerName, playerClass, role)
    local event = nil
    for _, e in ipairs(GU_GlobalDB.Events.list) do if e.id == eventId then event = e; break end end
    if not event then return end
    event.roster = event.roster or {}
    event.roster[playerName] = { class = playerClass, role = role, timestamp = time() }
    GuildUtils:Print("Signed up for " .. event.title .. " as " .. role, false)
    GuildUtils:QueueMessage(string.format("EVENT_SIGNUP:%d:%s:%s:%s", eventId, playerName, playerClass, role), "GUILD")
    if self.UpdateEventDetails and GuildUtils.Events.SelectedEventId == eventId then self:UpdateEventDetails(event) end
end

function GuildUtils.Events:HostProcessWithdraw(eventId, playerName)
    local event = nil
    for _, e in ipairs(GU_GlobalDB.Events.list) do if e.id == eventId then event = e; break end end
    if not event then return end
    if event.roster and event.roster[playerName] then
        event.roster[playerName] = nil
        GuildUtils:Print("Withdrawn from " .. event.title, false)
        GuildUtils:QueueMessage(string.format("EVENT_WITHDRAW:%d:%s", eventId, playerName), "GUILD")
        if self.UpdateEventDetails and GuildUtils.Events.SelectedEventId == eventId then self:UpdateEventDetails(event) end
    end
end

-- ============================================================================
-- PARTY LEADER VERIFICATION SCREEN & P2P CLAIM DISPATCH
-- ============================================================================

GuildUtils.Verification = GuildUtils.Verification or {}

function GuildUtils.Verification:CreateUI()
    if self.Frame then return end
    
    local f = CreateFrame("Frame", "GuildUtilsVerificationFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:Hide()
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("End Event: Roster Verification")
    
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.desc:SetPoint("TOP", 0, -25)
    f.desc:SetText("Select the members who qualify for quest/event progress.")
    
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 10, -50)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
    f.scrollChild:SetSize(360, 1)
    f.scrollFrame:SetScrollChild(f.scrollChild)
    
    f.submitBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.submitBtn:SetSize(120, 25)
    f.submitBtn:SetPoint("BOTTOM", 0, 15)
    f.submitBtn:SetText("Sign Off & Finish")
    
    f.submitBtn:SetScript("OnClick", function()
        GuildUtils.Verification:ProcessSignOff()
        f:Hide()
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
    
    for playerGuid, data in pairs(activeSessionRoster) do
        local row = self.RosterRows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, self.Frame.scrollChild)
            row:SetSize(340, 30)
            
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetPoint("LEFT", 5, 0)
            row.check:SetSize(24, 24)
            row.check:SetChecked(true)
            
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.check, "RIGHT", 10, 0)
            row.nameText:SetWidth(100)
            row.nameText:SetJustifyH("LEFT")
            
            row.metricText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.metricText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
            
            self.RosterRows[rowIndex] = row
        end
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        local classColor = RAID_CLASS_COLORS[data.class] or RAID_CLASS_COLORS["PRIEST"]
        row.nameText:SetText(data.name)
        row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        
        local mins = math.floor((data.timeInInstance or 0) / 60)
        row.metricText:SetText(string.format("Role: %s | Time: %d min", data.role or "N/A", mins))
        
        row.playerGuid = playerGuid
        row.playerName = data.name
        row:Show()
        
        yOffset = yOffset - 35
        rowIndex = rowIndex + 1
    end
    
    self.Frame.scrollChild:SetHeight(math.abs(yOffset))
    self.Frame:Show()
end

function GuildUtils.Verification:ProcessSignOff()
    if not self.CurrentEvent then return end
    
    local approvedPlayers = {}
    for _, row in ipairs(self.RosterRows) do
        if row:IsShown() and row.check:GetChecked() then
            table.insert(approvedPlayers, {guid = row.playerGuid, name = row.playerName})
        end
    end
    
    local eventID = tostring(self.CurrentEvent.id or "UnknownEvent")
    local basePay = tonumber(self.CurrentEvent.basePay) or 0
    local earlyBonus = tonumber(self.CurrentEvent.earlyBonus) or 0
    local rewardAmount = basePay + earlyBonus
    
    local eventTitle = "Raid Event"
    if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
        for _, e in ipairs(GU_GlobalDB.Events.list) do
            if tostring(e.id) == eventID then
                eventTitle = e.title
                break
            end
        end
    end
    
    if GuildUtils:IsAuthoritativeHost() then
        if rewardAmount > 0 and GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
            for _, pData in ipairs(approvedPlayers) do
                GuildUtils.LootCoin:ProcessTransaction(pData.guid, pData.name, rewardAmount, "Event Verified: " .. eventTitle)
            end
        end
        GuildUtils:Print("Event finalized. Payouts applied directly to master ledger.", false)
    else
        local serializedPlayers = {}
        for _, pData in ipairs(approvedPlayers) do
            table.insert(serializedPlayers, pData.guid .. "==" .. pData.name)
        end
        
        local payload = string.format("GU_LEADER_SIGNOFF:%s:%d:%s", eventID, rewardAmount, table.concat(serializedPlayers, ","))
        GuildUtils:QueueMessage(payload, "GUILD")
        GuildUtils:Print("Event finalized. Approval sheet sent to Host for payout.", false)
    end

    -- FIXED: Force the linked event selector back to "None" once sign-off is completed
    if GuildUtils.PartyRoller and GuildUtils.PartyRoller.ResetIdlePanel then
        GuildUtils.PartyRoller:ResetIdlePanel()
    end
end

-- Fallback network processor for remote officers sending sign-offs to a distant Host
local p2pListener = CreateFrame("Frame")
p2pListener:RegisterEvent("CHAT_MSG_ADDON")
p2pListener:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix ~= "GU_SYNC" then return end
    
    local command, payload = string.match(message, "^([^:]+):(.*)$")
    if not command then return end
    
    if command == "GU_LEADER_SIGNOFF" then
        local eventID, rewardStr, approvedList = string.match(payload, "^([^:]+):([^:]+):(.*)$")
        if not eventID then return end
        
        if GuildUtils:IsAuthoritativeHost() then
            local rewardAmount = tonumber(rewardStr) or 0
            if rewardAmount > 0 and GuildUtils.LootCoin and GuildUtils.LootCoin.ProcessTransaction then
                
                local eventTitle = "Raid Event"
                if GU_GlobalDB and GU_GlobalDB.Events and GU_GlobalDB.Events.list then
                    for _, e in ipairs(GU_GlobalDB.Events.list) do
                        if tostring(e.id) == eventID then
                            eventTitle = e.title
                            break
                        end
                    end
                end
                
                for approvedData in string.gmatch(approvedList or "", "([^,]+)") do
                    local pGuid, pName = string.match(approvedData, "^(.*)==(.*)$")
                    if pGuid and pName then
                        GuildUtils.LootCoin:ProcessTransaction(pGuid, pName, rewardAmount, "Event Verified: " .. eventTitle)
                    end
                end
            end
        end
    end
end)