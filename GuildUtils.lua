local addonName, GuildUtils = ...

GuildUtils.frame = CreateFrame("Frame")
GuildUtils.framePool = {}
GuildUtils.Host = nil
GuildUtils.HeartbeatTimer = nil
GuildUtils.ElectionActive = false
GuildUtils.ActivePeers = {}
GuildUtils.SoloMode = false
GuildUtils.OutboundQueue = {}
GuildUtils.SyncThrottleTimer = nil

-- ============================================================================
-- STRUCTURAL STYLE ENGINE
-- ============================================================================
GuildUtils.Styles = {
    [1] = { 
        name = "Blizzard Classic", 
        backdrop = {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        bgColor = {1, 1, 1, 1},
        borderColor = {1, 1, 1, 1},
        titleColor = {1, 0.82, 0, 1},
        nameColor = {1, 0.82, 0, 1},
        balColor = {1, 1, 1, 1},
        texCoords = {0, 1, 0, 1}
    },
    [2] = { 
        name = "Modern Flat", 
        backdrop = {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        },
        bgFile = "Interface\\Buttons\\WHITE8x8",
        bgColor = {0.1, 0.1, 0.1, 0.95},
        borderColor = {0, 0, 0, 1},
        titleColor = {1, 1, 1, 1},
        nameColor = {0.9, 0.8, 0.2, 1},
        balColor = {1, 1, 1, 1},
        texCoords = {0, 1, 0, 1}
    },
    [3] = { 
        name = "Floating Scroll", 
        backdrop = nil,
        bgFile = "Interface\\QuestFrame\\QuestBG",
        bgColor = {1, 1, 1, 1},
        borderColor = {0, 0, 0, 0}, 
        titleColor = {0.2, 0.1, 0.05, 1},
        nameColor = {0, 0, 0, 1},
        balColor = {0.15, 0.1, 0.05, 1},
        texCoords = {0, 0.58, 0, 0.65}
    }
}

function GuildUtils:ApplyTheme()
    if not GuildUtilsDB then GuildUtilsDB = {} end
    local themeIndex = GuildUtilsDB.Theme or 1
    local style = GuildUtils.Styles[themeIndex] or GuildUtils.Styles[1]

    local function ApplyStyleToFrame(f)
        if not f then return end
        
        -- Fix window layering strata so they sit cleanly above background UI
        f:SetFrameStrata("HIGH")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(self)
            self:Raise()
        end)
        
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
        
        if f == GuildUtils.LedgerFrame then
            if f.hostLabel then f.hostLabel:SetTextColor(unpack(style.nameColor)) end
        end
        if GuildUtils.PartyRoller and f == GuildUtils.PartyRoller.frame then
            if f.IdlePanel and f.IdlePanel.info then f.IdlePanel.info:SetTextColor(unpack(style.nameColor)) end
            if f.IdlePanel and f.IdlePanel.nameLabel then f.IdlePanel.nameLabel:SetTextColor(unpack(style.nameColor)) end
            if f.PhaseB and f.PhaseB.queueText then f.PhaseB.queueText:SetTextColor(unpack(style.balColor)) end
        end
    end

    ApplyStyleToFrame(GuildUtils.LedgerFrame)
    if GuildUtils.PartyRoller and GuildUtils.PartyRoller.frame then
        ApplyStyleToFrame(GuildUtils.PartyRoller.frame)
    end
    if GuildUtils.ContextMenu then
        ApplyStyleToFrame(GuildUtils.ContextMenu)
    end
end

-- ============================================================================
-- CORE LOGIC & CHAT ROUTING
-- ============================================================================
function GuildUtils:GetChatColor(alertType)
    if not GuildUtilsDB or not GuildUtilsDB.ActiveProfile then 
        return GuildUtils.Constants and GuildUtils.Constants.ChatAlerts[alertType].defaultColor or "00BFFF" 
    end
    
    local activeProfile = GuildUtilsDB.ActiveProfile
    if activeProfile == "Default" or not GuildUtilsDB.Profiles[activeProfile].Colors[alertType] then
        return GuildUtils.Constants and GuildUtils.Constants.ChatAlerts[alertType].defaultColor or "00BFFF"
    end
    
    return GuildUtilsDB.Profiles[activeProfile].Colors[alertType]
end

function GuildUtils:Print(msg, alertTypeOrWarning)
    -- Route the alert type (supports legacy booleans or explicit strings)
    local alertType = "Normal"
    if type(alertTypeOrWarning) == "string" then
        alertType = alertTypeOrWarning
    elseif alertTypeOrWarning == true then
        alertType = "Election"
    end
    
    local color = self:GetChatColor(alertType)
    
    -- Wrap the ENTIRE message in the selected hex color
    local formattedMessage = string.format("|cFF%s[GuildUtils] %s|r", color, tostring(msg))
    print(formattedMessage)
end
function GuildUtils:TriggerDesktopAlert()
    if GuildUtilsDB and GuildUtilsDB.DesktopAlerts then
        FlashClientIcon()
    end
end
function GuildUtils:ProcessOutboundQueue()
    if #GuildUtils.OutboundQueue == 0 then return end
    local payload = table.remove(GuildUtils.OutboundQueue, 1)
    
    if GuildUtils.SoloMode and payload.channel ~= "GUILD" and payload.channel ~= "WHISPER" then
        GuildUtils:HandleSyncMessage(UnitName("player"), payload.msg)
        return
    end
    
    if payload.channel == "WHISPER" then C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, "WHISPER", payload.target)
    else C_ChatInfo.SendAddonMessage("GU_SYNC", payload.msg, payload.channel) end
end

function GuildUtils:SendSync(msg, specificChannel, target)
    if GuildUtils.SoloMode and not specificChannel then
        GuildUtils:HandleSyncMessage(UnitName("player"), msg)
        return
    end
    
    if not IsInGroup() and not specificChannel and not GuildUtils.SoloMode then
        GuildUtils:Print("You are not in a party or raid. Enable Solo Mode with /gusolo to test.", true)
        return
    end
    
    local targetChannel = specificChannel or (IsInRaid() and "RAID" or "PARTY")
    table.insert(GuildUtils.OutboundQueue, {msg = msg, channel = targetChannel, target = target})
    
    if not GuildUtils.SyncThrottleTimer then
        GuildUtils.SyncThrottleTimer = C_Timer.NewTicker(0.1, function()
            if #GuildUtils.OutboundQueue > 0 then GuildUtils:ProcessOutboundQueue()
            else
                GuildUtils.SyncThrottleTimer:Cancel()
                GuildUtils.SyncThrottleTimer = nil
            end
        end)
    end
end

GuildUtils.frame:RegisterEvent("ADDON_LOADED")
GuildUtils.frame:RegisterEvent("PLAYER_LOGIN")
GuildUtils.frame:RegisterEvent("PLAYER_GUILD_UPDATE")
GuildUtils.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
GuildUtils.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
GuildUtils.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
C_ChatInfo.RegisterAddonMessagePrefix("GU_SYNC")
GuildUtils.frame:RegisterEvent("CHAT_MSG_ADDON")

GuildUtils.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then 
            if not GuildUtilsDB then GuildUtilsDB = {} end
            
            -- Initialize Profile Architecture
            if not GuildUtilsDB.Profiles then
                GuildUtilsDB.Profiles = {
                    Guild = { Colors = {} },
                    Personal = { Colors = {} }
                }
            end
            GuildUtilsDB.ActiveProfile = GuildUtilsDB.ActiveProfile or "Default"
            GuildUtilsDB.Theme = GuildUtilsDB.Theme or 1
            
            GuildUtils:ApplyTheme()
            GuildUtils:Print("Load Successful", false) 
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_GUILD_UPDATE" then
        local guildName = GetGuildInfo("player")
        if guildName and not GuildUtils.HasInitialized then
            GuildUtils.HasInitialized = true
            GuildUtils:Print(string.format("Init Successful. '%s' Welcomes you back, %s!", guildName, UnitName("player")), false)
            if GuildUtils.LootCoin then
                GuildUtils.LootCoin:CheckAuditLogTrigger()
                if IsGuildLeader() then GuildUtils.LootCoin:BootstrapLedger() end
                
                if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.ActiveSession then
                    local isLeader = UnitIsGroupLeader("player")
                    if isLeader or GuildUtils.SoloMode then
                        GuildUtils:Print("Recovered active group session. Ledger deductions are still being tracked.", false)
                    end
                end
            end
            C_Timer.After(15, function()
                if not GuildUtils.Host and not GuildUtils.ElectionActive then GuildUtils:StartElection() end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then GuildUtils:SuspendSync()
    elseif event == "PLAYER_REGEN_ENABLED" then GuildUtils:ResumeSync()
    elseif event == "GROUP_ROSTER_UPDATE" then GuildUtils:ReconcileRoster(...)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == "GU_SYNC" then
            if UnitIsUnit(sender, "player") and not GuildUtils.SoloMode then return end
            
            -- FIX: Capture UnitName in a variable to drop the second return value (realm)
            local playerName = UnitName("player")
            
            local senderName = strtrim((strsplit("-", sender)))
            local myName = strtrim((strsplit("-", playerName)))
            
            if senderName == myName and not GuildUtils.SoloMode then return end
            
            GuildUtils:HandleSyncMessage(senderName, text)
        end
    end
end)

function GuildUtils:HandleSyncMessage(senderName, text)
    GuildUtils:Debug("Sync from " .. tostring(senderName) .. ": " .. text)
    local command, payload = string.match(text, "^([^:]+):(.*)$")
    command = command or text
    payload = payload or ""
    
    if command == "HEARTBEAT" then GuildUtils:AcknowledgeHeartbeat(senderName, tonumber(payload))
    elseif command == "ELECTION" then
        local rankStr, verStr, guidStr, inGroupStr = strsplit(":", payload)
        GuildUtils:ProcessElection(senderName, tonumber(rankStr), tonumber(verStr), guidStr, inGroupStr == "true")
    elseif command == "HOST_CHALLENGE" then GuildUtils:ProcessHostChallenge(senderName, tonumber(payload))
    elseif command == "PING" then GuildUtils:SendSync("PONG:rep", "GUILD")
    elseif command == "PONG" then GuildUtils.ActivePeers[senderName] = true
    elseif command == "RESET" then if GuildUtils.LootCoin then GuildUtils.LootCoin:PerformFactoryReset(senderName) end
    elseif command == "START_QUEUE" then
        if senderName == UnitName("player") and not GuildUtils.SoloMode then return end
        local durationStr, linksBlob = string.match(payload, "^([^:]+):(.*)$")
        local duration = tonumber(durationStr) or 5
        if linksBlob then
            local queueData = {}
            for chunk in string.gmatch(linksBlob, "([^;]+)") do
                local link, reservedStr = string.match(chunk, "^(.*)@@(.*)$")
                if link and link ~= "" then table.insert(queueData, {link = link, reserved = (reservedStr == "true")}) end
            end
            if #queueData > 0 then GuildUtils.PartyRoller:ClientStartQueue(queueData, duration) end
        end
    elseif command == "NEXT_ITEM" then
        local index = tonumber(payload)
        if index then GuildUtils.PartyRoller:ClientAdvanceQueue(index) end
    elseif command == "QUEUE_FINISHED" then GuildUtils.PartyRoller:ClientFinishQueue()
    elseif command == "BID_INTENT" then
        if UnitIsGroupLeader("player") or GuildUtils.SoloMode then GuildUtils.PartyRoller:ProcessBidIntent(senderName, payload) end
    elseif command == "BID_CONFIRMED" then
        local pName, typeStr, amtStr, rollStr, guidStr, tieStr = strsplit(":", payload)
        GuildUtils.PartyRoller:OnBidReceived(pName, typeStr, amtStr, rollStr, guidStr, tieStr)
    elseif command == "BID_REJECTED" then
        local targetGuid, reason = strsplit(":", payload)
        if targetGuid == UnitGUID("player") then GuildUtils.PartyRoller:OnBidRejected(reason) end
    elseif command == "RESULTS_CLOSED" then
        local index = tonumber(payload)
        if index then GuildUtils.PartyRoller:OnResultsClosed(senderName, index) end
    elseif command == "FREEZE_GROUP" then GuildUtils.LootCoin:ProcessGroupFreeze(payload)
    elseif command == "MERGE_GROUP" then GuildUtils.LootCoin:ProcessGroupMerge(payload)
    elseif command == "TOGGLE_FREEZE" then
        local tGuid, tName = strsplit(":", payload)
        GuildUtils.LootCoin:ToggleManagementFreeze(tGuid, tName, true)
    elseif command == "SET_FREEZE" then
        local tGuid, tName, tState = strsplit(":", payload)
        tState = tostring(tState or ""):gsub("%s+", "")
        GuildUtils.LootCoin:ToggleManagementFreeze(tGuid, tName, true, tState)
    elseif command == "MERGE_ACK" then GuildUtils.LootCoin:ReceiveMergeAck(payload)
    elseif command == "NOTIFY_GROUP" then
        if payload == "START" then
            if GuildUtilsDB and GuildUtilsDB.Ledger then GuildUtilsDB.Ledger.LocalSessionSpent = 0 end
            GuildUtils:Print("The loot event has started! Balances are frozen.", false)
        else GuildUtils:Print(payload, false) end
    elseif command == "NOTIFY_GUILD" then GuildUtils:Print(payload, false)
    elseif command == "SYNC_REQUEST" then
        if GuildUtils.Host == UnitName("player") then GuildUtils.LootCoin:SendLedgerSync(senderName) end
    elseif command == "SYNC_START" then
        local verStr, totalChunksStr = strsplit(":", payload)
        GuildUtils.LootCoin:ReceiveSyncStart(tonumber(verStr), tonumber(totalChunksStr))
    elseif command == "SYNC_CHUNK" then
        local indexStr, chunkData = string.match(payload, "^(%d+):(.*)$")
        if indexStr and chunkData then GuildUtils.LootCoin:ReceiveSyncChunk(tonumber(indexStr), chunkData) end
    elseif command == "SYNC_END" then GuildUtils.LootCoin:ReceiveSyncEnd(tonumber(payload))
    end
end

function GuildUtils:SuspendSync() GuildUtils:Print("Combat initiated, suspending heavy P2P operations.", true) end
function GuildUtils:ResumeSync()
    GuildUtils:Print("Combat ended, resuming background tasks.", false)
    if GuildUtils.LootCoin then GuildUtils.LootCoin:ValidateConsensus() end
end

function GuildUtils:ReconcileRoster(...)
    if GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.ActiveSession then
        if UnitIsGroupLeader("player") or GuildUtils.SoloMode then
            local prefix = IsInRaid() and "raid" or "party"
            local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
            local newMembers = {}
            for i = 1, numGroup do
                local unit = prefix .. i
                if UnitExists(unit) then
                    local guid = UnitGUID(unit)
                    if not GuildUtilsDB.Ledger.ActiveSession.members[guid] then
                        GuildUtilsDB.Ledger.ActiveSession.members[guid] = { name = UnitName(unit), start = GuildUtilsDB.Ledger.balances[guid] or 0, change = 0 }
                        table.insert(newMembers, guid)
                    end
                end
            end
            if #newMembers > 0 then
                local leaderGuid = UnitGUID("player")
                local payload = leaderGuid .. "@@" .. table.concat(newMembers, ",")
                GuildUtils.LootCoin:ProcessGroupFreeze(payload)
                GuildUtils:SendSync("FREEZE_GROUP:" .. payload, "GUILD")
                GuildUtils:Print("New group members detected and added to active session.", false)
            end
        end
    end
end

function GuildUtils:AcknowledgeHeartbeat(hostName, hostLedgerVersion)
    local oldHost = GuildUtils.Host
    GuildUtils.Host = hostName
    
    if oldHost ~= hostName and GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then
        GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText())
    end
    
    if GuildUtils.HeartbeatTimer then GuildUtils.HeartbeatTimer:Cancel() end
    GuildUtils.HeartbeatTimer = C_Timer.NewTicker(90, function()
        GuildUtils:Print("Host heartbeat lost (90s). Initiating election.", true)
        GuildUtils:StartElection()
    end)
    
    local localVersion = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.version) or 0
    if localVersion > hostLedgerVersion then
        GuildUtils:SendSync("HOST_CHALLENGE:" .. localVersion, "GUILD")
    elseif localVersion < hostLedgerVersion then
        GuildUtils:SendSync("SYNC_REQUEST:" .. localVersion, "WHISPER", hostName)
    end
    if GuildUtils.LootCoin then GuildUtils.LootCoin:PushPendingMerges() end
end
function GuildUtils:ProcessHostChallenge(senderVersion) end

function GuildUtils:StartElection()
    GuildUtils.ElectionActive = true
    local _, _, rankIndex = GetGuildInfo("player")
    local localVersion = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.version) or 0
    local myGuid = UnitGUID("player")
    local inGroupStr = tostring(IsInGroup())
    GuildUtils:SendSync(string.format("ELECTION:%d:%d:%s:%s", rankIndex, localVersion, myGuid, inGroupStr), "GUILD")
    C_Timer.After(3, function() GuildUtils:ConcludeElection() end)
end

function GuildUtils:ProcessElection(sender, senderRank, senderVersion, senderGuid, senderInGroup)
    if not GuildUtils.ElectionActive then return end
    local _, _, myRank = GetGuildInfo("player")
    local myVersion = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.version) or 0
    local myGuid = UnitGUID("player")
    local myInGroup = IsInGroup()
    
    local myLeadership = (myRank <= 3) and 1 or 2
    local senderLeadership = (senderRank <= 3) and 1 or 2
    local myGroupStatus = (myLeadership == 1 and not myInGroup) and 1 or 2
    local senderGroupStatus = (senderLeadership == 1 and not senderInGroup) and 1 or 2

    if senderVersion > myVersion then GuildUtils.ElectionActive = false
    elseif senderVersion == myVersion then
        if senderLeadership < myLeadership then GuildUtils.ElectionActive = false
        elseif senderLeadership == myLeadership then
            if senderGroupStatus < myGroupStatus then GuildUtils.ElectionActive = false
            elseif senderGroupStatus == myGroupStatus then
                if senderGuid < myGuid then GuildUtils.ElectionActive = false end
            end
        end
    end
end

function GuildUtils:ConcludeElection()
    if GuildUtils.ElectionActive then
        GuildUtils.ElectionActive = false
        GuildUtils.Host = UnitName("player")
        GuildUtils:Print("Election won. Assuming Authoritative Host role.", false)
        if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
        C_Timer.NewTicker(5, function()
            local ver = (GuildUtilsDB and GuildUtilsDB.Ledger and GuildUtilsDB.Ledger.version) or 0
            GuildUtils:SendSync("HEARTBEAT:" .. ver, "GUILD")
        end)
    end
end
function GuildUtils:Debug(msg)
    if GuildUtilsDB and GuildUtilsDB.DebugMode then
        print("|cFF808080[GU-Debug]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_GUILDUTILSTHEME1 = "/gutheme"
SlashCmdList["GUILDUTILSTHEME"] = function(msg)
    local index = tonumber(msg)
    if index and GuildUtils.Styles[index] then
        if not GuildUtilsDB then GuildUtilsDB = {} end
        GuildUtilsDB.Theme = index
        GuildUtils:ApplyTheme()
        if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
        if GuildUtils.PartyRoller and GuildUtils.PartyRoller.frame and GuildUtils.PartyRoller.frame:IsShown() then GuildUtils.PartyRoller:SetUIState(GuildUtils.PartyRoller.State) end
        GuildUtils:Print("Style applied: " .. GuildUtils.Styles[index].name, false)
    else
        GuildUtils:Print("Usage: /gutheme [1, 2, or 3]", true)
        GuildUtils:Print("1 = Blizzard Classic | 2 = Modern Flat | 3 = Floating Scroll", false)
    end
end

SLASH_GUILDUTILSHOST1 = "/guhost"
SlashCmdList["GUILDUTILSHOST"] = function()
    if GuildUtils.Host then GuildUtils:Print(string.format("Authoritative Host is: %s", GuildUtils.Host), false)
    else GuildUtils:Print("No Authoritative Host is currently active.", true) end
end

SLASH_GUILDUTILSSOLO1 = "/gusolo"
SlashCmdList["GUILDUTILSSOLO"] = function()
    GuildUtils.SoloMode = not GuildUtils.SoloMode
    if GuildUtils.SoloMode then
        GuildUtils.Host = UnitName("player")
        GuildUtils:Print("Solo Mode ENABLED. Host set to local player.", false)
    else
        GuildUtils.Host = nil
        GuildUtils:Print("Solo Mode DISABLED. Using party/raid sync.", false)
    end
    if GuildUtils.LedgerFrame and GuildUtils.LedgerFrame:IsShown() then GuildUtils:UpdateLedgerDisplay(GuildUtils.LedgerFrame.searchBox:GetText()) end
end

StaticPopupDialogs["GUILDUTILS_CONFIRM_RESET"] = {
    text = "|cFFFF0000WARNING:|r Are you sure you want to FACTORY RESET the LootCoin ledger?\n\nThis will wipe all local data and broadcast a hard reset to all online guild members. This cannot be undone.",
    button1 = "Yes, Reset",
    button2 = "Cancel",
    OnAccept = function()
        if GuildUtils.LootCoin then 
            GuildUtils.LootCoin:PerformFactoryReset(UnitName("player")) 
            GuildUtils:SendSync("RESET", "GUILD")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

SLASH_GUILDUTILSRESET1 = "/gureset"
SlashCmdList["GUILDUTILSRESET"] = function()
    StaticPopup_Show("GUILDUTILS_CONFIRM_RESET")
end

SLASH_GUILDUTILSHELP1 = "/guhelp"
SLASH_GUILDUTILSHELP2 = "/gu?"
SlashCmdList["GUILDUTILSHELP"] = function()
    GuildUtils:Print("Available Commands:", false)
    print("  |cFFFFFF00/gu|r or |cFFFFFF00/ledger|r - Open/Close the Ledger UI")
    print("  |cFFFFFF00/guloot|r - Open the Group & Loot Manager")
    print("  |cFFFFFF00/gutheme 1/2/3|r - Switch Window Styles")
    print("  |cFFFFFF00/guconfig|r - Open the Settings Panel")
    print("  |cFFFFFF00/gubid [Item]|r - Start a Loot Council queue for an item")
    print("  |cFFFFFF00/gustartgroup|r - Start a group loot event (freezes balances)")
    print("  |cFFFFFF00/guendgroup|r - End the active group event (merges balances)")
    print("  |cFFFFFF00/gunext|r - Force advance to the next item in the roll queue")
    print("  |cFFFFFF00/guhost|r - Display the current Authoritative Host")
    print("  |cFFFFFF00/gusolo|r - Toggle Solo Mode for local testing")
    print("  |cFFFFFF00/gureset|r - Factory reset the ledger (requires confirmation)")
    print("  |cFFFFFF00/gurefresh|r - Force refresh the Ledger UI display")
end

SLASH_GUILDUTILSNEXT1 = "/gunext"
SlashCmdList["GUILDUTILSNEXT"] = function()
    if not GuildUtils.SoloMode and not IsInGroup() then
        GuildUtils:Print("You must be in a party/raid or have Solo Mode enabled (/gusolo).", true)
        return
    end
    GuildUtils.PartyRoller:HostNextItem()
end

SLASH_GUILDUTILSSTARTGROUP1 = "/gustartgroup"
SlashCmdList["GUILDUTILSSTARTGROUP"] = function()
    if not GuildUtils.SoloMode then
        if not IsInGroup() then GuildUtils:Print("You are not in a group.", true) return end
        local lootMethod, mlPartyID = nil, nil
        if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
        if lootMethod ~= "master" then GuildUtils:Print("You are not currently in a masterloot group.", true) return end
        local isLeader = UnitIsGroupLeader("player")
        local isML = (mlPartyID == 0)
        if not isLeader and not isML then GuildUtils:Print("You are not the group leader or master looter.", true) return end
    end
    GuildUtils.LootCoin:StartGroupEvent()
end

SLASH_GUILDUTILSENDGROUP1 = "/guendgroup"
SlashCmdList["GUILDUTILSENDGROUP"] = function()
    if not GuildUtilsDB or not GuildUtilsDB.Ledger or not GuildUtilsDB.Ledger.ActiveSession then
        GuildUtils:Print("No active group event found.", true)
        return
    end
    if not GuildUtils.SoloMode then
        local isLeader = UnitIsGroupLeader("player")
        local lootMethod, mlPartyID = nil, nil
        if GetLootMethod then lootMethod, mlPartyID = GetLootMethod() end
        local isML = (lootMethod == "master" and mlPartyID == 0)
        if not isLeader and not isML then GuildUtils:Print("You are not the group leader or master looter.", true) return end
    end
    GuildUtils.LootCoin:EndGroupEvent()
end