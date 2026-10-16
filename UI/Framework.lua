local addonName, GuildUtils = ...
GuildUtils.UI = {}
GuildUtils.ActiveWindows = {}
GuildUtils.UI.isApplyingTheme = false -- Anti-recursion lock

-- ============================================================================
-- GLOBAL THEME ENGINE & LIVE TEXT RENDERING
-- ============================================================================
function GuildUtils.UI:ApplyTheme(themeIndex)
    if self.isApplyingTheme then return end
    self.isApplyingTheme = true

    GU_CharDB.Theme = themeIndex or GU_CharDB.Theme or 1
    local style = GuildUtils.Styles[GU_CharDB.Theme] or GuildUtils.Styles[1]
    
    for f, _ in pairs(GuildUtils.ActiveWindows) do
        if f.SetBackdrop then 
            if style.backdrop then
                f:SetBackdrop(style.backdrop)
                f:SetBackdropBorderColor(unpack(style.borderColor))
            else
                f:SetBackdrop(nil) 
            end
        end
        
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
        if f.colLeftText then f.colLeftText:SetTextColor(unpack(style.titleColor)) end
        if f.colRightText then f.colRightText:SetTextColor(unpack(style.titleColor)) end
        if f.searchBox then f.searchBox:SetTextColor(unpack(style.entryColor or style.nameColor)) end
    end
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Rows then
        for _, row in ipairs(GuildUtils.Ledger.Rows) do
            if row.nameText then row.nameText:SetTextColor(unpack(style.nameColor)) end
            if row.balText then row.balText:SetTextColor(unpack(style.balColor)) end
        end
    end
    
    if GuildUtils.Contracts and GuildUtils.Contracts.LeftRows then
        for _, row in ipairs(GuildUtils.Contracts.LeftRows) do
            if row.title then row.title:SetTextColor(unpack(style.nameColor)) end
            if row.reward then row.reward:SetTextColor(unpack(style.balColor)) end
        end
    end
    
    if GuildUtils.Events and GuildUtils.Events.EventRows then
        for _, row in ipairs(GuildUtils.Events.EventRows) do
            if row.title then row.title:SetTextColor(unpack(style.nameColor)) end
            if row.date then row.date:SetTextColor(unpack(style.balColor)) end
        end
    end

    if GuildUtils.Ledger and GuildUtils.Ledger.UpdateDisplay then GuildUtils.Ledger:UpdateDisplay() end
    if GuildUtils.Contracts and GuildUtils.Contracts.UpdateBoard then GuildUtils.Contracts:UpdateBoard() end
    if GuildUtils.Events and GuildUtils.Events.UpdateEventList then GuildUtils.Events:UpdateEventList() end
    if GuildUtils.PartyRoller and GuildUtils.PartyRoller.RefreshState then GuildUtils.PartyRoller:RefreshState() end

    self.isApplyingTheme = false -- Unlock after completion
end

-- ============================================================================
-- TAINT-FREE WINDOW GENERATION
-- ============================================================================
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
    
    -- FIX: Apply the active theme directly to this frame at birth
    -- This ensures dynamically spawned windows get their backgrounds instantly!
    local themeIdx = GU_CharDB and GU_CharDB.Theme or 1
    local style = GuildUtils.Styles and GuildUtils.Styles[themeIdx]
    if style then
        if style.backdrop then
            f:SetBackdrop(style.backdrop)
            f:SetBackdropBorderColor(unpack(style.borderColor))
        else
            f:SetBackdrop(nil) 
        end
        
        if style.bgFile then
            f.BgTexture:SetTexture(style.bgFile)
            f.BgTexture:SetVertexColor(unpack(style.bgColor))
            if style.texCoords then 
                f.BgTexture:SetTexCoord(unpack(style.texCoords)) 
            else 
                f.BgTexture:SetTexCoord(0, 1, 0, 1) 
            end
        end
    end
    
    return f
end

-- ============================================================================
-- GLOBAL GHOST MODE (COMBAT FADER)
-- ============================================================================
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