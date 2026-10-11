local addonName, GuildUtils = ...
GuildUtils.SettingsUI = {}

function GuildUtils.SettingsUI:TogglePanel()
    if not self.Frame then
        local f = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsSettingsFrame", UIParent, 400, 450)
        f:Hide(); f:SetPoint("CENTER")
        
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText(GuildUtils.Constants.Headers.SettingsMain)
        f.title:SetTextColor(1, 0.96, 0.41)

        local function CreateTab(id, text, xOffset, viewName)
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(110, 24); btn:SetPoint("TOPLEFT", 20 + xOffset, -40); btn:SetText(text)
            btn:SetScript("OnClick", function() GuildUtils.SettingsUI:SwitchView(viewName) end)
            return btn
        end

        f.tabAdmin = CreateTab(1, "Guild Admin", 0, "ADMIN")
        f.tabGeneral = CreateTab(2, "General", 125, "GENERAL")
        f.tabAppearance = CreateTab(3, "Appearance", 250, "APPEARANCE")

        f.content = CreateFrame("Frame", nil, f)
        f.content:SetPoint("TOPLEFT", 15, -75); f.content:SetPoint("BOTTOMRIGHT", -15, 15)

        f.AdminView = CreateFrame("Frame", nil, f.content); f.AdminView:SetAllPoints()
        f.GeneralView = CreateFrame("Frame", nil, f.content); f.GeneralView:SetAllPoints()
        f.AppearanceView = CreateFrame("Frame", nil, f.content); f.AppearanceView:SetAllPoints()

        local isGM = IsGuildLeader and IsGuildLeader() or IsInGuild() and (select(3, GetGuildInfo("player")) == 0)
        if not isGM then
            local lockMsg = f.AdminView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lockMsg:SetPoint("CENTER", 0, 20)
            lockMsg:SetText("|cFFFF0000[Permission Restricted]|r\nOnly Guild Masters or Rank 0 Officers\nmay configure global economy rules.")
            lockMsg:SetJustifyH("CENTER")
        else
            local adminDesc = f.AdminView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            adminDesc:SetPoint("TOPLEFT", 10, -10); adminDesc:SetText("Guild Administration Tools"); adminDesc:SetTextColor(1, 1, 1)

            local btnElection = CreateFrame("Button", nil, f.AdminView, "UIPanelButtonTemplate")
            btnElection:SetSize(160, 26); btnElection:SetPoint("TOPLEFT", 10, -40); btnElection:SetText("Force Host Election"); btnElection:SetScript("OnClick", function() GuildUtils.Network:StartElection() end)

            local btnArchive = CreateFrame("Button", nil, f.AdminView, "UIPanelButtonTemplate")
            btnArchive:SetSize(160, 26); btnArchive:SetPoint("TOPLEFT", 10, -75); btnArchive:SetText("Manual Log Archive"); btnArchive:SetScript("OnClick", function()
                GU_GlobalDB.Ledger.PENDING_LOG_EXPORT = true; GuildUtils.SettingsUI:ShowExportWindow()
            end)

            local hbSlider = CreateFrame("Slider", "GUSettingsHeartbeatSlider", f.AdminView, "OptionsSliderTemplate")
            hbSlider:SetPoint("TOPLEFT", 10, -120)
            hbSlider:SetWidth(250)
            hbSlider:SetMinMaxValues(5, 60)
            hbSlider:SetValueStep(1)
            hbSlider:SetObeyStepOnDrag(true)
            hbSlider:SetValue(GU_GlobalDB.Settings.HeartbeatRate or 5)
            _G[hbSlider:GetName() .. "Low"]:SetText("5s")
            _G[hbSlider:GetName() .. "High"]:SetText("60s")
            _G[hbSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. hbSlider:GetValue() .. "s")
            hbSlider:SetScript("OnValueChanged", function(selfSlider, value)
                GU_GlobalDB.Settings.HeartbeatRate = value
                _G[selfSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. value .. "s")
            end)
        end

        local function CreateCheckbox(parent, name, point, text, dbKey, onClickExtra)
            local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
            cb:SetPoint(unpack(point))
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal"); cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0); cb.text:SetText(text)
            cb:SetChecked(GU_CharDB[dbKey])
            cb:SetScript("OnClick", function(selfCb) GU_CharDB[dbKey] = selfCb:GetChecked(); if onClickExtra then onClickExtra(selfCb:GetChecked()) end end)
            return cb
        end

        CreateCheckbox(f.GeneralView, "GUCBAlerts", {"TOPLEFT", 10, -10}, "Enable Desktop Alerts", "DesktopAlerts")
        CreateCheckbox(f.GeneralView, "GUCBMinimap", {"TOPLEFT", 10, -40}, "Enable Smart Minimap Icon", "SmartMinimap", function(val) if GuildUtils.Minimap then GuildUtils.Minimap:SetVisible(val) end end)
        CreateCheckbox(f.GeneralView, "GUCBPopups", {"TOPLEFT", 10, -70}, "Enable PartyRoller Popups", "PartyRollerEnabled")

        local function CreateRadio(name, point, text, profileKey)
            local cb = CreateFrame("CheckButton", name, f.AppearanceView, "UIRadioButtonTemplate")
            cb:SetPoint(unpack(point)); cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal"); cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0); cb.text:SetText(text)
            cb:SetScript("OnClick", function() GU_CharDB.ActiveProfile = profileKey; GuildUtils.SettingsUI:UpdateRadioStates(); GuildUtils:Print("Profile switched to: " .. text, false) end)
            return cb
        end

        f.radioDefault = CreateRadio("GU_RadioDef", {"TOPLEFT", 10, -10}, "Default Customization", "Default")
        f.radioGuild = CreateRadio("GU_RadioGuild", {"TOPLEFT", 10, -35}, "Guild Customization", "Guild")
        f.radioPersonal = CreateRadio("GU_RadioPers", {"TOPLEFT", 10, -60}, "Personal Customization", "Personal")

        local themeLabel = f.AppearanceView:CreateFontString(nil, "OVERLAY", "GameFontNormal"); themeLabel:SetPoint("TOPLEFT", 15, -100); themeLabel:SetText("Window Theme Override:")

        local function CreateThemeBtn(id, text, point)
            local btn = CreateFrame("Button", nil, f.AppearanceView, "UIPanelButtonTemplate"); btn:SetSize(110, 24); btn:SetPoint(unpack(point)); btn:SetText(text)
            btn:SetScript("OnClick", function() GuildUtils.UI:ApplyTheme(id); GuildUtils:Print("Style applied: " .. text, false) end)
            return btn
        end

        CreateThemeBtn(1, "Blizzard Classic", {"TOPLEFT", 15, -120})
        CreateThemeBtn(2, "Modern Flat", {"TOPLEFT", 130, -120})
        CreateThemeBtn(3, "Floating Scroll", {"TOPLEFT", 245, -120})

        local colorLabel = f.AppearanceView:CreateFontString(nil, "OVERLAY", "GameFontNormal"); colorLabel:SetPoint("TOPLEFT", 15, -165); colorLabel:SetText("Chat Notification Colors:")

        local function CreateColorPickerBtn(text, point, alertType)
            local btn = CreateFrame("Button", nil, f.AppearanceView, "UIPanelButtonTemplate"); btn:SetSize(160, 24); btn:SetPoint(unpack(point)); btn:SetText(text)
            local tex = btn:CreateTexture(nil, "ARTWORK"); tex:SetSize(14, 14); tex:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
            
            local function UpdateTexColor()
                local hex = GuildUtils:GetChatColor(alertType) or "FFFFFF"
                tex:SetColorTexture(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255, 1)
            end
            
            btn.UpdateColorPreview = UpdateTexColor; btn:SetScript("OnShow", UpdateTexColor)
            
            btn:SetScript("OnClick", function()
                if GU_CharDB.ActiveProfile == "Default" then return GuildUtils:Print("Colors locked on Default profile.", true) end
                local hex = GuildUtils:GetChatColor(alertType) or "FFFFFF"
                local info = {
                    swatchFunc = function()
                        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                        GU_CharDB.Profiles[GU_CharDB.ActiveProfile].Colors[alertType] = string.format("%02X%02X%02X", nr*255, ng*255, nb*255)
                        UpdateTexColor()
                    end,
                    hasOpacity = false, r = tonumber(string.sub(hex, 1, 2), 16) / 255, g = tonumber(string.sub(hex, 3, 4), 16) / 255, b = tonumber(string.sub(hex, 5, 6), 16) / 255
                }
                if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info)
                else ColorPickerFrame.func = info.swatchFunc; ColorPickerFrame.hasOpacity = false; ColorPickerFrame:SetColorRGB(info.r, info.g, info.b); ColorPickerFrame:Show() end
            end)
            return btn
        end

        f.AppearanceView.btnSystemAlerts = CreateColorPickerBtn("System Alerts", {"TOPLEFT", 15, -190}, "Normal")
        f.AppearanceView.btnWarningAlerts = CreateColorPickerBtn("Warning Alerts", {"TOPLEFT", 15, -220}, "Election")
        f.AppearanceView.btnRollQueueAlerts = CreateColorPickerBtn("Roll Queue Alerts", {"TOPLEFT", 15, -250}, "RollQueue")

        -- DYNAMIC FONT SIZE SLIDER
        local fontSlider = CreateFrame("Slider", "GUSettingsFontSlider", f.AppearanceView, "OptionsSliderTemplate")
        fontSlider:SetPoint("TOPLEFT", 210, -200)
        fontSlider:SetWidth(150)
        fontSlider:SetMinMaxValues(9, 18)
        fontSlider:SetValueStep(1)
        fontSlider:SetObeyStepOnDrag(true)
        fontSlider:SetValue(GU_CharDB.LedgerFontSize or 12)
        _G[fontSlider:GetName() .. "Low"]:SetText("9")
        _G[fontSlider:GetName() .. "High"]:SetText("18")
        _G[fontSlider:GetName() .. "Text"]:SetText("Ledger Font Size: " .. fontSlider:GetValue())
        
        fontSlider:SetScript("OnValueChanged", function(selfSlider, value)
            GU_CharDB.LedgerFontSize = value
            _G[selfSlider:GetName() .. "Text"]:SetText("Ledger Font Size: " .. value)
            if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then
                GuildUtils.Ledger:UpdateDisplay()
            end
        end)

        self.Frame = f
    end

    if self.Frame:IsShown() then self.Frame:Hide() else self.Frame:Show(); self:SwitchView("ADMIN"); self:UpdateRadioStates() end
end

function GuildUtils.SettingsUI:UpdateRadioStates()
    if not self.Frame then return end
    local active = GU_CharDB.ActiveProfile
    self.Frame.radioDefault:SetChecked(active == "Default")
    self.Frame.radioGuild:SetChecked(active == "Guild")
    self.Frame.radioPersonal:SetChecked(active == "Personal")
    if self.Frame.AppearanceView.btnSystemAlerts then
        self.Frame.AppearanceView.btnSystemAlerts.UpdateColorPreview(); self.Frame.AppearanceView.btnWarningAlerts.UpdateColorPreview(); self.Frame.AppearanceView.btnRollQueueAlerts.UpdateColorPreview()
    end
end

function GuildUtils.SettingsUI:SwitchView(viewName)
    self.Frame.AdminView:Hide(); self.Frame.GeneralView:Hide(); self.Frame.AppearanceView:Hide()
    if viewName == "ADMIN" then self.Frame.title:SetText(GuildUtils.Constants.Headers.SettingsAdmin); self.Frame.AdminView:Show()
    elseif viewName == "GENERAL" then self.Frame.title:SetText(GuildUtils.Constants.Headers.SettingsGeneral); self.Frame.GeneralView:Show()
    elseif viewName == "APPEARANCE" then self.Frame.title:SetText(GuildUtils.Constants.Headers.SettingsAppearance); self.Frame.AppearanceView:Show() end
end

function GuildUtils.SettingsUI:ShowExportWindow()
    if not self.ExportFrame then
        local f = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsExportFrame", UIParent, 450, 350)
        f:Hide(); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.title:SetPoint("TOP", 0, -15); f.title:SetText("Audit Log Export (Ctrl+C to Copy)"); f.title:SetTextColor(1, 0.96, 0.41)
        
        f.clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.clearBtn:SetSize(120, 24); f.clearBtn:SetPoint("BOTTOMLEFT", 15, 15); f.clearBtn:SetText("Clear Archive")
        f.clearBtn:SetScript("OnClick", function()
            if GU_GlobalDB and GU_GlobalDB.Ledger then GU_GlobalDB.Ledger.auditLog = {}; GU_GlobalDB.Ledger.PENDING_LOG_EXPORT = false end
            GuildUtils:Print("Audit log has been successfully cleared.", false)
            if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
            f:Hide()
        end)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT", 15, -40); sf:SetPoint("BOTTOMRIGHT", -35, 45)
        local eb = CreateFrame("EditBox", nil, sf); eb:SetMultiLine(true); eb:SetFontObject("ChatFontNormal"); eb:SetWidth(380); eb:SetAutoFocus(true); eb:SetScript("OnEscapePressed", function() f:Hide(); eb:ClearFocus() end); sf:SetScrollChild(eb)
        f.editBox = eb
        self.ExportFrame = f
    end

    local fullLog = ""
    if GU_GlobalDB and GU_GlobalDB.Ledger and GU_GlobalDB.Ledger.auditLog then
        for i = 1, #GU_GlobalDB.Ledger.auditLog do fullLog = fullLog .. tostring(GU_GlobalDB.Ledger.auditLog[i]) .. "\n" end
    end
    if fullLog == "" then fullLog = "No audit logs available to export." end
    self.ExportFrame.editBox:SetText(fullLog); self.ExportFrame:Show(); self.ExportFrame.editBox:HighlightText(); self.ExportFrame.editBox:SetFocus()
end