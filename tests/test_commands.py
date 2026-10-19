from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / "Mods" / "EndCrates-DragonWilds-Maxer-Mod" / "Scripts"
from lupa.lua54 import LuaRuntime

MOCKS = r'''
messages, calls, objects = {}, {}, {}
function object(name)
  return {name=name, IsValid=function() return true end,
    GetFName=function(self) return {ToString=function() return self.name end} end,
    GetFullName=function(self) return "ItemData /Game/Items/"..self.name.."."..self.name end}
end
function FindAllOf(name) return objects[name] or {} end
local a,b,c=object('ITEM_Scimitar_Dragon'),object('ITEM_Shield_Dragon'),object('ITEM_Resources_Wood_Ash')
for _,o in ipairs({a,b,c}) do o.Name={ToString=function() return o.name end} end
objects.ItemData={a,b,c}
inventory=object('Inventory'); inventory.amounts={}
function inventory:GetNumItemsByData(data) return self.amounts[data.name] or 0 end
function inventory:AddItemByData(data,count)
  calls[#calls+1]={'give',data.name,count}; self.amounts[data.name]=self:GetNumItemsByData(data)+count; return true
end
pc=object('Player'); pc.localplayer=true; pc.authority=true; pc.BP_Components_Inventory=inventory
function pc:IsLocalController() return self.localplayer end
function pc:HasAuthority() return self.authority end
pc.Pawn=object('Pawn')
function pc.Pawn:K2_GetActorLocation() return {X=100,Y=200,Z=300} end
function pc.Pawn:K2_GetActorRotation() return {Pitch=0,Yaw=0,Roll=0} end
function pc.Pawn:K2_TeleportTo(location) calls[#calls+1]={'tp',location.X,location.Y,location.Z}; return true end
function FName(value) return {ToString=function() return value end} end
function pc.Pawn:BP_TriggerDelayedTeleport(params)
  calls[#calls+1]={'tp',params.TargetLocation.X,params.TargetLocation.Y,params.TargetLocation.Z};return true
end
pc.CheatManager=object('CheatManager')
for _,name in ipairs({'domFullHeal','domFullyRestoreSurvivalUpkeep','domSetImmortal','domSetInvulnerable','domGetGearPreset','domEquipItem'}) do
  pc.CheatManager[name]=function(self,...) calls[#calls+1]={name,...} end
end
objects.PlayerController={pc}
function reply(message) messages[#messages+1]=message end
'''


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        core_chunk = self.lua.compile((ROOT / "core.lua").read_text(encoding="utf-8"))
        self.lua.globals().require = lambda _: core_chunk()
        factory = self.lua.execute((ROOT / "commands.lua").read_text(encoding="utf-8"))
        self.state = self.lua.table()
        self.api = factory(self.state, self.lua.globals().reply)
        self.state.probed = True

    def run_command(self, line):
        self.api.run(line)
        return [v for _,v in self.lua.globals().messages.items()]

    def call_count(self):
        return len(self.lua.globals().calls)

    def test_help_without_player(self):
        self.lua.execute('objects.PlayerController={}')
        self.assertIn("EndCrates-DragonWilds-Maxer-Mod", self.run_command("!help")[0])
        self.assertEqual(self.call_count(), 0)

    def test_exact_item_and_count(self):
        self.run_command("!give Scimitar_Dragon 9999")
        self.assertEqual(self.call_count(), 1)
        self.assertEqual(self.lua.globals().calls[1][3], 9999)

    def test_ambiguous_item_never_spawns(self):
        messages = self.run_command("!give dragon")
        self.assertIn("ambiguous", messages[-1])
        self.assertEqual(self.call_count(), 0)

    def test_invalid_counts_never_spawn(self):
        for count in ["-2", "0", "10000", "1.5", "1e309"]:
            with self.subTest(count=count):
                self.run_command("!give Scimitar_Dragon " + count)
                self.assertEqual(self.call_count(), 0)

    def test_remote_server_rejected(self):
        self.lua.globals().pc.authority = False
        self.assertIn("solo world", self.run_command("!give Scimitar_Dragon 1")[-1])
        self.assertEqual(self.call_count(), 0)

    def test_search_does_not_mutate(self):
        messages = self.run_command("!items dragon")
        self.assertIn("2 matches", messages[-1])
        self.assertEqual(self.call_count(), 0)

    def test_god_mode_toggles_exact_native_functions(self):
        self.run_command("!god on")
        self.assertTrue(self.state.god)
        self.run_command("!god off")
        self.assertFalse(self.state.god)
        calls = self.lua.globals().calls
        self.assertEqual(calls[1][1], "domSetInvulnerable")
        self.assertEqual(calls[4][2], False)

    def test_coordinate_teleport(self):
        self.run_command("!tp -100 200.5 300")
        self.assertEqual(self.lua.globals().calls[1][2], -100)
        self.assertEqual(self.lua.globals().calls[1][3], 200.5)

    def test_bulk_cancel(self):
        self.run_command("!giveall dragon 2")
        self.assertEqual(len(self.state.queue), 2)
        self.run_command("!cancel")
        self.api.tick()
        self.assertEqual(self.call_count(), 0)

    def test_unknown_commands_do_not_execute_cheats(self):
        self.run_command("!domCrashServer")
        self.assertEqual(self.call_count(), 0)

    def test_tier_alias(self):
        self.run_command("!geartier6")
        self.assertEqual(self.lua.globals().calls[1][1], "domGetGearPreset")
        self.assertEqual(self.lua.globals().calls[1][2], 6)

    def test_bulk_processing_finishes(self):
        self.run_command("!giveall dragon 2")
        self.api.tick()
        self.assertEqual(self.call_count(), 2)
        self.assertEqual(len(self.state.queue), 0)

    def mock_progress(self):
        self.lua.execute(r'''
function arr(rows)
  return {rows=rows,ForEach=function(self,callback)
    for i,value in ipairs(self.rows) do if callback(i,{get=function() return value end}) then break end end
  end}
end
local mining,wood=object('SKILL_Mining'),object('SKILL_Woodcutting')
mining.Name={ToString=function()return 'Mining' end};mining.MaxLevel=99
wood.Name={ToString=function()return 'Woodcutting' end};wood.MaxLevel=99
skill=object('SkillComponent');skill.Skills=arr({{SkillData=mining,CurrentXP=9000},{SkillData=wood,CurrentXP=100000}})
function pc:GetPlayerSkillComponent() return skill end
function skill:GetSkillLevel(data)
  for _,s in ipairs(self.Skills.rows) do if s.SkillData==data then return math.min(99,math.floor(s.CurrentXP/1000)+1) end end
end
function skill:GetTotalXPNeededForLevel(level) return (level-1)*1000 end
function skill:OnRep_Skills(old) calls[#calls+1]={'xp_notify',old[1].CurrentXP} end
progress=object('Progress');pc.ProgressComponent=progress
local course=object('DA_AgilityGymCourse1')
course.PersistenceID='course_1'
course.TimeTrialData={GoldMedal={MedalTime={Days=0,Hours=0,Minutes=0,Seconds=57}}}
objects.AgilityCourseDataAsset={course}
progress.AgilityCourseCompletionTimes=arr({{CourseID='course_1',HighestUnlockedMedal=3,PersonalBestCompletionTime=50}})
function progress:Client_UpdateAgilityCourseHighScore(data) calls[#calls+1]={'gold',data.CourseID,data.HighestUnlockedMedal,data.PersonalBestCompletionTime} end
''')

    def test_xp_adds_exactly_once_and_notifies(self):
        self.mock_progress()
        self.run_command('!xp mining 250')
        self.assertEqual(self.lua.globals().skill.Skills.rows[1].CurrentXP, 9250)
        self.assertEqual(self.call_count(), 1)

    def test_level_uses_game_xp_curve(self):
        self.mock_progress()
        self.run_command('!level mining 50')
        self.assertEqual(self.lua.globals().skill.Skills.rows[1].CurrentXP, 49000)

    def test_max_skills_preserves_excess_xp(self):
        self.mock_progress()
        self.run_command('!maxskills')
        self.assertEqual(self.lua.globals().skill.Skills.rows[1].CurrentXP, 98000)
        self.assertEqual(self.lua.globals().skill.Skills.rows[2].CurrentXP, 100000)

    def test_invalid_level_does_not_write(self):
        self.mock_progress()
        self.run_command('!level all 100')
        self.assertEqual(self.lua.globals().skill.Skills.rows[1].CurrentXP, 9000)
        self.assertEqual(self.call_count(), 0)

    def test_noop_xp_does_not_notify(self):
        self.mock_progress()
        self.run_command('!xp all 0')
        self.assertEqual(self.call_count(), 0)

    def test_existing_gold_score_is_not_changed(self):
        self.mock_progress()
        messages=self.run_command('!agilitygold')
        self.assertIn('0 updated', messages[-1])
        self.assertEqual(self.call_count(), 0)

    def test_gold_uses_correct_course_id_and_threshold(self):
        self.mock_progress()
        self.lua.execute("progress.AgilityCourseCompletionTimes=arr({})")
        self.run_command('!agilitygold')
        self.assertEqual(self.lua.globals().calls[1][1], 'gold')
        self.assertEqual(self.lua.globals().calls[1][2], 'course_1')
        self.assertEqual(self.lua.globals().calls[1][3], 3)
        self.assertEqual(self.lua.globals().calls[1][4], 56.5)

    def test_unlockall_off_preserves_persistent_unlocks(self):
        self.run_command('!unlockall on')
        self.assertTrue(self.state.unlockall)
        self.run_command('!unlockall off')
        self.assertFalse(self.state.unlockall)
        self.assertEqual(self.call_count(), 0)

    def test_achievement_requests_only_run_when_explicitly_typed(self):
        achievements_chunk=self.lua.compile((ROOT/'achievements.lua').read_text(encoding='utf-8'))
        core_chunk=self.lua.compile((ROOT/'core.lua').read_text(encoding='utf-8'))
        self.lua.globals().require=lambda name: achievements_chunk() if name == 'achievements' else core_chunk()
        self.lua.execute("router=object('Router'); function router:Client_UnlockAchievement(id) calls[#calls+1]={'achievement',id} end; function pc:GetDomAchievementRouter() return router end")
        self.api.tick()
        self.assertEqual(self.call_count(), 0)
        self.run_command('!achievements')
        self.assertEqual(self.call_count(), 0)
        self.assertEqual(len(self.state.queue), 50)
        for _ in range(17):
            self.api.tick()
        self.assertEqual(self.call_count(), 50)


if __name__ == "__main__":
    unittest.main(verbosity=2)
