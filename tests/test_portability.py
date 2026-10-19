from pathlib import Path
import shutil
import tempfile
import unittest

from lupa.lua54 import LuaRuntime


class PortabilityTests(unittest.TestCase):
    def test_entry_point_loads_from_another_directory(self):
        source = Path(__file__).resolve().parents[1] / 'Mods' / 'EndCrates-DragonWilds-Maxer-Mod' / 'Scripts'
        with tempfile.TemporaryDirectory(prefix='mod install ') as temporary:
            scripts = Path(temporary) / 'Renamed Folder' / 'Scripts'
            shutil.copytree(source, scripts)
            lua = LuaRuntime(unpack_returned_tuples=True)
            lua.globals().module_search_path = scripts.as_posix() + '/?.lua'
            lua.execute('''
                package.path = module_search_path
                messages, hooks = {}, {}
                function print(message) messages[#messages + 1] = message end
                function FindAllOf() return {} end
                function RegisterHook(name, pre, post) hooks[name] = {pre=pre, post=post} end
                function LoopAsync(_, callback) tick = callback end
                function ExecuteInGameThread(callback) callback() end
                function FText(text) return {ToString=function() return text end} end
                require('main')
                tick()
                local widget = {MessageSendBox={SetText=function() end}}
                local context = {get=function() return widget end}
                local text = {get=function() return FText('!help') end, set=function() end}
                local commit = {get=function() return 1 end, set=function() end}
                hooks['/Script/Dominion.OpenedChatSubWidget:OnTextCommitted'].pre(context, text, commit)
            ''')
            messages = list(lua.globals().messages.values())
            self.assertTrue(any('!give <item>' in message for message in messages))
            self.assertFalse(any('failed:' in message or 'stopped:' in message for message in messages))


if __name__ == '__main__':
    unittest.main()
