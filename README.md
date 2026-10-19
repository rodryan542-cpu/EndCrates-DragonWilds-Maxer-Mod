# EndCrates-DragonWilds-Maxer-Mod

A RuneScape: Dragonwilds mod for your solo world. Spawn items, set skills to 99, turn on god mode, teleport, and skip quest steps through in-game chat.

The 9,999 stack limit is built in. One mod folder, one entry in the loader.

## Install

Close the game first and back up `%LOCALAPPDATA%\RSDragonwilds\Saved`.

1. Install [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) for Dragonwilds.
2. Download this repo using **Code → Download ZIP** and extract it.
3. Copy `Mods/EndCrates-DragonWilds-Maxer-Mod` into the game's `ue4ss/Mods` folder.
4. Add this line to your existing `mods.txt`:

   ```text
   EndCrates-DragonWilds-Maxer-Mod : 1
   ```

   If you also use `mods.json`, enable the matching entry there.
5. Load your solo world, open chat, and type `!help`.

You should end up with this file:

```text
ue4ss/Mods/EndCrates-DragonWilds-Maxer-Mod/Scripts/main.lua
```

Upgrading from the earlier version? Disable `WorldCommands` and remove the separate `Stacks9999` mod. Both features are in this folder now.

## Commands

Type these straight into chat:

| Command | What it does |
| --- | --- |
| `!items dragon` | Find item names |
| `!give Scimitar_Dragon 1` | Give yourself a Dragon Scimitar |
| `!maxskills` | Raise all skills to their maximum |
| `!god on` / `!god off` | Toggle god mode |
| `!refill` | Restore health, stamina, food, water, and rest |
| `!landmarks lava fields` | Find a teleport destination |
| `!tp lava fields` | Teleport there |
| `!back` | Return to your previous teleport position |
| `!agilitygold` | Set gold medals on all six courses |
| `!givequestitems` | Give quest items and keys |
| `!unlockall` / `!unlockall off` | Toggle crafting and building unlocks |
| `!achievements` | Send achievement unlock requests to the game |
| `!cancel` | Stop a bulk command that's still running |

There's more in the [full command list](docs/COMMANDS.md), including individual skill levels, quest steps, mounts, urns, and gear presets.

## A few things to know

The stack limit applies to items that already stack. Weapons and armour keep their normal limits, and item weight stays the same. Existing stacks aren't filled automatically.

Quest skips can leave scripted events unfinished. Back up before using the quest commands; restarting a quest won't necessarily reset what happened in the world.

Achievement unlocks haven't been verified on Jagex Launcher. The command sends the requests, but the platform still has to accept them.

This is for solo worlds. Multiplayer duel challenges aren't included.

To remove the mod, close the game and disable its loader entry. Items and progress you've already saved will stay; restoring a save backup rolls those changes back.

Tested against Dragonwilds CL 251392 / Unreal 5.6.1 with UE4SS `v3.0.1-1181-g83330635`. See [testing notes](docs/TESTING.md) for what was checked and how to run the tests.

## Credits

Some game-object access code is adapted from Glooboo's [Dragonwilds Toolkit](https://github.com/MyNameIsGlooboo/Dragonwilds-Toolkit). Achievement names come from [Steam's public list](https://steamcommunity.com/stats/1374490/achievements/).

MIT licensed. Keep [LICENSE](LICENSE) and [ThirdParty-LICENSE.txt](ThirdParty-LICENSE.txt) with redistributed copies. This is a community mod, unaffiliated with Jagex.
