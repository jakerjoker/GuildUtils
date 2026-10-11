local addonName, GuildUtils = ...

-- 1. Name Normalization Wrapper
function GuildUtils:FormatName(rawName)
    if not rawName or rawName == "" then return nil end
    -- Strip server tags (e.g., "Jacob-Atiesh" -> "Jacob")
    local cleanName = Ambiguate(rawName, "none")
    -- Force lowercase, then capitalize the first letter
    cleanName = cleanName:lower():gsub("^%l", string.upper)
    return cleanName
end

-- 2. Cache Yielding Protocol (Wait for Server)
GuildUtils.ItemCacheQueue = {}
local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

cacheFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" and success then
        if GuildUtils.ItemCacheQueue[itemID] then
            -- Trigger all queued callbacks for this specific item now that data exists
            for _, callback in ipairs(GuildUtils.ItemCacheQueue[itemID]) do
                callback(itemID)
            end
            GuildUtils.ItemCacheQueue[itemID] = nil
        end
    end
end)

-- Universal function to fetch item data safely
function GuildUtils:GetItemOrYield(itemID, callback)
    local itemName, itemLink = GetItemInfo(itemID)
    if itemName then
        -- Item is already cached, execute immediately
        callback(itemID, itemName, itemLink)
    else
        -- Item is missing, queue the callback for when the server responds
        if not self.ItemCacheQueue[itemID] then
            self.ItemCacheQueue[itemID] = {}
        end
        table.insert(self.ItemCacheQueue[itemID], function(id)
            local name, link = GetItemInfo(id)
            callback(id, name, link)
        end)
    end
end