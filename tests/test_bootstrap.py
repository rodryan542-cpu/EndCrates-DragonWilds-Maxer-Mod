from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / "Mods" / "EndCrates-DragonWilds-Maxer-Mod" / "Scripts"
from lupa.lua54 import LuaRuntime

MOCKS=r'''
hooks,dispatched,scheduled={}, {}, {}
function RegisterHook(name,pre,post) hooks[name]={pre=pre,post=post} end
function LoopAsync(_,fn) loop=fn end
function ExecuteInGameThread(fn) scheduled[#scheduled+1]=fn;fn() end
function FindAllOf() return {} end
function print() end
require=function(name)
 if name == 'stack_limits' then return function() end end
 return function()
   return {run=function(line)dispatched[#dispatched+1]=line end,tick=function()end}
 end
end
function FText(s) return {ToString=function()return s end} end
function ref(v) return {value=v,get=function(self)return self.value end,set=function(self,x)self.value=x end} end
widget={MessageSendBox={SetText=function(self,text)self.text=text:ToString() end}}
context=ref(widget)
function commit(line,kind)
 t,c=ref(FText(line)),ref(kind or 1)
 hooks['/Script/Dominion.OpenedChatSubWidget:OnTextCommitted'].pre(context,t,c)
end
'''

class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.lua.execute((ROOT/'main.lua').read_text(encoding='utf-8'))
        self.lua.globals().loop()

    def test_commands_are_consumed_once_before_native_send(self):
        self.lua.globals().commit('!help',1)
        self.assertEqual(len(self.lua.globals().dispatched),1)
        self.assertEqual(self.lua.globals().dispatched[1],'!help')
        self.assertEqual(self.lua.globals().c.value,0)
        self.assertEqual(self.lua.globals().t.value.ToString(),'')
        self.assertEqual(self.lua.globals().widget.MessageSendBox.text,'')

    def test_ordinary_chat_is_preserved(self):
        self.lua.globals().commit('hello',1)
        self.assertEqual(len(self.lua.globals().dispatched),0)
        self.assertEqual(self.lua.globals().c.value,1)
        self.assertEqual(self.lua.globals().t.value.ToString(),'hello')

    def test_focus_change_does_not_execute_command(self):
        self.lua.globals().commit('!give dragon 1',2)
        self.assertEqual(len(self.lua.globals().dispatched),0)

    def test_each_game_thread_dispatch_has_its_own_callback(self):
        self.lua.globals().loop()
        self.assertTrue(self.lua.eval('scheduled[1] ~= scheduled[2]'))

    def test_update_is_not_queued_twice_when_game_thread_is_busy(self):
        self.lua.execute('ExecuteInGameThread=function(fn) held=fn;held_count=(held_count or 0)+1 end')
        self.lua.globals().loop()
        self.lua.globals().loop()
        self.assertEqual(self.lua.globals().held_count,1)

if __name__=='__main__':
    unittest.main(verbosity=2)
