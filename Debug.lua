local addonName, GuildUtils = ...
GuildUtils.Debug = {}

SLASH_GUDEBUG_SPOOF1 = "/guspoof"
SlashCmdList["GUDEBUG_SPOOF"] = function(msg)
    local command, target = strsplit(" ", msg)
    local fakeSender = target or "OfficerDan"
    
    if command == "heartbeat" then
        local fakePayload = "HEARTBEAT:9999" 
        GuildUtils:Print("|cFFFF0000[DEBUG]|r Spoofing Heartbeat from " .. fakeSender, false)
        if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then
            GuildUtils.Network:OnMessageReceived("GU_SYNC", fakePayload, "GUILD", fakeSender)
        end
    elseif command == "election" then
        local fakePayload = string.format("ELECTION:%d:%d:%s", 3, 1, "Fake-GUID-123") 
        GuildUtils:Print("|cFFFF0000[DEBUG]|r Spoofing Election from " .. fakeSender, false)
        if GuildUtils.Network and GuildUtils.Network.OnMessageReceived then
            GuildUtils.Network:OnMessageReceived("GU_SYNC", fakePayload, "GUILD", fakeSender)
        end
    else
        GuildUtils:Print("Usage: /guspoof heartbeat [name] OR /guspoof election [name]", true)
    end
end

SLASH_GUDEBUG_STRESS1 = "/gustress"
SlashCmdList["GUDEBUG_STRESS"] = function()
    GuildUtils:Print("|cFFFF0000[DEBUG]|r Queueing 20 simultaneous payloads. Watch chat for 1.0s delays.", false)
    for i = 1, 20 do GuildUtils:QueueMessage("TEST_PAYLOAD_" .. i, "WHISPER", UnitName("player")) end
end

SLASH_GUDEBUG_UI1 = "/gufakeui"
SlashCmdList["GUDEBUG_UI"] = function(msg)
    if msg == "combat" then
        GuildUtils:Print("|cFFFF0000[DEBUG]|r Firing PLAYER_REGEN_DISABLED", false)
        for frame, _ in pairs(GuildUtils.ActiveWindows) do
            frame:SetAlpha(0.3)
            frame:EnableMouse(false)
        end
        C_Timer.After(5, function()
            GuildUtils:Print("|cFFFF0000[DEBUG]|r Firing PLAYER_REGEN_ENABLED", false)
            for frame, _ in pairs(GuildUtils.ActiveWindows) do
                frame:SetAlpha(1.0)
                frame:EnableMouse(true)
            end
        end)
    elseif msg == "roster" then
        GU_GlobalDB.Ledger.balances["DEBUG-1"] = 1500
        GU_GlobalDB.Ledger.roster["DEBUG-1"] = "FakeOfficer"
        GU_GlobalDB.Ledger.frozenAccounts["DEBUG-1"] = "GL"
        
        GU_GlobalDB.Ledger.balances["DEBUG-2"] = 50
        GU_GlobalDB.Ledger.roster["DEBUG-2"] = "TamperedUser"
        GU_GlobalDB.Ledger.frozenAccounts["DEBUG-2"] = "T"
        
        if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
    else
        GuildUtils:Print("Usage: /gufakeui combat OR /gufakeui roster", true)
    end
end