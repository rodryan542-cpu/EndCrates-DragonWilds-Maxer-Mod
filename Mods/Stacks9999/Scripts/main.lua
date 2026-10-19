-- Local single-player stack limits. Never writes save files or item counts.
local TARGET = 9999
local pending = false

local function patch_loaded_items()
    local ok, items = pcall(FindAllOf, "ItemData")
    if not ok or not items then
        print("[Stacks9999] No ItemData assets loaded yet.\n")
        return
    end
    local changed, stackable, errors = 0, 0, 0
    for _, item in ipairs(items) do
        local success = pcall(function()
            if not item:IsValid() then return end
            local limit = item.MaxStackSize
            -- Keep weapons, equipment and other single-instance items unchanged.
            if type(limit) == "number" and limit > 1 then
                stackable = stackable + 1
                if limit < TARGET then
                    item.MaxStackSize = TARGET
                    if item.MaxStackSize ~= TARGET then
                        error("Stack limit write did not persist")
                    end
                    changed = changed + 1
                end
            end
        end)
        if not success then errors = errors + 1 end
    end
    print(string.format("[Stacks9999] Checked %d assets; %d stackable; raised %d to %d; errors=%d.\n",
        #items, stackable, changed, TARGET, errors))
end

local function queue_patch()
    if pending then return end
    pending = true
    ExecuteWithDelay(2000, function()
        ExecuteInGameThread(function()
            pending = false
            patch_loaded_items()
        end)
    end)
end

-- Delay until the new assets have finished deserializing their defaults.
local notify_ok, notify_error = pcall(function()
    NotifyOnNewObject("/Script/Dominion.ItemData", function()
        queue_patch()
    end)
end)
if not notify_ok then
    print("[Stacks9999] Asset notification unavailable: " .. tostring(notify_error) .. "\n")
end

local hook_ok, hook_error = pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        queue_patch()
        ExecuteWithDelay(12000, queue_patch)
    end)
end)
if not hook_ok then
    print("[Stacks9999] World-load hook unavailable: " .. tostring(hook_error) .. "\n")
end

queue_patch()
print("[Stacks9999] Loaded. Target=9999. Weight and single-instance items unchanged.\n")
