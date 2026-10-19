-- EndCrates-DragonWilds-Maxer-Mod local-world command handlers. No gameplay mutations at startup.
return function(state, reply)
    local C = require("core")
    local handlers = {}
    state.queue = state.queue or {}
    state.page = state.page or {}
    local function valid(o) return o and o:IsValid() end
    local function text(v)
        local ok, s = pcall(function() return v:ToString() end)
        return ok and s or tostring(v)
    end
    local function mypc(context)
        if context then
            local ok, pc = pcall(function() return context:GetOwningPlayer() end)
            if ok and valid(pc) and pc:IsLocalController() and pc:HasAuthority() then return pc end
        end
        for _, pc in ipairs(FindAllOf("PlayerController") or {}) do
            if valid(pc) and pc:IsLocalController() and pc:HasAuthority() then return pc end
        end
        error("Load a solo world that you own before using commands.", 0)
    end
    local function pawn(pc)
        if not valid(pc.Pawn) then error("Your character is not ready yet.", 0) end
        return pc.Pawn
    end
    local function cm(pc)
        local manager = pc.CheatManager
        if not valid(manager) then
            local class = StaticFindObject("/Script/Dominion.DominionCheatManager")
            if not valid(class) then error("This game build has no DominionCheatManager.", 0) end
            manager = StaticConstructObject(class, pc)
            if not valid(manager) then error("Could not create the local cheat manager.", 0) end
            pc.CheatManager = manager
            pcall(function() manager:ReceiveInitCheatManager() end)
        end
        return manager
    end
    local function cheat(pc, name, ...)
        local manager = cm(pc)
        local fn = manager[name]
        if not fn then error("Game function unavailable: " .. name, 0) end
        return fn(manager, ...)
    end
    local function assets(class, display_property)
        local rows = {}
        for _, obj in ipairs(FindAllOf(class) or {}) do
            if valid(obj) then
                local name = obj:GetFName():ToString()
                local display = name
                if display_property then pcall(function() display = text(obj[display_property]) end) end
                local path=obj:GetFullName()
                local deleted=path:lower():find("/deleted/",1,true) or path:lower():find("_deprecated",1,true) or path:lower():find("/futuremajorversion/",1,true)
                pcall(function() if obj.bSoftDeleted==true then deleted=true end end)
                if not name:match("^Default__") and not deleted then
                    local internal=name
                    pcall(function() local s=text(obj.InternalName); if s~="" then internal=s end end)
                    rows[#rows+1] = {obj=obj, name=name, internal=internal, display=display, path=path}
                end
            end
        end
        table.sort(rows, function(a,b) return a.name < b.name end)
        return rows
    end
    local function find(rows, query)
        local found, exact = {}, {}
        local key = C.key(query)
        for _, row in ipairs(rows) do
            if C.key(row.name) == key or C.key(row.display) == key or C.key(row.internal or "")==key then exact[#exact+1] = row
            elseif C.matches(row.name .. " " .. row.display .. " " .. (row.internal or ""), query) then found[#found+1] = row end
        end
        if #exact > 0 then return exact end
        return found
    end
    local function unique(rows, query)
        if C.trim(query) == "" then error("Enter a name. Use the list command to find one.", 0) end
        local found = find(rows, query)
        if #found == 0 then error("No match for: " .. query, 0) end
        if #found > 1 then
            local names = {}; for i=1, math.min(5,#found) do names[#names+1] = found[i].name end
            error("Name is ambiguous: " .. table.concat(names, ", ") .. ". Use an exact name.", 0)
        end
        return found[1]
    end
    local function listing(rows, query, label)
        local found = find(rows, query or "")
        local page = {}; for i=1, math.min(15,#found) do page[#page+1] = found[i].name .. (found[i].display ~= found[i].name and (" — " .. found[i].display) or "") end
        state.page = {}; for _, row in ipairs(found) do state.page[#state.page+1] = row.name .. " — " .. row.display end
        reply(label .. ": " .. #found .. " matches. " .. table.concat(page, "; ") .. (#found>15 and ". Type !more for the next page." or ""))
        state.page_index = 16
    end
    local function enqueue(label, functions)
        if #state.queue > 0 then error("Another bulk command is running. Use !cancel first.", 0) end
        if #functions == 0 then reply(label..": nothing to change."); return end
        state.queue, state.queue_label, state.queue_done, state.queue_failed = functions, label, 0, 0
        state.queue_pc=mypc()
        reply(label .. ": queued " .. #functions .. " operations.")
    end
    local function item_count(pc, data)
        return pc.BP_Components_Inventory:GetNumItemsByData(data)
    end
    local function give(pc, row, count)
        if not valid(pc) or not valid(row.obj) then error("The player or item was unloaded; command cancelled.",0) end
        local inv = pc.BP_Components_Inventory
        if not valid(inv) then error("Player inventory is not ready.", 0) end
        local before = inv:GetNumItemsByData(row.obj)
        inv:AddItemByData(row.obj, count, 1.0, {})
        local after = inv:GetNumItemsByData(row.obj)
        return math.max(0, after-before)
    end
    local function teleport(pc, location)
        local p = pawn(pc)
        local current = p:K2_GetActorLocation()
        local ok = p:BP_TriggerDelayedTeleport({
            LocationName=FName("None"),TargetLocation=location,TargetRotation=p:K2_GetActorRotation(),
            TeleportationType=0,TeleportBeginVFXDelayOverride=0.0,bShowLoadingScreen=true,
            bVFXOnTeleportStart=false,bVFXOnTeleportEnd=false,bNoCheck=false,bIsATest=false,
            bDropAnyLoadoutExclusiveEquipment=false,
        })
        if not ok then error("The game refused that destination. Your position was not changed.", 0) end
        state.back = {X=current.X, Y=current.Y, Z=current.Z}
        reply(string.format("Teleport accepted: %.0f %.0f %.0f. The game will load the destination.",location.X,location.Y,location.Z))
    end
    handlers.help = function(args)
        reply("EndCrates-DragonWilds-Maxer-Mod: !help !where !players !items <words> !give <item> [count] !equip <item> !giveall <words> [count] !preset <tier> [knight|ranger|mage] !geartier<N> !givequestitems [search]")
        reply("Skills/vitals: !skills !xp <skill|all> <amount> !level <skill|all> <level> !maxskills !heal !refill !god [on|off] !attr [word] !attr <name> <value> !damage <multiplier>")
        reply("Travel: !landmarks [search] !tp <landmark|x y z> !grave [list|n] !waypoint !goto <player> !tpenemy <name> !imaru !velgar !fuzan !kuldra !heart !back")
        reply("Progress: !recipes [words] !buildings [words] !unlockall [off] !unlockinfo !quests [search] !quest start|complete <name> !quest completeall !queststep <quest> [next|number] !questrestart <quest> !findstep <words> !mounts !mount [name] !urns !agilitygold !achievements")
        reply("Utilities: !resend !pvpme [on|off] !duel <player|off> !more !cancel !status. Commands affect your local character. Bulk progress commands run only when you type them.")
    end
    handlers.more = function()
        local lines, start = {}, state.page_index or 1
        for i=start,math.min(start+14,#state.page) do lines[#lines+1]=state.page[i] end
        state.page_index=start+15
        reply(#lines>0 and table.concat(lines,"; ") or "End of the current list.")
    end
    handlers.cancel = function() local n=#state.queue; state.queue={}; reply("Cancelled "..n.." remaining bulk operations.") end
    handlers.where = function(_, pc)
        local l=pawn(pc):K2_GetActorLocation(); reply(string.format("Coordinates: %.1f %.1f %.1f",l.X,l.Y,l.Z))
    end
    handlers.players = function()
        local names={}
        for _,pc in ipairs(FindAllOf("PlayerController") or {}) do
            pcall(function() if valid(pc.PlayerState) then names[#names+1]=text(pc.PlayerState:GetPlayerName()) end end)
        end
        reply("Players: "..table.concat(names,", "))
    end
    handlers.items = function(args) listing(assets("ItemData","Name"),C.join(args),"Items") end
    handlers.give = function(args,pc)
        local query,count=C.search_count(args,1); local row=unique(assets("ItemData","Name"),query)
        local actual=give(pc,row,count); reply("Added "..actual.." of "..row.name..(actual<count and " (inventory has no room for the remainder)." or "."))
    end
    handlers.equip = function(args,pc)
        local row=unique(assets("ItemData","Name"),C.join(args))
        if item_count(pc,row.obj)==0 and give(pc,row,1)==0 then error("No free inventory slot.",0) end
        cheat(pc,"domEquipItem",row.internal:gsub("^[Ii][Tt][Ee][Mm]_","")); reply("Equip requested: "..row.name)
    end
    handlers.giveall = function(args,pc)
        local query,count=C.search_count(args,1); local rows=find(assets("ItemData","Name"),query); local jobs={}
        for _,row in ipairs(rows) do jobs[#jobs+1]=function() give(pc,row,count) end end
        enqueue("Give matching items",jobs)
    end
    handlers.givequestitems = function(args,pc)
        local rows={}
        for _,row in ipairs(assets("ItemData","Name")) do
            local path=row.path:lower()
            if path:find("/quest/",1,true) or path:find("/quests/",1,true) or path:find("/resources/key/",1,true) or row.name:lower():match("^item_quest") then rows[#rows+1]=row end
        end
        local jobs={}; for _,row in ipairs(find(rows,C.join(args))) do jobs[#jobs+1]=function() give(pc,row,1) end end
        enqueue("Give quest items",jobs)
    end
    handlers.preset = function(args,pc)
        local tier=C.number(args[1],1,10,true,"Tier")
        local styles={knight=1,ranger=2,mage=3}; local style=args[2] and styles[args[2]:lower()] or 0
        if args[2] and not style then error("Use knight, ranger or mage.",0) end
        cheat(pc,"domGetGearPreset",tier,style); reply("Requested tier "..tier.." gear preset.")
    end
    handlers.heal = function(_,pc) cheat(pc,"domFullHeal"); reply("Health restored.") end
    handlers.refill = function(_,pc)
        cheat(pc,"domFullHeal"); cheat(pc,"domFullyRestoreSurvivalUpkeep")
        local sc=pawn(pc).StaminaComponent; sc:IncreaseStamina(math.max(0,sc:GetMaxStamina()-sc:GetStamina()))
        reply("Health, stamina, food, water and rest restored.")
    end
    handlers.god = function(args,pc)
        local enabled=C.toggle(args[1],state.god)
        cheat(pc,"domSetInvulnerable",enabled); cheat(pc,"domSetImmortal",enabled)
        state.god=enabled; if enabled then cheat(pc,"domFullHeal") end
        reply("God mode "..(enabled and "on" or "off")..".")
    end
    local function skills(pc)
        local sc=pc:GetPlayerSkillComponent(); local result={}
        sc.Skills:ForEach(function(i,e)
            local s=e:get(); local d=s.SkillData
            result[#result+1]={index=i,entry=s,obj=d,name=d:GetFName():ToString(),display=text(d.Name),xp=s.CurrentXP,level=sc:GetSkillLevel(d)}
        end)
        return sc,result
    end
    handlers.skills=function(_,pc)
        local _,rows=skills(pc); local out={}
        for _,s in ipairs(rows) do out[#out+1]=s.display.."="..s.level.." ("..s.xp.." XP)" end
        reply(table.concat(out,"; "))
    end
    local function update_skills(pc,query,mode,amount)
        local sc,rows=skills(pc); local targets=query:lower()=="all" and rows or {unique(rows,query)}
        local previous,changes={},{}
        for _,s in ipairs(rows) do previous[#previous+1]={SkillData=s.obj,CurrentXP=s.xp} end
        for _,s in ipairs(targets) do
            local newxp
            if mode=="level" or mode=="max" then
                newxp=sc:GetTotalXPNeededForLevel(math.min(amount,s.obj.MaxLevel))
                if mode=="max" then newxp=math.max(newxp,s.xp) end
            else newxp=math.min(2147483646,s.xp+amount) end
            if newxp~=s.xp then changes[#changes+1]={entry=s.entry,old=s.xp,new=newxp} end
        end
        for _,change in ipairs(changes) do change.entry.CurrentXP=change.new end
        if #changes>0 then sc:OnRep_Skills(previous) end
        for _,change in ipairs(changes) do if change.entry.CurrentXP~=change.new then error("The game refused an XP update.",0) end end
        reply("Updated "..#changes.." skill(s). Use !skills to check levels.")
    end
    handlers.xp=function(args,pc)
        if #args~=2 then error("Use !xp <skill|all> <amount>.",0) end
        update_skills(pc,args[1],"xp",C.number(args[2],0,2147483646,true,"XP"))
    end
    handlers.level=function(args,pc)
        if #args~=2 then error("Use !level <skill|all> <level>.",0) end
        update_skills(pc,args[1],"level",C.number(args[2],1,99,true,"Level"))
    end
    handlers.maxskills=function(_,pc) update_skills(pc,"all","max",99) end
    local function attributes(pc)
        local ac=pawn(pc).PlayerEncumbranceComponent.AttributesComponent; local rows={}
        for _,spec in ipairs({{"FloatAttributes","AttributeValues"},{"SharedFloatAttributes","SharedAttributeValues"}}) do
            ac[spec[1]]:ForEach(function(i,e)
                local a=e:get(); if valid(a) then
                    local n=a:GetClass():GetFName():ToString()
                    rows[#rows+1]={obj=a,index=i,values=spec[2],name=n,display=n,value=ac[spec[2]][i]}
                end
            end)
        end
        return ac,rows
    end
    handlers.attr=function(args,pc)
        local ac,rows=attributes(pc)
        if #args>=2 and tonumber(args[#args]) then
            local value=C.number(args[#args],-1000000,1000000,false,"Attribute value")
            local row=unique(rows,C.join(args,1,#args-1))
            row.obj.BaseValue=value; ac[row.values][row.index]=value
            ac:OnAttributeChanged(row.obj); reply(row.name.."="..tostring(value))
        else
            for _,row in ipairs(rows) do row.display=tostring(row.value) end
            listing(rows,C.join(args),"Attributes")
        end
    end
    handlers.damage=function(args,pc)
        local value=C.number(args[1],0,10000,false,"Damage multiplier")
        return handlers.attr({"DamageMultiplierAllCombatStylesAttribute",tostring(value)},pc)
    end
    handlers.quests=function(args) listing(assets("QuestData","QuestName"),C.join(args),"Quests") end
    handlers.quest=function(args,pc)
        local action=(args[1] or ""):lower(); local qpc=pc:GetQuestProgressComponent()
        if action=="completeall" then
            local jobs={}
            for _,q in ipairs(assets("QuestData","QuestName")) do
                if qpc:GetQuestState(q.obj)~=2 then jobs[#jobs+1]=function() qpc:CompleteQuest(q.obj,false) end end
            end
            enqueue("Complete quests",jobs); return
        end
        if action~="start" and action~="complete" then error("Use !quest start|complete <name>, or !quest completeall.",0) end
        local q=unique(assets("QuestData","QuestName"),C.join(args,2))
        if action=="start" then qpc:GiveQuest(q.obj,false) else qpc:CompleteQuest(q.obj,false) end
        reply(q.name..": state="..qpc:GetQuestState(q.obj))
    end
    local function objectives(q)
        local out={}
        q.obj.Objectives:ForEach(function(k,v)
            local data=v:get()
            out[#out+1]={key=text(k:get()),description=text(data.Description).." "..text(data.SubobjectiveDescription).." "..text(data.Hint)}
        end)
        local function natural(s) return s:lower():gsub("%d+",function(n)return string.format("%012d",tonumber(n)) end) end
        table.sort(out,function(a,b)return natural(a.key)<natural(b.key) end)
        return out
    end
    handlers.findstep=function(args)
        local query=C.join(args); if query=="" then error("Use !findstep <words>.",0) end
        local found={}
        for _,q in ipairs(assets("QuestData","QuestName")) do
            for _,step in ipairs(objectives(q)) do
                if C.matches(q.name.." "..step.key.." "..step.description,query) then
                    found[#found+1]={name=q.name.." / "..step.key,display=step.description}
                end
            end
        end
        listing(found,"","Quest steps")
    end
    handlers.queststep=function(args,pc)
        local mode="next"; local last=#args
        if last>1 and (args[last]:lower()=="next" or tonumber(args[last])) then mode=args[last]:lower();last=last-1 end
        local q=unique(assets("QuestData","QuestName"),C.join(args,1,last)); local steps=objectives(q)
        if #steps==0 then error("This quest has no named objectives.",0) end
        local qpc=pc:GetQuestProgressComponent(); local current="None"
        qpc.Quests:ForEach(function(_,e) local x=e:get(); if x.Data==q.obj then current=text(x.CurrentObjective) end end)
        local index=1
        if mode=="next" then
            for i,s in ipairs(steps) do if s.key==current then index=i+1;break end end
            if index>#steps then error("Already at the last named objective. Use !quest complete "..q.name.." to finish it.",0) end
        else index=C.number(mode,1,#steps,true,"Step") end
        if qpc:GetQuestState(q.obj)==0 then qpc:GiveQuest(q.obj,false) end
        qpc:SetQuestObjective(q.obj,FName(steps[index].key));reply(q.name..": objective "..steps[index].key.." — "..steps[index].description)
    end
    handlers.questrestart=function(args,pc)
        local q=unique(assets("QuestData","QuestName"),C.join(args)); local qpc=pc:GetQuestProgressComponent()
        local records={};local old_selected=nil;local new_selected=nil
        qpc.Quests:ForEach(function(_,e)
            local x=e:get()
            local copy={Data=x.Data,State=x.State,CurrentObjective=FName(text(x.CurrentObjective)),QuestBools={},QuestInts={}}
            x.QuestBools:ForEach(function(_,v)local b=v:get();copy.QuestBools[#copy.QuestBools+1]={QuestBoolName=FName(text(b.QuestBoolName)),bQuestBoolValue=b.bQuestBoolValue} end)
            x.QuestInts:ForEach(function(_,v)local n=v:get();copy.QuestInts[#copy.QuestInts+1]={QuestIntName=FName(text(n.QuestIntName)),QuestIntValue=n.QuestIntValue} end)
            if x.Data==q.obj then
                old_selected=copy
                new_selected={Data=q.obj,State=1,CurrentObjective=FName("None"),QuestBools={},QuestInts={}}
                records[#records+1]=new_selected
            else records[#records+1]=copy
            end
        end)
        if old_selected then qpc.Quests=records;qpc:OnQuestUpdated(old_selected,new_selected,true,true)
        else qpc:GiveQuest(q.obj,false) end
        reply("Restarted local quest progress: "..q.name..". Existing world actors and completed-world events are preserved.")
    end
    handlers.recipes=function(args,pc)
        if #args==0 then cheat(pc,"domUnlockAllRecipes");reply("All crafting recipes unlocked.");return end
        local selected=find(assets("RecipeData"),C.join(args));local objects={}
        for _,r in ipairs(selected) do objects[#objects+1]=r.obj end
        if #objects==0 then error("No matching recipes.",0) end
        pc.ProgressComponent:UnlockRecipes(objects);reply("Unlocked "..#objects.." matching recipes.")
    end
    handlers.buildings=function(args,pc)
        if #args==0 then cheat(pc,"domUnlockAllBuildingPieces");reply("All building pieces unlocked.");return end
        local selected=find(assets("BuildingPieceData","DisplayName"),C.join(args));local objects={}
        for _,r in ipairs(selected) do objects[#objects+1]=r.obj end
        if #objects==0 then error("No matching building pieces.",0) end
        pc.ProgressComponent:UnlockBuildings(objects);reply("Unlocked "..#objects.." matching building pieces.")
    end
    handlers.unlockall=function(args)
        state.unlockall=C.toggle(args[1],state.unlockall)
        reply("Temporary recipe/building unlock override "..(state.unlockall and "on" or "off")..". Reopen the crafting or building menu to refresh.")
    end
    handlers.unlockinfo=function(_,pc)
        local recipes,buildings=0,0
        for _,r in ipairs(assets("RecipeData")) do if pc.ProgressComponent:IsRecipeUnlocked(r.obj) then recipes=recipes+1 end end
        for _,r in ipairs(assets("BuildingPieceData")) do if pc.ProgressComponent:IsBuildingUnlocked(r.obj) then buildings=buildings+1 end end
        reply("Unlocked recipes="..recipes.."; buildings="..buildings.."; temporary unlock-all="..tostring(state.unlockall==true))
    end
    handlers.mounts = function(args) listing(assets("MountDataAsset","DisplayName"),C.join(args),"Mounts") end
    handlers.mount = function(args,pc)
        if #args==0 then return handlers.mounts(args,pc) end
        local row=unique(assets("MountDataAsset","DisplayName"),C.join(args))
        cheat(pc,"domSetMountUnlocked",row.name,true); cheat(pc,"domSetEquippedMount",row.name,true)
        reply("Mount equipped: "..row.name)
    end
    handlers.back = function(_,pc)
        if not state.back then error("No previous teleport position.",0) end
        teleport(pc,state.back)
    end
    local function landmarks()
        local rows={}; local reg=FindFirstOf("GameplayObjectRegistry")
        if valid(reg) then reg.Landmarks:ForEach(function(i,e)
            local l=e:get();local internal=text(l.InternalName);local display=text(l.UserVisibleDescription)
            if display=="" then display=internal~="None" and internal or ("Landmark "..i) end
            rows[#rows+1]={name=internal~="None" and internal or display,display=display,internal=internal,location={X=l.Location.X,Y=l.Location.Y,Z=l.Location.Z},category=l.Category,guid={A=l.Identifier.A,B=l.Identifier.B,C=l.Identifier.C,D=l.Identifier.D}}
        end) end
        for _,obj in ipairs(FindAllOf("TeleportationTarget") or {}) do
            if valid(obj) then
                local name=text(obj.TargetName);local l=obj:K2_GetActorLocation()
                rows[#rows+1]={name=name,display=name,internal=name,location={X=l.X,Y=l.Y,Z=l.Z},target=true}
            end
        end
        return rows
    end
    handlers.landmarks=function(args) listing(landmarks(),C.join(args),"Teleport destinations") end
    handlers.tp = function(args,pc)
        if #args==3 and tonumber(args[1]) and tonumber(args[2]) and tonumber(args[3]) then
            return teleport(pc,{X=C.number(args[1],-10000000,10000000,false,"X"),Y=C.number(args[2],-10000000,10000000,false,"Y"),Z=C.number(args[3],-10000000,10000000,false,"Z")})
        end
        local dest=unique(landmarks(),C.join(args));local l=dest.location
        teleport(pc,{X=l.X,Y=l.Y,Z=l.Z+150})
    end
    handlers.waypoint = function(_,pc)
        local marker=pc.MapCustomizationComponent.CurrentWaypoint
        if not valid(marker) then error("Place a waypoint on your map first.",0) end
        local l=marker:K2_GetActorLocation(); teleport(pc,{X=l.X,Y=l.Y,Z=l.Z+150})
    end
    local function guid(q)
        return string.format("%08X%08X%08X%08X",q.A & 0xFFFFFFFF,q.B & 0xFFFFFFFF,q.C & 0xFFFFFFFF,q.D & 0xFFFFFFFF)
    end
    handlers.grave=function(args,pc)
        local reg=FindFirstOf("GameplayObjectRegistry");if not valid(reg) then error("Gravestone registry is not ready.",0) end
        local mine=guid(pc:GetCharacterGuid().InnerGuid);local graves={}
        reg.Gravestones:ForEach(function(_,e)
            local g=e:get()
            if guid(g.OwningCharGuid.InnerGuid)==mine then graves[#graves+1]={X=g.Location.X,Y=g.Location.Y,Z=g.Location.Z} end
        end)
        if #graves==0 then error("You have no gravestone in this world.",0) end
        if args[1]=="list" then
            local out={};for i,l in ipairs(graves) do out[#out+1]=string.format("%d: %.0f %.0f %.0f",i,l.X,l.Y,l.Z) end
            reply(table.concat(out,"; "));return
        end
        local index=args[1] and C.number(args[1],1,#graves,true,"Gravestone") or #graves
        local l=graves[index];teleport(pc,{X=l.X+100,Y=l.Y,Z=l.Z+150})
    end
    handlers["goto"]=function(args,pc)
        local others={}
        for _,other in ipairs(FindAllOf("PlayerController") or {}) do
            if valid(other.PlayerState) and valid(other.Pawn) and other~=pc then
                local name=text(other.PlayerState:GetPlayerName());others[#others+1]={name=name,display=name,obj=other.Pawn}
            end
        end
        if #others==0 then error("There are no other players in your solo world.",0) end
        local other=unique(others,C.join(args));local l=other.obj:K2_GetActorLocation();teleport(pc,{X=l.X+150,Y=l.Y,Z=l.Z+150})
    end
    handlers.tpenemy=function(args,pc)
        local rows={}
        for _,o in ipairs(FindAllOf("DominionAICharacter") or {}) do
            if valid(o) then local n=o:GetFName():ToString();rows[#rows+1]={obj=o,name=n,display=o:GetClass():GetFName():ToString()} end
        end
        local row=unique(rows,C.join(args));local l=row.obj:K2_GetActorLocation();teleport(pc,{X=l.X+500,Y=l.Y,Z=l.Z+150})
    end
    local function boss(pc,query,keys)
        local found=find(landmarks(),query);local named={}
        for _,r in ipairs(found) do if r.target then named[#named+1]=r end end
        if #named>0 then found=named end
        if #found>1 then
            local entrances={};for _,r in ipairs(found) do if C.matches(r.name,"entrance") then entrances[#entrances+1]=r end end
            if #entrances==1 then found=entrances end
        end
        if #found~=1 then error("Boss destination is not unique/loaded. Use !landmarks "..query.." and !tp <exact destination>.",0) end
        local keyrows={}
        for _,name in ipairs(keys or {}) do keyrows[#keyrows+1]=unique(assets("ItemData","Name"),name) end
        for _,row in ipairs(keyrows) do if item_count(pc,row.obj)==0 and give(pc,row,1)==0 then error("No inventory room for the boss key: "..row.name,0) end end
        local l=found[1].location;teleport(pc,{X=l.X,Y=l.Y,Z=l.Z+150})
    end
    handlers.imaru=function(_,pc) boss(pc,"Imarus_Lair_Exit",{"Resources_SealBreakKey_Fall","Resources_SealBreakKey_Fort","Resources_SealBreakKey_Vil"}) end
    handlers.velgar=function(_,pc) boss(pc,"Dragons Lair Arena",{"Masterworks_Challenge_Horn"}) end
    handlers.fuzan=function(_,pc) boss(pc,"Fuzan_Arena") end
    handlers.kuldra=function(_,pc) boss(pc,"KuldraArena_Entrance") end
    handlers.heart=function(_,pc) boss(pc,"KuldraInteriorEntrance") end
    handlers.urns=function(_,pc)
        local progress=pc.ProgressComponent;local before=progress:GetUnlockedShrineCount();local count=0
        for _,l in ipairs(landmarks()) do
            if l.category==6 or l.category==7 then progress:UnlockShrine(l.guid);count=count+1 end
        end
        reply("Health urns: "..progress:GetUnlockedShrineCount().." unlocked (was "..before.."; "..count.." mapped urns checked).")
    end
    handlers.agilitygold=function(_,pc)
        local progress=pc.ProgressComponent;local scores={}
        progress.AgilityCourseCompletionTimes:ForEach(function(_,e)
            local s=e:get();scores[text(s.CourseID)]={medal=s.HighestUnlockedMedal,time=s.PersonalBestCompletionTime}
        end)
        local updated,total=0,0
        for _,course in ipairs(assets("AgilityCourseDataAsset")) do
            local id=text(course.obj.PersistenceID);local g=course.obj.TimeTrialData.GoldMedal.MedalTime
            local goldtime=((g.Days*24+g.Hours)*60+g.Minutes)*60+g.Seconds
            if id=="" or goldtime<=0 then error("Invalid agility course metadata: "..course.name,0) end
            total=total+1
            if not scores[id] or scores[id].medal<3 then
                local best=math.max(0.1,goldtime-0.5)
                if scores[id] and scores[id].time>0 then best=math.min(best,scores[id].time) end
                progress:Client_UpdateAgilityCourseHighScore({CourseID=id,HighestUnlockedMedal=3,PersonalBestCompletionTime=best})
                updated=updated+1
            end
        end
        reply("Agility gold: "..total.." courses checked; "..updated.." updated. Existing gold times were preserved.")
    end
    handlers.resend=function(_,pc)
        if not valid(pc.ReplicationStream) then error("No structure replication stream exists in this solo session.",0) end
        pc.ReplicationStream:OnPlayerControllerReady();reply("Requested a fresh structure replication stream for your player.")
    end
    handlers.pvpme=function(args,pc)
        local enabled=C.toggle(args[1],state.pvp)
        local found=false
        for _,component in ipairs(FindAllOf("PlayerDamageComponent") or {}) do
            if valid(component) and component:GetOwner()==pawn(pc) then
                component.bIsPvpEnabled=enabled;component:OnRep_bIsPvpEnabled();found=true
            end
        end
        if not found then error("Your player damage component is not ready.",0) end
        state.pvp=enabled;reply("Your PvP flag "..(enabled and "on" or "off")..". Solo worlds have no opponent.")
    end
    handlers.duel=function(args)
        if args[1] and args[1]:lower()=="off" then state.duel=nil;reply("No active duel.");return end
        error("A duel requires another consenting player. This mod is configured for your solo world.",0)
    end
    handlers.achievements=function(_,pc)
        local names=require("achievements")
        local router=pc:GetDomAchievementRouter()
        if not valid(router) then error("This platform has no active game achievement router.",0) end
        local jobs={}
        for _,name in ipairs(names) do
            jobs[#jobs+1]=function() router:Client_UnlockAchievement(name) end
        end
        enqueue("Submit platform achievement requests",jobs)
        reply("These are requests to the game's achievement service. Acceptance depends on your platform; account unlocks cannot be verified here.")
    end
    handlers.status = function()
        reply("EndCrates-DragonWilds-Maxer-Mod 1.0. God mode="..tostring(state.god==true).."; queued operations="..#state.queue.."; temporary unlock-all="..tostring(state.unlockall==true)..". Solo host commands only.")
    end
    local API={}
    function API.run(line,context)
        local parsed,why=C.parse(line); if not parsed then reply(why); return end
        local name,args=parsed.name,parsed.args
        local tier=name:match("^geartier(%d+)$")
        if tier then name="preset"; args={tier} end
        local fn=handlers[name]
        if not fn then reply("Command is not ready: !"..name..". Type !help for the command list."); return end
        local ok,result=pcall(function()
            local needs_player=not (name=="help" or name=="more" or name=="status" or name=="cancel")
            local pc=nil
            if needs_player then pc=mypc(context) end
            return fn(args,pc)
        end)
        if not ok then reply(tostring(result)) end
    end
    function API.tick()
        if not state.chat_ready then
            local ok,pc=pcall(mypc)
            if ok and valid(pc.Pawn) then
                local supported,enabled=pcall(function()return pc:IsChatEnabled()end)
                if supported then
                    state.original_chat=enabled
                    if not enabled then cheat(pc,"domEnableChat",true) end
                end
                state.chat_ready=true
            end
        end
        if #state.queue>0 then
            local ok,pc=pcall(mypc)
            if not ok or pc~=state.queue_pc or not valid(pc.Pawn) then
                state.queue={};reply("Bulk command cancelled because the player or world changed.");return
            end
        end
        for _=1,3 do
            local job=table.remove(state.queue,1); if not job then break end
            local ok,why=pcall(job)
            state.queue_done=state.queue_done+1
            if not ok then state.queue_failed=state.queue_failed+1; reply("Bulk operation skipped: "..tostring(why)) end
            if #state.queue==0 then reply(state.queue_label.." finished: "..state.queue_done.." operations; failures="..state.queue_failed) end
        end
    end
    API.handlers=handlers
    return API
end
