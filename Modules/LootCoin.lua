local addonName, GuildUtils = ...
GuildUtils.LootCoin = {}

function GuildUtils.LootCoin:GetEffectiveGuid(guid)
    if not GU_GlobalDB or not GU_GlobalDB.Ledger or not GU_GlobalDB.Ledger.altMap then return guid end
    return GU_GlobalDB.Ledger.altMap[guid] or guid
end

function GuildUtils.LootCoin:ProcessTransaction(guid, playerName, amount, reason)
    amount = tonumber(amount) or 0
    if amount == 0 then return end
    
    local targetGuid = self:GetEffectiveGuid(guid)
    local targetName = GU_GlobalDB.Ledger.roster[targetGuid] or playerName
    
    GU_GlobalDB.Ledger.roster[targetGuid] = targetName
    
    if GU_GlobalDB.Ledger.frozenAccounts[targetGuid] then
        GuildUtils:Print("Transaction blocked: " .. targetName .. " is frozen.", true)
        return
    end

    local currentBalance = GU_GlobalDB.Ledger.balances[targetGuid] or 0
    local newBalance = math.max(0, currentBalance + amount)
    
    GU_GlobalDB.Ledger.balances[targetGuid] = newBalance
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    
    local timestamp = date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] %s: %d LC (%s) - New Balance: %d", timestamp, targetName, amount, reason or "Manual Adjustment", newBalance)
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    
    GuildUtils:Print(string.format("Transaction: %s %d LC. Balance: %d", targetName, amount, newBalance), false)
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then 
        GuildUtils.Ledger:UpdateDisplay() 
    end
    
    if GuildUtils:IsAuthoritativeHost() then
        GuildUtils:QueueMessage("HEARTBEAT:" .. GU_GlobalDB.Ledger.version, "GUILD")
    end
end

function GuildUtils.LootCoin:LinkAlt(altGuid, altName, mainGuid, mainName)
    if not GuildUtils:IsAuthoritativeHost() then return end
    if altGuid == mainGuid then return end
    
    GU_GlobalDB.Ledger.altMap[altGuid] = mainGuid
    
    local altBal = GU_GlobalDB.Ledger.balances[altGuid] or 0
    if altBal > 0 then
        GU_GlobalDB.Ledger.balances[mainGuid] = (GU_GlobalDB.Ledger.balances[mainGuid] or 0) + altBal
        GU_GlobalDB.Ledger.balances[altGuid] = 0
        GuildUtils:Print(string.format("Consolidated %d LC from alt %s to main %s.", altBal, altName, mainName), false)
    end
    
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    local entry = string.format("[%s] Alt Linked: %s -> Main: %s", date("%Y-%m-%d %H:%M:%S"), altName, mainName)
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    
    GuildUtils:QueueMessage(string.format("SET_ALT_LINK:%s:%s:%s:%s", altGuid, altName, mainGuid, mainName), "GUILD")
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
end

function GuildUtils.LootCoin:UnlinkAlt(altGuid, altName)
    if not GuildUtils:IsAuthoritativeHost() then return end
    GU_GlobalDB.Ledger.altMap[altGuid] = nil
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    
    local entry = string.format("[%s] Alt Unlinked: %s", date("%Y-%m-%d %H:%M:%S"), altName)
    table.insert(GU_GlobalDB.Ledger.auditLog, entry)
    
    GuildUtils:QueueMessage(string.format("SET_ALT_UNLINK:%s:%s", altGuid, altName), "GUILD")
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then GuildUtils.Ledger:UpdateDisplay() end
end

function GuildUtils.LootCoin:AwardRaidAttendance(amount, reason)
    if not GuildUtils:IsAuthoritativeHost() then return end
    amount = tonumber(amount) or (GU_GlobalDB.Settings and GU_GlobalDB.Settings.AttendanceReward) or 10
    
    local count = 0
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            local name = GuildUtils:FormatName(UnitName(unit))
            if guid and name then
                self:ProcessTransaction(guid, name, amount, reason or "Raid Attendance")
                count = count + 1
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local unit = i == GetNumGroupMembers() and "player" or ("party" .. i)
            local guid = UnitGUID(unit)
            local name = GuildUtils:FormatName(UnitName(unit))
            if guid and name then
                self:ProcessTransaction(guid, name, amount, reason or "Group Attendance")
                count = count + 1
            end
        end
    else
        self:ProcessTransaction(UnitGUID("player"), GuildUtils:FormatName(UnitName("player")), amount, reason or "Solo Attendance")
        count = 1
    end
    GuildUtils:Print(string.format("Awarded %d LC attendance grant to %d members.", amount, count), false)
end

function GuildUtils.LootCoin:ToggleManagementFreeze(guid, playerName, newState)
    local targetGuid = self:GetEffectiveGuid(guid)
    if newState == "1" then
        GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = "F"
        GuildUtils:Print("Management freeze |F| applied to " .. tostring(playerName), true)
    else
        GU_GlobalDB.Ledger.frozenAccounts[targetGuid] = nil
        GuildUtils:Print("Management freeze |F| lifted for " .. tostring(playerName), false)
    end
    
    GU_GlobalDB.Ledger.version = (GU_GlobalDB.Ledger.version or 1) + 1
    
    if GuildUtils.Ledger and GuildUtils.Ledger.Frame and GuildUtils.Ledger.Frame:IsShown() then 
        GuildUtils.Ledger:UpdateDisplay() 
    end
    
    if GuildUtils:IsAuthoritativeHost() then
        GuildUtils:QueueMessage("HEARTBEAT:" .. GU_GlobalDB.Ledger.version, "GUILD")
    end
end