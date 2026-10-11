local addonName, GuildUtils = ...
GuildUtils.Minimap = {}

-- Math to keep the button orbiting exactly on the minimap ring
local function UpdateButtonPosition(btn, angle)
    local radius = 105 -- Expanded to orbit completely outside the minimap ring
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    
    local angle = math.deg(math.atan2(py - my, px - mx))
    if angle < 0 then angle = angle + 360 end
    
    self.db.angle = angle
    UpdateButtonPosition(self, angle)
end

local function CreateNativeMinimapButton(name, iconTexture, tooltipText, onClick)
    local btn = CreateFrame("Button", name, Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")
    
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetSize(31, 31)
    hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -4)
    hl:SetBlendMode("ADD")
    
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(25, 25)
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -4)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) 
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnClick", onClick)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(tooltipText, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    return btn
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    GU_CharDB.MinimapLedgerPos = GU_CharDB.MinimapLedgerPos or { angle = 225 }
    GU_CharDB.MinimapGLPos = GU_CharDB.MinimapGLPos or { angle = 200 }
    
    GuildUtils.Minimap.LedgerBtn = CreateNativeMinimapButton(
        "GuildUtilsMinimapLedger",
        "Interface\\Icons\\INV_Misc_Coin_02",
        "GuildUtils: Ledger\nLeft-Click: Open Ledger\nRight-Click: Open Settings",
        function(_, button)
            if button == "LeftButton" then
                if GuildUtils.Ledger then GuildUtils.Ledger:Toggle() end
            elseif button == "RightButton" then
                if GuildUtils.SettingsUI then GuildUtils.SettingsUI:TogglePanel() end
            end
        end
    )
    
    GuildUtils.Minimap.GLBtn = CreateNativeMinimapButton(
        "GuildUtilsMinimapGL",
        "Interface\\Icons\\INV_Misc_Dice_01",
        "GuildUtils: Action Dashboard\nLeft-Click: Open/Close Dashboard",
        function(_, button)
            if button == "LeftButton" then
                local f = GuildUtils.DashboardFrame
                if not f and GuildUtils.PartyRoller then 
                    f = GuildUtils.PartyRoller:InitializeUI() 
                end
                
                -- True toggle: Closes the window if it is already visible
                if f and f:IsShown() then
                    f:Hide()
                elseif f then
                    -- If hidden, open it and automatically route to the correct tab based on group state
                    f:Show()
                    if IsInGroup() or GuildUtils.SoloMode then
                        f.tabGL:Click()
                    else
                        if GuildUtils.Contracts then
                            f.tabBounty:Click()
                        end
                    end
                end
            end
        end
    )
    
    GuildUtils.Minimap.LedgerBtn.db = GU_CharDB.MinimapLedgerPos
    GuildUtils.Minimap.GLBtn.db = GU_CharDB.MinimapGLPos
    
    UpdateButtonPosition(GuildUtils.Minimap.LedgerBtn, GuildUtils.Minimap.LedgerBtn.db.angle)
    UpdateButtonPosition(GuildUtils.Minimap.GLBtn, GuildUtils.Minimap.GLBtn.db.angle)
    
    if GU_CharDB.SmartMinimap == false then GuildUtils.Minimap:SetVisible(false) end
end)

function GuildUtils.Minimap:SetVisible(show)
    GU_CharDB.SmartMinimap = show
    if show then
        if self.LedgerBtn then self.LedgerBtn:Show() end
        if self.GLBtn then self.GLBtn:Show() end
    else
        if self.LedgerBtn then self.LedgerBtn:Hide() end
        if self.GLBtn then self.GLBtn:Hide() end
    end
end