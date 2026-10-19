# EndCrates-DragonWilds-Maxer-Mod

Chat commands for RuneScape: Dragonwilds solo worlds. Spawn items, max skills, toggle god mode, teleport, manage quest progress, and request achievement unlocks from the game's native systems.

Includes an optional **Stacks9999** companion that raises existing stackable items to a limit of 9,999. Weapons and other single-instance equipment keep their original limits. Neither mod changes item weight.

## Quick start

Open in-game chat, enter a command, and press Enter:

```text
!help
!items dragon scimitar
!give Scimitar_Dragon 1
!maxskills
!god on
!landmarks lava fields
!tp lava fields
!agilitygold
```

Use `!god off` to turn god mode off. Use `!status` to check active modes and queued operations. The [command reference](docs/COMMANDS.md) covers every command, including quest controls, mounts, recipes, buildings, health urns, and achievements.

## Installation

Requires the Windows PC game and [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases). The command handlers were checked against Dragonwilds build CL 251392 / Unreal 5.6.1 using UE4SS `v3.0.1-1181-g83330635`. Other builds may need adjustments. UE4SS binaries and game assets are not included.

1. Close the game and back up your saves. On a normal Windows installation they are under `%LOCALAPPDATA%\RSDragonwilds\Saved`, including `SaveCharacters`, `SaveGames`, and `AccountConfig`.
2. Install a compatible UE4SS build according to its instructions. Find the game's `RSDragonwilds\Binaries\Win64\ue4ss\Mods` directory.
3. Download this repository with **Code → Download ZIP**, then extract it.
4. Copy `Mods/EndCrates-DragonWilds-Maxer-Mod` into your UE4SS `Mods` directory. Copy `Mods/Stacks9999` there too if you want the stack-limit companion.
5. Enable the mod in UE4SS. For a `mods.txt` setup, add these entries to the existing file without removing other mods:

   ```text
   EndCrates-DragonWilds-Maxer-Mod : 1
   Stacks9999 : 1
   ```

   Omit the second entry if you did not install Stacks9999. If your loader also maintains `mods.json`, ensure the corresponding `mod_enabled` entries agree with `mods.txt`.
6. Keep `LICENSE` and `ThirdParty-LICENSE.txt` with your copy, launch the game, and enter your solo world. Type `!help`.

The final command path should be:

```text
ue4ss/Mods/EndCrates-DragonWilds-Maxer-Mod/Scripts/main.lua
```

For an earlier installation named `WorldCommands`, disable its entry before enabling this version. Run only one copy of the command mod to avoid duplicate hooks. An existing Stacks9999 installation can be kept.

## How it behaves

- Commands require a local player with authority over the world. Remote clients are refused.
- Chat messages beginning with `!` are handled locally; ordinary chat follows the game's normal path.
- Item names are searched dynamically. Ambiguous names and invalid counts are rejected.
- Bulk commands run gradually. `!cancel` stops remaining operations, and changing player/world cancels the queue.
- `!maxskills` preserves XP already above the level cap. `!agilitygold` preserves existing gold times.
- Items, XP, quest progress, unlocks, and achievement requests change only when their commands are entered. The mod enables local chat when necessary.
- Stacks9999 changes in-memory stack limits. It does not automatically fill inventory stacks or edit save files.

## Limits

Back up the world before changing quests. Resetting a quest record cannot reliably restore removed actors or rewind scripted world events. Numbered quest steps follow sorted objective keys rather than every quest's branching logic.

`!achievements` submits the 50 achievement IDs to the game's achievement router. Backend acceptance depends on the active platform service; account unlocks on Jagex Launcher are unverified. Local completion of the request queue is not proof of account unlocks.

The teleport list contains destinations from the current world and loaded actors. Creature searches cover loaded creatures only. Multiplayer duel challenges are unavailable in this solo release.

## Disable or remove

Close the game, disable the mod's entry in the loader, and remove its folder if desired. Disable Stacks9999 separately if installed. Removing the scripts does not undo items or progress already saved by the game. Restore a backup with the game closed to roll back those changes.

## Testing

See [testing and compatibility](docs/TESTING.md) for coverage, live checks, and known gaps.

```text
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p "test_*.py" -v
```

## Credits and license

MIT licensed. UObject access patterns include adaptations from [Dragonwilds Toolkit](https://github.com/MyNameIsGlooboo/Dragonwilds-Toolkit), by Glooboo. Its MIT notice is preserved in [ThirdParty-LICENSE.txt](ThirdParty-LICENSE.txt). Achievement identifiers come from the [public Steam achievement definitions](https://steamcommunity.com/stats/1374490/achievements/).

This is a community mod and is not affiliated with Jagex.
