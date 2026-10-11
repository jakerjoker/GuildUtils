local addonName, GuildUtils = ...
GuildUtils.Minimap = {}

local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local icon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

local LedgerLDB = ldb and ldb:NewDataObject("GuildUtils_Ledger", {
    type = "data source",
    text = "GuildUtils Ledger",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    OnClick = function(_, button)
        if button == "LeftButton" then
            if GuildUtils.Ledger then GuildUtils.Ledger:Toggle() end
        elseif button == "RightButton" then
            if GuildUtils.SettingsUI then GuildUtils.SettingsUI:TogglePanel() end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText("GuildUtils: Ledger")
        tooltip:AddLine("Left-Click: Open Ledger", 1, 1, 1)
        tooltip:AddLine("Right-Click: Open Settings", 1, 1, 1)
    end,
})

local GLLDB = ldb and ldb:NewDataObject("GuildUtils_GL", {
    type = "data source",
    text = "GuildUtils Gear & Loot",
    icon = "Interface\\Icons\\INV_Misc_Dice_01",
    OnClick = function(_, button)
        if button == "LeftButton" then
            if IsInGroup() or GuildUtils.SoloMode then
                if GuildUtils.PartyRoller then GuildUtils.PartyRoller:Toggle() end
            else
                if GuildUtils.Contracts then GuildUtils.Contracts:Toggle() end
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText("GuildUtils: Gear & Loot")
        tooltip:AddLine("Left-Click: Open PartyRoller / Bounty Board", 1, 1, 1)
    end,
})

function GuildUtils.Minimap:SetVisible(show)
    if not icon then return end
    GU_CharDB.SmartMinimap = show
    if show then
        icon:Show("GuildUtils_Ledger")
        icon:Show("GuildUtils_GL")
    else
        icon:Hide("GuildUtils_Ledger")
        icon:Hide("GuildUtils_GL")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if icon then
        GU_CharDB.MinimapLedger = GU_CharDB.MinimapLedger or {}
        GU_CharDB.MinimapGL = GU_CharDB.MinimapGL or {}
        if LedgerLDB then icon:Register("GuildUtils_Ledger", LedgerLDB, GU_CharDB.MinimapLedger) end
        if GLLDB then icon:Register("GuildUtils_GL", GLLDB, GU_CharDB.MinimapGL) end
        
        if GU_CharDB.SmartMinimap == false then
            GuildUtils.Minimap:SetVisible(false)
        end
    end
end)