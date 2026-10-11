local addonName, GuildUtils = ...
GuildUtils.SettingsUI = {}

function GuildUtils.SettingsUI:TogglePanel()
    if not self.Frame then
        self.Frame = GuildUtils.UI:CreateTaintFreeFrame("GuildUtilsSettingsFrame", UIParent, 420, 380)
        self.Frame:Hide()
        self.Frame:SetPoint("CENTER", -300, 0)
        
        local f = self.Frame
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText("GuildUtils: Settings")
        f.title:SetTextColor(1, 0.96, 0.41)

        -- Tab System
        f.tabs = {}
        f.panels = {}
        local tabNames = {"GM View", "General", "Appearance"}
        for i, name in ipairs(tabNames) do
            local tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            tab:SetSize(110, 24)
            tab:SetPoint("TOPLEFT", 25 + ((i-1) * 125), -45)
            tab:SetText(name)
            
            local panel = CreateFrame("Frame", nil, f)
            panel:SetPoint("TOPLEFT", 10, -75)
            panel:SetPoint("BOTTOMRIGHT", -10, 10)
            panel:Hide()
            
            tab:SetScript("OnClick", function()
                for _, p in ipairs(f.panels) do p:Hide() end
                panel:Show()
            end)
            f.tabs[i] = tab
            f.panels[i] = panel
        end

        -- Tab 1: GM View (Permission-Locked)
        local p1 = f.panels[1]
        local isGM = IsGuildLeader and IsGuildLeader() or IsInGuild() and (select(3, GetGuildInfo("player")) == 0)
        
        if not isGM then
            local lockMsg = p1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lockMsg:SetPoint("CENTER", 0, 20)
            lockMsg:SetText("|cFFFF0000[Permission Restricted]|r\nOnly Guild Masters or Rank 0 Officers\nmay configure global economy rules.")
            lockMsg:SetJustifyH("CENTER")
        else
            local hbSlider = CreateFrame("Slider", "GUSettingsHeartbeatSlider", p1, "OptionsSliderTemplate")
            hbSlider:SetPoint("TOPLEFT", 20, -30)
            hbSlider:SetWidth(250)
            hbSlider:SetMinMaxValues(5, 60)
            hbSlider:SetValueStep(1)
            hbSlider:SetObeyStepOnDrag(true)
            hbSlider:SetValue(GU_GlobalDB.Settings.HeartbeatRate or 10)
            _G[hbSlider:GetName() .. "Low"]:SetText("5s")
            _G[hbSlider:GetName() .. "High"]:SetText("60s")
            _G[hbSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. hbSlider:GetValue() .. "s")
            hbSlider:SetScript("OnValueChanged", function(selfSlider, value)
                GU_GlobalDB.Settings.HeartbeatRate = value
                _G[selfSlider:GetName() .. "Text"]:SetText("Smart Heartbeat Interval: " .. value .. "s")
            end)

            local rewardSlider = CreateFrame("Slider", "GUSettingsAttendanceSlider", p1, "OptionsSliderTemplate")
            rewardSlider:SetPoint("TOPLEFT", 20, -90)
            rewardSlider:SetWidth(250)
            rewardSlider:SetMinMaxValues(5, 50)
            rewardSlider:SetValueStep(5)
            rewardSlider:SetObeyStepOnDrag(true)
            rewardSlider:SetValue(GU_GlobalDB.Settings.AttendanceReward or 10)
            _G[rewardSlider:GetName() .. "Low"]:SetText("5 LC")
            _G[rewardSlider:GetName() .. "High"]:SetText("50 LC")
            _G[rewardSlider:GetName() .. "Text"]:SetText("Boss Kill Attendance Grant: " .. rewardSlider:GetValue() .. " LC")
            rewardSlider:SetScript("OnValueChanged", function(selfSlider, value)
                GU_GlobalDB.Settings.AttendanceReward = value
                _G[selfSlider:GetName() .. "Text"]:SetText("Boss Kill Attendance Grant: " .. value .. " LC")
            end)
        end
        
        -- Tab 2: General View
        local p2 = f.panels[2]
        local function CreateCheckbox(parent, label, dbKey, yOffset, onClickExtra)
            local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 15, yOffset)
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            cb.text:SetText(label)
            cb:SetChecked(GU_CharDB[dbKey])
            cb:SetScript("OnClick", function(selfBtn) 
                GU_CharDB[dbKey] = selfBtn:GetChecked()
                if onClickExtra then onClickExtra(selfBtn:GetChecked()) end
            end)
            return cb
        end

        CreateCheckbox(p2, "Enable Smart Minimap Icon", "SmartMinimap", -15, function(val)
            if GuildUtils.Minimap then GuildUtils.Minimap:SetVisible(val) end
        end)
        CreateCheckbox(p2, "Show Extended GuildUtils Tooltips", "ShowTooltips", -45)
        CreateCheckbox(p2, "Enable PartyRoller Loot Popups", "PartyRollerEnabled", -75)
        
        -- Tab 3: Appearance View
        local p3 = f.panels[3]
        local themeLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        themeLabel:SetPoint("TOPLEFT", 15, -15)
        themeLabel:SetText("Select UI Visual Theme:")

        local function CreateThemeBtn(label, themeIdx, xOffset)
            local btn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
            btn:SetSize(110, 24)
            btn:SetPoint("TOPLEFT", 15 + xOffset, -45)
            btn:SetText(label)
            btn:SetScript("OnClick", function()
                if GuildUtils.UI and GuildUtils.UI.ApplyTheme then
                    GuildUtils.UI:ApplyTheme(themeIdx)
                    GuildUtils:Print("Theme applied: " .. label, false)
                end
            end)
            return btn
        end

        CreateThemeBtn("Dark Slate", 1, 0)
        CreateThemeBtn("Citadel Steel", 2, 120)
        CreateThemeBtn("Parchment Gold", 3, 240)

        local resetBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
        resetBtn:SetSize(180, 24)
        resetBtn:SetPoint("TOPLEFT", 15, -100)
        resetBtn:SetText("Reset All Frame Positions")
        resetBtn:SetScript("OnClick", function()
            for frame, _ in pairs(GuildUtils.ActiveWindows) do
                frame:ClearAllPoints()
                frame:SetPoint("CENTER")
            end
        end)

        f.panels[2]:Show()
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