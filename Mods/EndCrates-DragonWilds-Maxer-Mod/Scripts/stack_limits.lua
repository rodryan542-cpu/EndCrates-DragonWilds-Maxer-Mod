-- Built-in stack limits. Item quantities, weight and save files are untouched.
return function(log)
    local target = 9999
    local pending = false

    local function patch_loaded_items()
        local ok, items = pcall(FindAllOf, "ItemData")
        if not ok or not items then
            log("No ItemData assets loaded yet.")
            return
        end
        local changed, stackable, errors = 0, 0, 0
        for _, item in ipairs(items) do
            local success = pcall(function()
                if not item:IsValid() then return end
                local limit = item.MaxStackSize
                -- Equipment and other single-instance items retain their limits.
                if type(limit) == "number" and limit > 1 then
                    stackable = stackable + 1
                    if limit < target then
                        item.MaxStackSize = target
                        if item.MaxStackSize ~= target then
                            error("Stack limit write did not persist")
                        end
                        changed = changed + 1
                    end
                end
            end)
            if not success then errors = errors + 1 end
        end
        log(string.format("Stacks: checked %d assets; %d stackable; raised %d to %d; errors=%d.",
            #items, stackable, changed, target, errors))
    end

    local function queue_patch()
        if pending then return end
        pending = true
        -- Newly loaded assets must finish deserializing before their defaults change.
        ExecuteWithDelay(2000, function()
            ExecuteInGameThread(function()
                pending = false
                patch_loaded_items()
            end)
        end)
    end

    local notify_ok, notify_error = pcall(function()
        NotifyOnNewObject("/Script/Dominion.ItemData", function() queue_patch() end)
    end)
    if not notify_ok then log("Asset notification unavailable: " .. tostring(notify_error)) end

    local hook_ok, hook_error = pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
            queue_patch()
            ExecuteWithDelay(12000, queue_patch)
        end)
    end)
    if not hook_ok then log("World-load hook unavailable: " .. tostring(hook_error)) end

    queue_patch()
end
