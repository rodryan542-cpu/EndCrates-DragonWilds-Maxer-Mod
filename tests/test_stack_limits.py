from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime


SCRIPTS = Path(__file__).resolve().parents[1] / 'Mods' / 'EndCrates-DragonWilds-Maxer-Mod' / 'Scripts'

MOCKS = '''
    items, delayed, hooks, notifications, messages = {}, {}, {}, {}, {}
    function log(message) messages[#messages + 1] = message end
    function FindAllOf(name) assert(name == 'ItemData'); return items end
    function ExecuteWithDelay(_, callback) delayed[#delayed + 1] = callback end
    function ExecuteInGameThread(callback) callback() end
    function RegisterHook(name, callback) hooks[name] = callback end
    function NotifyOnNewObject(name, callback) notifications[name] = callback end
    function item(limit)
        return {MaxStackSize=limit, Weight=5, Quantity=7, IsValid=function() return true end}
    end
    function flush()
        while #delayed > 0 do table.remove(delayed, 1)() end
    end
'''


class StackLimitTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.start = self.lua.execute((SCRIPTS / 'stack_limits.lua').read_text(encoding='utf-8'))

    def test_limits_preserve_equipment_higher_limits_weight_and_quantities(self):
        self.lua.execute('items={item(50),item(1),item(20000),item(9999),item(0),item("invalid")}')
        self.start(self.lua.globals().log)
        self.lua.globals().flush()
        rows = self.lua.globals()['items']
        self.assertEqual([rows[i].MaxStackSize for i in range(1, 7)], [9999, 1, 20000, 9999, 0, 'invalid'])
        for row in rows.values():
            self.assertEqual(row.Weight, 5)
            self.assertEqual(row.Quantity, 7)

    def test_new_assets_are_patched_after_notification(self):
        self.start(self.lua.globals().log)
        self.lua.globals().flush()
        self.lua.execute("items={item(100)}; notifications['/Script/Dominion.ItemData']()")
        self.assertEqual(self.lua.globals()['items'][1].MaxStackSize, 100)
        self.lua.globals().flush()
        self.assertEqual(self.lua.globals()['items'][1].MaxStackSize, 9999)

    def test_many_notifications_share_one_pending_pass(self):
        self.start(self.lua.globals().log)
        self.lua.execute("for i=1,20 do notifications['/Script/Dominion.ItemData']() end")
        self.assertEqual(len(self.lua.globals().delayed), 1)
        self.lua.globals().flush()
        self.assertEqual(len(self.lua.globals().messages), 1)

    def test_world_restart_schedules_followup_pass(self):
        self.start(self.lua.globals().log)
        self.lua.globals().flush()
        self.lua.execute("items={item(10)}; hooks['/Script/Engine.PlayerController:ClientRestart']()")
        self.assertEqual(len(self.lua.globals().delayed), 2)
        self.lua.globals().flush()
        self.assertEqual(self.lua.globals()['items'][1].MaxStackSize, 9999)
        self.assertEqual(len(self.lua.globals().messages), 3)

    def test_bad_asset_does_not_stop_other_items(self):
        self.lua.execute('''
            items={setmetatable({IsValid=function() return true end}, {
                __index=function() error('unloaded item') end
            }), item(25)}
        ''')
        self.start(self.lua.globals().log)
        self.lua.globals().flush()
        self.assertEqual(self.lua.globals()['items'][2].MaxStackSize, 9999)
        self.assertIn('errors=1', self.lua.globals().messages[1])

    def test_missing_assets_are_handled_without_a_failure(self):
        self.lua.execute('FindAllOf=function() return nil end')
        self.start(self.lua.globals().log)
        self.lua.globals().flush()
        self.assertEqual(self.lua.globals().messages[1], 'No ItemData assets loaded yet.')


if __name__ == '__main__':
    unittest.main()
