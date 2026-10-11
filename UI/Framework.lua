local addonName, GuildUtils = ...
GuildUtils.UI = {}
GuildUtils.ActiveWindows = {}

function GuildUtils.UI:ApplyTheme(themeIndex)
    GU_CharDB.Theme = themeIndex or GU_CharDB.Theme or 1
    local style = GuildUtils.Styles[GU_CharDB.Theme] or GuildUtils.Styles[1]
    for f, _ in pairs(GuildUtils.ActiveWindows) do
        if f.SetBackdrop then f:SetBackdrop(style.backdrop); if style.backdrop then f:SetBackdropBorderColor(unpack(style.borderColor)) end end
        if f.BgTexture then 
            f.BgTexture:SetTexture(style.bgFile)
            f.BgTexture:SetVertexColor(unpack(style.bgColor))
            if style.texCoords then 
                f.BgTexture:SetTexCoord(unpack(style.texCoords)) 
            else 
                f.BgTexture:SetTexCoord(0, 1, 0, 1) 
            end
        end
        if f.title then f.title:SetTextColor(unpack(style.titleColor)) end
    end
end

function GuildUtils.UI:CreateTaintFreeFrame(name, parent, width, height)
    local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetFrameStrata("HIGH")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f.BgTexture = f:CreateTexture(nil, "BACKGROUND")
    f.BgTexture:SetAllPoints(f)
    
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    
    GuildUtils.ActiveWindows[f] = true
    GuildUtils.UI:ApplyTheme()
    return f
end

local combatFader = CreateFrame("Frame")
combatFader:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFader:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFader:SetScript("OnEvent", function(self, event)
    local inCombat = (event == "PLAYER_REGEN_DISABLED")
    for frame, _ in pairs(GuildUtils.ActiveWindows) do
        if inCombat then frame:SetAlpha(0.3); frame:EnableMouse(false)
        else frame:SetAlpha(1.0); frame:EnableMouse(true) end
    end
end)