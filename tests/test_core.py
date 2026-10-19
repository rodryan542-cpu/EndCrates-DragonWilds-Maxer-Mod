from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / "Mods" / "EndCrates-DragonWilds-Maxer-Mod" / "Scripts"
from lupa.lua54 import LuaRuntime, LuaError


class CoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua = LuaRuntime(unpack_returned_tuples=True)
        cls.core = cls.lua.execute((ROOT / "core.lua").read_text(encoding="utf-8"))

    def args(self, *args):
        return self.lua.table_from(args)

    def test_command_names_and_spaces(self):
        parsed = self.core.parse("  !GiVe  Resources_Wood_Ash  100  ")
        self.assertEqual(parsed.name, "give")
        self.assertEqual(parsed.args[1], "Resources_Wood_Ash")
        self.assertEqual(parsed.args[2], "100")

    def test_quotes(self):
        parsed = self.core.parse('!tp "lava fields"')
        self.assertEqual(parsed.args[1], "lava fields")

    def test_reject_incomplete_quotes(self):
        self.assertIsNone(self.core.parse('!tp "lava fields')[0])

    def test_plain_chat_is_not_a_command(self):
        self.assertIsNone(self.core.parse("hello world")[0])

    def test_nonfinite_and_out_of_range_numbers(self):
        for value in ["nan", "inf", "1e309", "-1", "10000", "2.5", "abc"]:
            with self.subTest(value=value), self.assertRaises(LuaError):
                self.core.number(value, 1, 9999, True, "Count")

    def test_count_boundaries(self):
        self.assertEqual(self.core.number("1", 1, 9999, True, "Count"), 1)
        self.assertEqual(self.core.number("9999", 1, 9999, True, "Count"), 9999)

    def test_multiword_item_and_count(self):
        self.assertEqual(self.core.search_count(self.args("dragon", "shield", "50"), 1), ("dragon shield", 50))

    def test_item_name_with_number_is_not_count(self):
        self.assertEqual(self.core.search_count(self.args("123"), 1), ("123", 1))

    def test_empty_item_rejected(self):
        with self.assertRaises(LuaError):
            self.core.search_count(self.args(), 1)

    def test_matching_handles_internal_prefix(self):
        self.assertTrue(self.core.matches("ITEM_Scimitar_Dragon", "dragon scimitar"))
        self.assertFalse(self.core.matches("ITEM_Scimitar_Dragon", "rune scimitar"))

    def test_toggle_validation(self):
        self.assertTrue(self.core.toggle("on", False))
        self.assertFalse(self.core.toggle("off", True))
        self.assertTrue(self.core.toggle(None, False))
        with self.assertRaises(LuaError):
            self.core.toggle("maybe", False)

    def test_length_limit(self):
        self.assertIsNone(self.core.parse("!give " + "a" * 1001)[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
