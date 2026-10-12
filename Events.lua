local addonName, GuildUtils = ...
GuildUtils.Events = {}
GuildUtils.Events.initialized = false
GuildUtils.Events.SelectedEventId = nil

function GuildUtils.Events:CanManageEvents()
    local isGM = IsGuildLeader and IsGuildLeader() or (select(3, GetGuildInfo("player")) == 0)
    local rankIndex = select(3, GetGuildInfo("player")) or 99
    local isOfficerOrLeader = rankIndex <= 2
    
    return isGM or isOfficerOrLeader
end

function GuildUtils.Events:GetOfficerList()
    local officers = {}
    local numMembers = GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local name, _, rankIndex, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        if not rankIndex then
            -- Fallback if return index varies by client version
            _, _, rankIndex, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        end
        -- Filter for officers / raid leaders (rank index 0, 1, or 2)
        if name and rankIndex and rankIndex <= 2 then
            local cleanName = GuildUtils:FormatName(name)
            table.insert(officers, cleanName)
        end
    end
    if #officers == 0 then
        table.insert(officers, UnitName("player"))
    end
    return officers
end

function GuildUtils.Events:InitializeUI()
    if self.initialized then return end
    
    local mainFrame = GuildUtils.PartyRoller:InitializeUI()
    local f = mainFrame.EventsContainer
    self.Container = f

    -- HEADERS
    f.colLeftText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colLeftText:SetPoint("TOPLEFT", 20, -10)
    f.colLeftText:SetText("Upcoming Events")

    f.colRightText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.colRightText:SetPoint("TOPLEFT", 250, -10)
    f.colRightText:SetText("Event Details & Signups")

    -- DIVIDER
    local midDiv = f:CreateTexture(nil, "ARTWORK")
    midDiv:SetColorTexture(0.3, 0.3, 0.3, 1)
    midDiv:SetSize(1, 330)
    midDiv:SetPoint("TOP", 0, -10)
    midDiv:SetPoint("LEFT", f, "LEFT", 230, 0) 
    
    -- LEFT COLUMN: Create Event Button
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
        modal.dateBox:SetText(date("%m/%d"))
        modal.titleBox:SetText("")
        modal.titleBox:SetFocus()
        modal:Show()
    end)

    -- LEFT COLUMN: Scroll Frame for the Calendar List
    f.scrollLeft = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollLeft:SetPoint("TOPLEFT", 10, -40)
    f.scrollLeft:SetPoint("BOTTOMLEFT", f.createBtn, "TOPLEFT", 0, 5)
    f.scrollLeft:SetWidth(190) 
    
    f.childLeft = CreateFrame("Frame", nil, f.scrollLeft)
    f.childLeft:SetSize(190, 1)
    f.scrollLeft:SetScrollChild(f.childLeft)

    -- RIGHT COLUMN: Event Info Panel
    f.eventTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.eventTitle:SetPoint("TOPLEFT", 245, -35)
    f.eventTitle:SetText("No Event Selected")
    
    f.eventInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.eventInfo:SetPoint("TOPLEFT", f.eventTitle, "BOTTOMLEFT", 0, -5)
    f.eventInfo:SetText("Select an event from the list to view details.")

    -- RIGHT COLUMN: Scroll Frame for the Roster
    f.scrollRight = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollRight:SetPoint("TOPLEFT", 245, -80)
    f.scrollRight:SetPoint("BOTTOMRIGHT", -30, 50)
    
    f.childRight = CreateFrame("Frame", nil, f.scrollRight)
    f.childRight:SetSize(300, 1)
    f.scrollRight:SetScrollChild(f.childRight)

    -- RIGHT COLUMN: Management & Action Buttons
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
        GuildUtils.Events:ShowRoleSelector(GuildUtils.Events.SelectedEventId)
    end)

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(100, 24)
    f.cancelBtn:SetPoint("RIGHT", f.signupBtn, "LEFT", -5, 0)
    f.cancelBtn:SetText("Withdraw")
    f.cancelBtn:SetScript("OnClick", function()
        local eventId = GuildUtils.Events.SelectedEventId
        if not eventId then return end
        
        for _, event in ipairs(GU_GlobalDB.Events.list) do
            if event.id == eventId then
                local myGuid = UnitGUID("player")
                if event.roster and event.roster[myGuid] then
                    event.roster[myGuid] = nil
                    GuildUtils:Print("Withdrawn from " .. event.title, false)
                    local payload = string.format("%d:%s", eventId, myGuid)
                    GuildUtils:QueueMessage("EVENT_WITHDRAW:" .. payload, "GUILD")
                    GuildUtils.Events:UpdateEventDetails(event)
                else
                    GuildUtils:Print("You are not signed up for this event.", true)
                end
                break
            end
        end
    end)

    self.initialized = true
end

function GuildUtils.Events:GetCreateModal()
    if self.CreateModal then return self.CreateModal end
    
    local m = CreateFrame("Frame", "GuildUtilsEventCreateModal", UIParent, "BasicFrameTemplateWithInset")
    m:SetSize(300, 480)
    m:SetPoint("CENTER")
    m:SetFrameStrata("DIALOG")
    m:Hide()
    
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    m.title:SetPoint("TOP", 0, -5)
    m.title:SetText("Create Raid Event")
    
    local function CreateInput(name, parent, yOffset, defaultText, isNumeric)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 25, yOffset)
        label:SetText(name)
        
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(230, 20)
        box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 5, -5)
        box:SetAutoFocus(false)
        if defaultText then box:SetText(defaultText) end
        if isNumeric then box:SetNumeric(true) end
        return box
    end

    local function CreateDropdown(name, parent, yOffset, defaultVal)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 25, yOffset)
        label:SetText(name)
        
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(230, 22)
        btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        btn.selectedValue = defaultVal or UnitName("player")
        btn:SetText(btn.selectedValue)
        
        btn:SetScript("OnClick", function(selfBtn)
            MenuUtil.CreateContextMenu(selfBtn, function(owner, rootDescription)
                rootDescription:CreateTitle("Select Officer")
                local officers = GuildUtils.Events:GetOfficerList()
                for _, officerName in ipairs(officers) do
                    rootDescription:CreateButton(officerName, function()
                        selfBtn.selectedValue = officerName
                        selfBtn:SetText(officerName)
                    end)
                end
            end)
        end)
        return btn
    end

    m.titleBox = CreateInput("Event Title:", m, -40, "Molten Core")
    m.dateBox = CreateInput("Date (MM/DD):", m, -95, date("%m/%d"))
    m.timeBox = CreateInput("Time (HH:MM):", m, -150, "19:00")
    m.sizeBox = CreateInput("Max Players:", m, -205, "40", true)
    m.payoutBox = CreateInput("Flat Payout (LC per member):", m, -260, "25", true)
    
    -- Dropdowns for Raid Leader and Admin
    m.raidLeaderDropdown = CreateDropdown("Raid Leader:", m, -315, UnitName("player"))
    m.adminDropdown = CreateDropdown("Event Admin:", m, -370, UnitName("player"))
    
    m.confirmBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    m.confirmBtn:SetSize(100, 24)
    m.confirmBtn:SetPoint("BOTTOMLEFT", 40, 15)
    m.confirmBtn:SetText("Create")
    
    m.cancelBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    m.cancelBtn:SetSize(100, 24)
    m.cancelBtn:SetPoint("BOTTOMRIGHT", -40, 15)
    m.cancelBtn:SetText("Cancel")
    
    m.cancelBtn:SetScript("OnClick", function() m:Hide() end)
    
    m.confirmBtn:SetScript("OnClick", function()
        local t = m.titleBox:GetText()
        local d = m.dateBox:GetText()
        local tm = m.timeBox:GetText()
        local sz = tonumber(m.sizeBox:GetText()) or 40
        local payout = tonumber(m.payoutBox:GetText()) or 0
        local raidLeader = m.raidLeaderDropdown.selectedValue
        local admin = m.adminDropdown.selectedValue
        
        if t == "" or d == "" or tm == "" then
            GuildUtils:Print("All fields are required.", true)
            return
        end
        
        GuildUtils.Events:HostCreateEvent(t, d, tm, sz, payout, raidLeader, admin)
        m:Hide()
    end)
    
    self.CreateModal = m
    return m
end

function GuildUtils.Events:HostCreateEvent(title, dateStr, timeStr, maxSize, flatPayout, raidLeader, admin)
    local id = GU_GlobalDB.Events.nextId
    GU_GlobalDB.Events.nextId = id + 1
    
    local newEvent = {
        id = id,
        title = title,
        date = dateStr,
        time = timeStr,
        maxSize = maxSize,
        flatPayout = tonumber(flatPayout) or 0,
        raidLeader = raidLeader ~= "" and raidLeader or UnitName("player"),
        admin = admin ~= "" and admin or UnitName("player"),
        limits = { Tank = 2, Healer = 5, DPS = 33 },
        roster = {},
        creator = UnitName("player")
    }
    
    table.insert(GU_GlobalDB.Events.list, newEvent)
    GuildUtils:Print("Event Created: " .. title, false)
    
    local payload = string.format("%d:%s:%s:%s:%d:%d:%s:%s", id, title, dateStr, timeStr, maxSize, newEvent.flatPayout, newEvent.raidLeader, newEvent.admin)
    GuildUtils:QueueMessage("EVENT_ADD:" .. payload, "GUILD")
    
    if self.UpdateEventList then 
        self:UpdateEventList() 
    end
end

function GuildUtils.Events:UpdateEventList()
    if not self.initialized or not self.Container:IsShown() then return end
    
    local child = self.Container.childLeft
    self.EventRows = self.EventRows or {}
    
    for _, r in ipairs(self.EventRows) do r:Hide() end
    
    local yOffset = -5
    local rowIndex = 1
    
    for _, event in ipairs(GU_GlobalDB.Events.list or {}) do
        local row = self.EventRows[rowIndex]
        if not row then
            row = CreateFrame("Button", nil, child)
            row:SetSize(170, 40)
            
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
            
            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.title:SetPoint("TOPLEFT", 5, -5)
            row.title:SetWidth(160)
            row.title:SetJustifyH("LEFT")
            row.title:SetWordWrap(false)
            
            row.date = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.date:SetPoint("BOTTOMLEFT", 5, 5)
            
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            
            self.EventRows[rowIndex] = row
        end
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 5, yOffset)
        
        row.title:SetText(event.title)
        row.date:SetText(string.format("%s @ %s", event.date, event.time))
        
        row:SetScript("OnClick", function()
            GuildUtils.Events.SelectedEventId = event.id
            GuildUtils.Events:UpdateEventList()
            GuildUtils.Events:UpdateEventDetails(event)
        end)
        
        if GuildUtils.Events.SelectedEventId == event.id then
            row.bg:SetColorTexture(0.2, 0.4, 0.8, 0.6)
        else
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
        end
        
        row:Show()
        rowIndex = rowIndex + 1
        yOffset = yOffset - 45
    end
    
    child:SetHeight(math.max(300, math.abs(yOffset)))
end

function GuildUtils.Events:UpdateEventDetails(event)
    if not event then return end
    
    self.Container.eventTitle:SetText(event.title)
    self.Container.eventInfo:SetText(string.format(
        "Date: %s | Time: %s | Max Size: %d\nFlat Payout: %d LC\nRaid Leader: %s | Admin: %s\nCreator: %s", 
        event.date, event.time, event.maxSize, event.flatPayout or 0, event.raidLeader or "None", event.admin or "None", event.creator
    ))
    
    self:UpdateRosterDisplay(event)
end

function GuildUtils.Events:UpdateRosterDisplay(event)
    local child = self.Container.childRight
    if self.RosterRows then
        for _, r in ipairs(self.RosterRows) do r:Hide() end
    end
    self.RosterRows = {}
    
    local yOffset = -5
    for guid, data in pairs(event.roster or {}) do
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(300, 20)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 5, 0)
        text:SetText(string.format("%s - Role: %s", data.name, data.role))
        
        row:Show()
        table.insert(self.RosterRows, row)
        yOffset = yOffset - 22
    end
    
    child:SetHeight(math.max(200, math.abs(yOffset)))
end

function GuildUtils.Events:ShowRoleSelector(eventId)
    if not self.RoleModal then
        local m = CreateFrame("Frame", "GuildUtilsRoleModal", UIParent, "BasicFrameTemplateWithInset")
        m:SetSize(220, 160)
        m:SetPoint("CENTER")
        m:SetFrameStrata("DIALOG")
        m:Hide()
        
        m.title = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        m.title:SetPoint("TOP", 0, -5)
        m.title:SetText("Select Your Role")
        
        local function CreateRoleBtn(text, y, role)
            local btn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
            btn:SetSize(160, 24)
            btn:SetPoint("TOP", 0, y)
            btn:SetText(text)
            btn:SetScript("OnClick", function()
                GuildUtils.Events:HostProcessSignup(m.eventId, role)
                m:Hide()
            end)
            return btn
        end
        
        m.tankBtn = CreateRoleBtn("Tank", -40, "Tank")
        m.healBtn = CreateRoleBtn("Healer", -70, "Healer")
        m.dpsBtn = CreateRoleBtn("DPS", -100, "DPS")
        
        self.RoleModal = m
    end
    
    self.RoleModal.eventId = eventId
    self.RoleModal:Show()
end

function GuildUtils.Events:HostProcessSignup(eventId, role)
    for _, event in ipairs(GU_GlobalDB.Events.list) do
        if event.id == eventId then
            local myGuid = UnitGUID("player")
            local myName = UnitName("player")
            
            event.limits = event.limits or { Tank = 2, Healer = 5, DPS = 33 }
            local roleCounts = { Tank = 0, Healer = 0, DPS = 0 }
            for _, data in pairs(event.roster or {}) do
                if roleCounts[data.role] then
                    roleCounts[data.role] = roleCounts[data.role] + 1
                end
            end
            
            if (roleCounts[role] or 0) >= (event.limits[role] or 99) then
                GuildUtils:Print(string.format("Signup failed: %s slots are full!", role), true)
                return
            end
            
            event.roster[myGuid] = { name = myName, role = role }
            GuildUtils:Print("Successfully signed up for " .. event.title .. " as " .. role, false)
            
            local payload = string.format("%d:%s:%s:%s", eventId, myGuid, myName, role)
            GuildUtils:QueueMessage("EVENT_SIGNUP:" .. payload, "GUILD")
            
            self:UpdateEventDetails(event)
            break
        end
    end
end

function GuildUtils.Events:DistributeEventPayout(eventId)
    if not GuildUtils:IsAuthoritativeHost() then return end
    
    for _, event in ipairs(GU_GlobalDB.Events.list) do
        if event.id == eventId then
            local payout = event.flatPayout or 0
            if payout <= 0 then return end
            
            GuildUtils:Print(string.format("Distributing flat payout of %d LC to participating members for %s.", payout, event.title), false)
            
            for guid, data in pairs(event.roster or {}) do
                if GuildUtils.LootCoin then
                    GuildUtils.LootCoin:ProcessTransaction(guid, data.name, payout, "Raid Event Payout: " .. event.title)
                end
            end
            
            event.flatPayout = 0
            break
        end
    end
end