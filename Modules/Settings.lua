local addonName, GuildUtils = ...
GuildUtils.SettingsUI = {}

function GuildUtils.SettingsUI:TogglePanel()
    if not self.Frame then
        self.Frame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsSettingsFrame", UIParent, 320, 440)
        self.Frame:Hide()
        self.Frame:SetPoint("CENTER", -300, 0)
        
        local f = self.Frame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText("GuildUtils: Settings")
        f.title:SetTextColor(1, 0.96, 0.41)

        local function CreateCheckbox(label, dbKey, yOffset)
            local cb = CreateFrame("CheckButton", nil, f, "ChatConfigCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 20, yOffset)
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            cb.text:SetText(label)
            cb:SetChecked(GU_CharDB[dbKey])
            cb:SetScript("OnClick", function(selfBtn) GU_CharDB[dbKey] = selfBtn:GetChecked() end)
            return cb
        end

        f.cbMinimap = CreateCheckbox("Enable Minimap Icon", "SmartMinimap", -50)
        f.cbTooltips = CreateCheckbox("Show GuildUtils Tooltips", "ShowTooltips", -80)
        f.cbPartyRoller = CreateCheckbox("Enable PartyRoller Popups", "PartyRollerEnabled", -110)

        -- Heartbeat Slider
        f.hbSlider = CreateFrame("Slider", "GUSettingsHeartbeatSlider", f, "OptionsSliderTemplate")
        f.hbSlider:SetPoint("TOPLEFT", 25, -165)
        f.hbSlider:SetWidth(270)
        f.hbSlider:SetMinMaxValues(5, 60)
        f.hbSlider:SetValueStep(1)
        f.hbSlider:SetObeyStepOnDrag(true)
        f.hbSlider:SetValue(GU_GlobalDB.Settings.HeartbeatRate or 10)
        
        _G[f.hbSlider:GetName() .. "Low"]:SetText("5s")
        _G[f.hbSlider:GetName() .. "High"]:SetText("60s")
        _G[f.hbSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. f.hbSlider:GetValue() .. "s")

        f.hbSlider:SetScript("OnValueChanged", function(selfSlider, value)
            GU_GlobalDB.Settings.HeartbeatRate = value
            _G[selfSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. value .. "s")
        end)

        -- Ledger Font Size Slider
        f.fontSlider = CreateFrame("Slider", "GUSettingsFontSlider", f, "OptionsSliderTemplate")
        f.fontSlider:SetPoint("TOPLEFT", 25, -235)
        f.fontSlider:SetWidth(270)
        f.fontSlider:SetMinMaxValues(9, 18)
        f.fontSlider:SetValueStep(1)
        f.fontSlider:SetObeyStepOnDrag(true)
        f.fontSlider:SetValue(GU_CharDB.LedgerFontSize or 12)
        
        _G[f.fontSlider:GetName() .. "Low"]:SetText("9px")
        _G[f.fontSlider:GetName() .. "High"]:SetText("18px")
        _G[f.fontSlider:GetName() .. "Text"]:SetText("Ledger Font Size: " .. f.fontSlider:GetValue() .. "px")

        f.fontSlider:SetScript("OnValueChanged", function(selfSlider, value)
            GU_CharDB.LedgerFontSize = value
            _G[selfSlider:GetName() .. "Text"]:SetText("Ledger Font Size: " .. value .. "px")
            if GuildUtils.Ledger and GuildUtils.Ledger.UpdateDisplay then
                GuildUtils.Ledger:UpdateDisplay()
            end
        end)
    end

    if self.Frame:IsShown() then self.Frame:Hide() else self.Frame:Show() end
end

local function CreateGuildPaneButton()
    if not CommunitiesFrame or _G["GuildUtilsSettingsHook"] then return end
    local settingsBtn = CreateFrame("Button", "GuildUtilsSettingsHook", CommunitiesFrame, "UIPanelButtonTemplate")
    settingsBtn:SetText("GuildUtils")
    settingsBtn:SetSize(80, 22) 
    settingsBtn:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 2, -250)
    settingsBtn:SetScript("OnClick", function()
        GuildUtils.SettingsUI:TogglePanel()
        if GuildUtils.SettingsUI.Frame then
            GuildUtils.SettingsUI.Frame:ClearAllPoints()
            GuildUtils.SettingsUI.Frame:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 90, 0)
        end
    end)
end

local eventWatcher = CreateFrame("Frame")
eventWatcher:RegisterEvent("ADDON_LOADED")
eventWatcher:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_Communities" then
        CreateGuildPaneButton()
        self:UnregisterAllEvents()
    end
end)