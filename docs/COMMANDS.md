# Commands

## Items and vitals

| Command | Use |
|---|---|
| `!items dragon scimitar` | Search internal and displayed item names. |
| `!give Scimitar_Dragon 1` | Give an exact item. Counts must be 1–9999. |
| `!equip Club_AbyssalWhip` | Give one if needed, then request native equipping. |
| `!giveall rune 50` | Queue matching items, subject to inventory capacity. |
| `!preset 8 mage` | Native tier preset; knight, ranger, mage or generic. |
| `!geartier6` | Generic tier shortcut, tiers 1–10. |
| `!givequestitems [search]` | Queue quest/key items, one each. |
| `!heal`, `!refill` | Heal; or refill health, stamina, food, water and rest. |
| `!god on`, `!god off` | Native invulnerability and immortality. |
| `!attr damage` | Search actual player attributes. |
| `!attr <exact name> <value>` | Change that player's attribute. |
| `!damage 2` | Set the all-combat-styles damage multiplier. |

Deleted/deprecated game assets are excluded. Ambiguous names are rejected before spawning. The game decides whether an item fits in your inventory and whether it can be equipped. Stack limits of 9,999 are built into the mod for existing stackable items; weapons and armour keep their original limits.

## Skills and travel

| Command | Use |
|---|---|
| `!skills` | Current XP and levels. |
| `!xp mining 5000`, `!xp all 5000` | Add exact XP. |
| `!level mining 50`, `!level all 50` | Set XP using the game's current level curve. |
| `!maxskills` | Reach each skill's maximum, preserving existing excess XP. |
| `!where`, `!players` | Coordinates or players present. |
| `!landmarks lava fields` | Search this world's landmarks and named teleport targets. |
| `!tp Lava Fields` | Teleport to a unique destination. |
| `!tp <x> <y> <z>` | Teleport to Unreal coordinates using the game's loading-screen teleport path. |
| `!back` | Return to the previous teleport position. |
| `!grave`, `!grave list`, `!grave 2` | Your own latest, listed or numbered gravestone. |
| `!waypoint` | Teleport to your active map waypoint. |
| `!goto <player>` | Teleport your character near another player, if one is present. |
| `!tpenemy <name>` | Teleport near a currently loaded creature; ambiguous matches are rejected. |
| `!imaru` | Supply the three seal-break keys and go to the exterior lair portal. |
| `!velgar` | Supply a Challenge Horn and go to Dragons Lair Arena. |
| `!fuzan`, `!kuldra`, `!heart` | Named native boss destinations. |

Destination names come from the current world registry and loaded teleport targets. The engine can refuse a teleport that fails its destination checks.

## Unlocks and quests

| Command | Use |
|---|---|
| `!recipes [words]` | Permanently unlock all or matching crafting recipes. |
| `!buildings [words]` | Permanently unlock all or matching building pieces. |
| `!unlockall on`, `!unlockall off` | Temporary local unlock-query override. Off preserves recipes learned normally. Reopen the relevant menu after toggling. |
| `!unlockinfo` | Recipe/building counts and override status. |
| `!quests [search]` | List quests by internal and displayed names. |
| `!quest start <name>` | Give/start one quest. |
| `!quest complete <name>` | Complete one quest using its native completion function. |
| `!quest completeall` | Queue completion of all unfinished active game quest assets. |
| `!findstep <words>` | Search objective descriptions and hints. |
| `!queststep <quest> next` | Advance through naturally sorted named objective keys. |
| `!queststep <quest> <number>` | Select a numbered named objective. |
| `!questrestart <quest>` | Reset that character's quest state, flags and counters. |
| `!mounts`, `!mount <name>` | List mounts or unlock and equip one. |
| `!urns` | Unlock every health urn recorded in the world's landmark registry. |
| `!agilitygold` | Gold on the six game courses; preserve existing gold times. |
| `!achievements` | Queue requests for all 50 valid achievement IDs through the game's achievement router. |

Quest commands alter your character's quest records. They cannot reliably rewind world events, resurrect removed actors, or reconstruct a quest's scripted world state. Quest objective numbering follows sorted objective keys and cannot infer every branching quest's intended next step. Backups allow recovery if a scripted quest behaves differently after a manual change.

Achievement requests depend on the platform's active achievement service. Account acceptance on Jagex Launcher is unverified. A request completing locally is not proof of an account unlock. Achievement requests are never run automatically or during smoke tests.

## Other commands

`!resend` reinitializes your player's native building replication stream. `!pvpme on|off` changes only your player's PvP flag. The single-player configuration has no opponent, and multiplayer duel challenges are unavailable; `!duel off` clears any local duel state. Multiplayer server features are outside the scope of this release.

`!more` displays another page of the previous list. `!cancel` stops queued bulk operations. `!status` reports active modes. The game thread processes bulk operations gradually.

