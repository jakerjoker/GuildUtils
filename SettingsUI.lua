local addonName, GuildUtils = ...
GuildUtils.SettingsUI = {}

function GuildUtils.SettingsUI:TogglePanel()
    if not self.Frame then
        local f = CreateFrame("Frame", "GuildUtilsSettingsFrame", UIParent, "BackdropTemplate")
        f:Hide()
        f:SetSize(400, 450)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText(GuildUtils.Constants and GuildUtils.Constants.Headers.SettingsMain or "GuildUtils: Settings")
        f.title:SetTextColor(1, 0.96, 0.41)

        f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

        local function CreateTab(id, text, xOffset, viewName)
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(110, 24)
            btn:SetPoint("TOPLEFT", 20 + xOffset, -40)
            btn:SetText(text)
            btn:SetScript("OnClick", function() GuildUtils.SettingsUI:SwitchView(viewName) end)
            return btn
        end

        f.tabAdmin = CreateTab(1, "Guild Admin", 0, "ADMIN")
        f.tabGeneral = CreateTab(2, "General", 125, "GENERAL")
        f.tabAppearance = CreateTab(3, "Appearance", 250, "APPEARANCE")

        f.content = CreateFrame("Frame", nil, f)
        f.content:SetPoint("TOPLEFT", 15, -75)
        f.content:SetPoint("BOTTOMRIGHT", -15, 15)

        f.AdminView = CreateFrame("Frame", nil, f.content)
        f.AdminView:SetAllPoints()
        f.GeneralView = CreateFrame("Frame", nil, f.content)
        f.GeneralView:SetAllPoints()
        f.AppearanceView = CreateFrame("Frame", nil, f.content)
        f.AppearanceView:SetAllPoints()

        -- ==========================================
        -- GUILD ADMINISTRATION VIEW
        -- ==========================================
        local adminDesc = f.AdminView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        adminDesc:SetPoint("TOPLEFT", 10, -10)
        adminDesc:SetText("Guild Administration Tools")
        adminDesc:SetTextColor(1, 1, 1)

        local btnElection = CreateFrame("Button", nil, f.AdminView, "UIPanelButtonTemplate")
        btnElection:SetSize(160, 26)
        btnElection:SetPoint("TOPLEFT", 10, -40)
        btnElection:SetText("Force Host Election")
        btnElection:SetScript("OnClick", function() GuildUtils:StartElection() end)

        local btnArchive = CreateFrame("Button", nil, f.AdminView, "UIPanelButtonTemplate")
        btnArchive:SetSize(160, 26)
        btnArchive:SetPoint("TOPLEFT", 10, -75)
        btnArchive:SetText("Manual Log Archive")
        btnArchive:SetScript("OnClick", function()
            GuildUtils:Print("Manual Archive Triggered.", false)
            if not GuildUtilsDB then GuildUtilsDB = {} end
            if not GuildUtilsDB.Ledger then GuildUtilsDB.Ledger = {auditLog={}} end
            GuildUtilsDB.Ledger.PENDING_LOG_EXPORT = true
            GuildUtils.SettingsUI:ShowExportWindow() 
        end)

        local rankLabel = f.AdminView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankLabel:SetPoint("TOPLEFT", 15, -115)
        rankLabel:SetText("Minimum Officer Rank:")

        local rankDropdownBtn = CreateFrame("Button", nil, f.AdminView, "UIPanelButtonTemplate")
        rankDropdownBtn:SetSize(160, 26)
        rankDropdownBtn:SetPoint("TOPLEFT", 10, -135)
        
        local function UpdateRankDropdownText()
            local currentRank = GuildUtilsDB.MinAdminRank or 3
            if not IsInGuild() then
                rankDropdownBtn:SetText("Rank " .. currentRank)
                return
            end
            local rName = GuildControlGetRankName(currentRank)
            rankDropdownBtn:SetText(rName and (currentRank .. ". " .. rName) or ("Rank " .. currentRank))
        end

        rankDropdownBtn:SetScript("OnShow", UpdateRankDropdownText)
        UpdateRankDropdownText()

        rankDropdownBtn:SetScript("OnClick", function(self)
            if not IsInGuild() then
                GuildUtils:Print("You must be in a guild to retrieve rank titles.", true)
                return
            end
            
            if MenuUtil then
                MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                    rootDescription:CreateTitle("Set Officer Threshold")
                    local numRanks = GuildControlGetNumRanks()
                    for i = 1, numRanks do
                        local rName = GuildControlGetRankName(i)
                        if rName then
                            rootDescription:CreateRadio(i .. ". " .. rName, 
                            function(index) return (GuildUtilsDB.MinAdminRank or 3) == index end, 
                            function(index) GuildUtilsDB.MinAdminRank = index; UpdateRankDropdownText() end, i)
                        end
                    end
                end)
            else
                GuildUtils:Print("Menu API not available in this client.", true)
            end
        end)

        -- ==========================================
        -- GENERAL PREFERENCES VIEW
        -- ==========================================
        local function CreateCheckbox(parent, name, point, text, dbKey)
            local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
            cb:SetPoint(unpack(point))
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            cb.text:SetText(text)
            cb:SetChecked(GuildUtilsDB[dbKey])
            cb:SetScript("OnClick", function(self) GuildUtilsDB[dbKey] = self:GetChecked() end)
            return cb
        end

        f.GeneralView.cbCompact = CreateCheckbox(f.GeneralView, "GUCBCompact", {"TOPLEFT", 10, -10}, "Enable Slim Compact Mode", "CompactMode")
        
        f.GeneralView.cbCompact:SetScript("OnClick", function(self) 
            GuildUtilsDB.CompactMode = self:GetChecked()
            local scale = GuildUtilsDB.CompactMode and 0.85 or 1.0
            if GuildUtils.LedgerFrame then GuildUtils.LedgerFrame:SetScale(scale) end
            if GuildUtilsGroupManagerFrame then GuildUtilsGroupManagerFrame:SetScale(scale) end
            if GuildUtilsSettingsFrame then GuildUtilsSettingsFrame:SetScale(scale) end
        end)

        f.GeneralView.cbAlerts = CreateCheckbox(f.GeneralView, "GUCBAlerts", {"TOPLEFT", 10, -40}, "Enable Desktop Alerts", "DesktopAlerts")
        f.GeneralView.cbDebug = CreateCheckbox(f.GeneralView, "GUCBDebug", {"TOPLEFT", 10, -70}, "Enable Diagnostic Debug Logging", "DebugMode")

        -- ==========================================
        -- APPEARANCE & THEMES VIEW
        -- ==========================================
        local function CreateRadio(name, point, text, profileKey)
            local cb = CreateFrame("CheckButton", name, f.AppearanceView, "UIRadioButtonTemplate")
            cb:SetPoint(unpack(point))
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            cb.text:SetText(text)
            
            cb:SetScript("OnClick", function(self)
                GuildUtilsDB.ActiveProfile = profileKey
                GuildUtils.SettingsUI:UpdateRadioStates()
                GuildUtils:Print("Profile switched to: " .. text, false)
            end)
            return cb
        end

        f.radioDefault = CreateRadio("GU_RadioDef", {"TOPLEFT", 10, -10}, "Default Customization", "Default")
        f.radioGuild = CreateRadio("GU_RadioGuild", {"TOPLEFT", 10, -35}, "Guild Customization", "Guild")
        f.radioPersonal = CreateRadio("GU_RadioPers", {"TOPLEFT", 10, -60}, "Personal Customization", "Personal")

        local themeLabel = f.AppearanceView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        themeLabel:SetPoint("TOPLEFT", 15, -100)
        themeLabel:SetText("Window Theme Override:")

        local function CreateThemeBtn(id, text, point)
            local btn = CreateFrame("Button", nil, f.AppearanceView, "UIPanelButtonTemplate")
            btn:SetSize(110, 24)
            btn:SetPoint(unpack(point))
            btn:SetText(text)
            btn:SetScript("OnClick", function() 
                GuildUtilsDB.Theme = id
                GuildUtils:ApplyTheme()
                if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
                if GuildUtils.PartyRoller and GuildUtils.PartyRoller.frame and GuildUtils.PartyRoller.frame:IsShown() then GuildUtils.PartyRoller:SetUIState(GuildUtils.PartyRoller.State) end
                GuildUtils:Print("Style applied: " .. text, false)
            end)
            return btn
        end

        CreateThemeBtn(1, "Blizzard Classic", {"TOPLEFT", 15, -120})
        CreateThemeBtn(2, "Modern Flat", {"TOPLEFT", 130, -120})
        CreateThemeBtn(3, "Floating Scroll", {"TOPLEFT", 245, -120})

        local colorLabel = f.AppearanceView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        colorLabel:SetPoint("TOPLEFT", 15, -165)
        colorLabel:SetText("Chat Notification Colors (Personal/Guild Profiles):")

        local function CreateColorPickerBtn(text, point, alertType)
            local btn = CreateFrame("Button", nil, f.AppearanceView, "UIPanelButtonTemplate")
            btn:SetSize(160, 24)
            btn:SetPoint(unpack(point))
            btn:SetText(text)

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetSize(14, 14)
            tex:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
            
            local function UpdateTexColor()
                local hex = GuildUtils:GetChatColor(alertType) or "FFFFFF"
                local r = tonumber(string.sub(hex, 1, 2), 16) / 255
                local g = tonumber(string.sub(hex, 3, 4), 16) / 255
                local b = tonumber(string.sub(hex, 5, 6), 16) / 255
                tex:SetColorTexture(r, g, b, 1)
            end
            
            btn.UpdateColorPreview = UpdateTexColor 
            btn:SetScript("OnShow", UpdateTexColor)
            
            btn:SetScript("OnClick", function()
                local active = GuildUtilsDB.ActiveProfile
                if active == "Default" then
                    GuildUtils:Print("Colors are locked on the Default profile. Switch to Personal or Guild.", true)
                    return
                end

                local hex = GuildUtils:GetChatColor(alertType) or "FFFFFF"
                local r = tonumber(string.sub(hex, 1, 2), 16) / 255
                local g = tonumber(string.sub(hex, 3, 4), 16) / 255
                local b = tonumber(string.sub(hex, 5, 6), 16) / 255

                local function OnColorChanged()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local newHex = string.format("%02X%02X%02X", nr*255, ng*255, nb*255)
                    GuildUtilsDB.Profiles[GuildUtilsDB.ActiveProfile].Colors[alertType] = newHex
                    UpdateTexColor()
                end
                
                local function OnColorCanceled(prev)
                    local newHex = string.format("%02X%02X%02X", prev.r*255, prev.g*255, prev.b*255)
                    GuildUtilsDB.Profiles[GuildUtilsDB.ActiveProfile].Colors[alertType] = newHex
                    UpdateTexColor()
                end

                if ColorPickerFrame.SetupColorPickerAndShow then
                    local info = {
                        swatchFunc = OnColorChanged,
                        cancelFunc = OnColorCanceled,
                        r = r, g = g, b = b,
                        hasOpacity = false,
                    }
                    ColorPickerFrame:SetupColorPickerAndShow(info)
                else
                    ColorPickerFrame.func = OnColorChanged
                    ColorPickerFrame.cancelFunc = OnColorCanceled
                    ColorPickerFrame.hasOpacity = false
                    ColorPickerFrame.previousValues = {r=r, g=g, b=b}
                    ColorPickerFrame:SetColorRGB(r, g, b)
                    ColorPickerFrame:Show()
                end
            end)
            return btn
        end

        f.AppearanceView.btnSystemAlerts = CreateColorPickerBtn("System Alerts", {"TOPLEFT", 15, -190}, "Normal")
        f.AppearanceView.btnWarningAlerts = CreateColorPickerBtn("Warning Alerts", {"TOPLEFT", 15, -220}, "Election")
        f.AppearanceView.btnRollQueueAlerts = CreateColorPickerBtn("Roll Queue Alerts", {"TOPLEFT", 15, -250}, "RollQueue")

        self.Frame = f
    end

    if self.Frame:IsShown() then
        self.Frame:Hide()
    else
        self.Frame:Show()
        self:SwitchView("ADMIN")
        self:UpdateRadioStates()
    end
end

function GuildUtils.SettingsUI:UpdateRadioStates()
    if not self.Frame then return end
    local active = GuildUtilsDB.ActiveProfile
    self.Frame.radioDefault:SetChecked(active == "Default")
    self.Frame.radioGuild:SetChecked(active == "Guild")
    self.Frame.radioPersonal:SetChecked(active == "Personal")
    
    if self.Frame.AppearanceView.btnSystemAlerts then
        self.Frame.AppearanceView.btnSystemAlerts.UpdateColorPreview()
        self.Frame.AppearanceView.btnWarningAlerts.UpdateColorPreview()
        self.Frame.AppearanceView.btnRollQueueAlerts.UpdateColorPreview()
    end
end

function GuildUtils.SettingsUI:SwitchView(viewName)
    self.Frame.AdminView:Hide()
    self.Frame.GeneralView:Hide()
    self.Frame.AppearanceView:Hide()
    
    if viewName == "ADMIN" then
        self.Frame.title:SetText(GuildUtils.Constants and GuildUtils.Constants.Headers.SettingsAdmin or "Guild Administration")
        self.Frame.AdminView:Show()
    elseif viewName == "GENERAL" then
        self.Frame.title:SetText(GuildUtils.Constants and GuildUtils.Constants.Headers.SettingsGeneral or "General Preferences")
        self.Frame.GeneralView:Show()
    elseif viewName == "APPEARANCE" then
        self.Frame.title:SetText(GuildUtils.Constants and GuildUtils.Constants.Headers.SettingsAppearance or "Appearance & Themes")
        self.Frame.AppearanceView:Show()
    end
end

-- ==========================================
-- LOG EXPORT WINDOW LOGIC
-- ==========================================
function GuildUtils.SettingsUI:ShowExportWindow()
    if not self.ExportFrame then
        local f = CreateFrame("Frame", "GuildUtilsExportFrame", UIParent, "BackdropTemplate")
        f:Hide()
        f:SetSize(450, 350)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText("Audit Log Export (Ctrl+C to Copy)")
        f.title:SetTextColor(1, 0.96, 0.41)

        f.closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.closeBtn:SetSize(100, 24)
        f.closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
        f.closeBtn:SetText("Close")
        f.closeBtn:SetScript("OnClick", function() f:Hide() end)

        f.clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.clearBtn:SetSize(120, 24)
        f.clearBtn:SetPoint("BOTTOMLEFT", 15, 15)
        f.clearBtn:SetText("Clear Archive")
        f.clearBtn:SetScript("OnClick", function()
            StaticPopupDialogs["GUILDUTILS_CONFIRM_ARCHIVE"] = {
                text = "|cFFFF0000WARNING:|r Are you sure you want to wipe the audit log? Make sure you have copied it first!",
                button1 = "Yes, Clear It", button2 = "Cancel",
                OnAccept = function()
                    if GuildUtilsDB and GuildUtilsDB.Ledger then
                        GuildUtilsDB.Ledger.auditLog = {}
                        GuildUtilsDB.Ledger.PENDING_LOG_EXPORT = false
                    end
                    GuildUtils:Print("Audit log has been successfully cleared.", false)
                    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay() end
                    f:Hide()
                end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("GUILDUTILS_CONFIRM_ARCHIVE")
        end)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 15, -40)
        sf:SetPoint("BOTTOMRIGHT", -35, 45)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(380)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide(); eb:ClearFocus() end)
        sf:SetScrollChild(eb)
        f.editBox = eb
        
        self.ExportFrame = f
    end

    local fullLog = ""
    if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.auditLog then
        for i = 1, #GuildUtilsDB.Ledger.auditLog do
            local entry = GuildUtilsDB.Ledger.auditLog[i]
            if type(entry) == "table" then
                local ts = entry.timestamp or "Unknown Time"
                local p = entry.pusher or "Unknown"
                local d = entry.details or "No details"
                fullLog = fullLog .. string.format("[%s] %s: %s", ts, p, d) .. "\n"
            else
                fullLog = fullLog .. tostring(entry) .. "\n"
            end
        end
    end

    if fullLog == "" then fullLog = "No audit logs available to export." end

    self.ExportFrame.editBox:SetText(fullLog)
    self.ExportFrame:Show()
    self.ExportFrame.editBox:HighlightText()
    self.ExportFrame.editBox:SetFocus()
end

SLASH_GUILDUTILSCONFIG1 = "/guconfig"
SLASH_GUILDUTILSCONFIG2 = "/lcconfig"
SlashCmdList["GUILDUTILSCONFIG"] = function()
    GuildUtils.SettingsUI:TogglePanel()
end