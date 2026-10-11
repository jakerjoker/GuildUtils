local addonName, GuildUtils = ...
GuildUtils.UI = {}
GuildUtils.ActiveWindows = {}

local THEME_PRESETS = {
    [1] = { r = 0.10, g = 0.10, b = 0.10, a = 0.95 }, -- Dark Slate
    [2] = { r = 0.08, g = 0.12, b = 0.18, a = 0.95 }, -- Citadel Steel
    [3] = { r = 0.18, g = 0.15, b = 0.10, a = 0.96 }, -- Parchment Gold
}

function GuildUtils.UI:ApplyTheme(themeIndex)
    GU_CharDB.Theme = themeIndex or GU_CharDB.Theme or 1
    local t = THEME_PRESETS[GU_CharDB.Theme] or THEME_PRESETS[1]
    for frame, _ in pairs(GuildUtils.ActiveWindows) do
        if frame.bg then
            frame.bg:SetColorTexture(t.r, t.g, t.b, t.a)
        end
    end
end

local combatFader = CreateFrame("Frame")
combatFader:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFader:RegisterEvent("PLAYER_REGEN_ENABLED")

combatFader:SetScript("OnEvent", function(self, event)
    local inCombat = (event == "PLAYER_REGEN_DISABLED")
    for frame, _ in pairs(GuildUtils.ActiveWindows) do
        if inCombat then
            frame:SetAlpha(0.3)
            frame:EnableMouse(false)
        else
            frame:SetAlpha(1.0)
            frame:EnableMouse(true)
        end
    end
end)

function GuildUtils.UI:CreateTaintFreeFrame(name, parent, width, height)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetSize(width, height)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    local themeIdx = (GU_CharDB and GU_CharDB.Theme) or 1
    local t = THEME_PRESETS[themeIdx] or THEME_PRESETS[1]

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(t.r, t.g, t.b, t.a)
    
    f.closeBtn = CreateFrame("Button", nil, f)
    f.closeBtn:SetSize(24, 24)
    f.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    f.closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    f.closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    f.closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    GuildUtils.ActiveWindows[f] = true
    return f
end