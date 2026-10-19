-- EndCrates-DragonWilds-Maxer-Mod: local chat commands, with one queued game-thread update at a time.
local state, adapter = {}, nil
local pending = false
local function log(s) print("[EndCrates-DragonWilds-Maxer-Mod] "..tostring(s).."\n") end
local function reply(s)
    s=tostring(s); log(s)
    for _,w in ipairs(FindAllOf("ChatWidget") or {}) do
        pcall(function() w:OnChatErrorMessageReceived(FText("[EndCrate] "..s)) end)
    end
end
local function run(line,context)
    if not adapter then reply("Commands are still loading. Try again after entering your solo world."); return end
    local ok,why=pcall(adapter.run,line,context)
    if not ok then reply("Command stopped: "..tostring(why)) end
end
adapter = require("commands")(state, reply)
require("stack_limits")(log)
local function update()
    if adapter.tick then adapter.tick() end
end
RegisterHook("/Script/Dominion.OpenedChatSubWidget:OnTextCommitted",function(context,text,commit)
    local ok,why=pcall(function()
        if commit:get()~=1 then return end
        local line=text:get():ToString()
        if not line:match("^%s*!") then return end
        text:set(FText("")); commit:set(0)
        local w=context:get(); w.MessageSendBox:SetText(FText(""))
        run(line,w)
    end)
    if not ok then log("Chat input failed: "..tostring(why)) end
end,function() end)
RegisterHook("/Script/Dominion.OpenedChatSubWidget:OnSendMessageInputActionGamepadOnly",function(context)
    local ok,why=pcall(function()
        local w=context:get(); local line=w.MessageSendBox:GetText():ToString()
        if line:match("^%s*!") then w.MessageSendBox:SetText(FText("")); run(line,w) end
    end)
    if not ok then log("Controller input failed: "..tostring(why)) end
end,function() end)
for _,function_name in ipairs({"IsRecipeUnlocked","IsBuildingUnlocked"}) do
    RegisterHook("/Script/Dominion.ProgressComponent:"..function_name,function() end,function(context)
        if not state.unlockall then return end
        local ok,local_owner=pcall(function()
            local pc=context:get():GetOwner()
            return pc:IsLocalController() and pc:HasAuthority()
        end)
        if ok and local_owner then return true end
    end)
end
LoopAsync(500,function()
    if pending then return end
    pending=true
    -- A fresh closure per dispatch avoids reusing released native callback refs.
    ExecuteInGameThread(function()
        local ok,why=pcall(update)
        pending=false
        if not ok then log("Update stopped: "..tostring(why)) end
    end)
end)
log("Local chat commands loaded. Stack limit=9999.")
