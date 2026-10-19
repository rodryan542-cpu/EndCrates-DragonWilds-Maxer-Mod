# Testing and compatibility

The command implementation was tested on Windows PC with RuneScape: Dragonwilds CL 251392, Unreal 5.6.1, and UE4SS `v3.0.1-1181-g83330635` on 19 October 2026.

The release uses UE4SS's module search path and contains no machine-specific paths, save editors, development command files, or runtime data dumps. The portable entry point retains the chat hooks and callback scheduling used in the live-tested build; the development loader and diagnostic command were removed for distribution.

## Automated checks

The Lua 5.4 tests run through Lupa. They cover parsing, quoting, numeric bounds, ambiguous item rejection, local authority requirements, item counts, native call selection, bulk cancellation, XP updates, excess XP preservation, gold medal data, explicit achievement requests, chat interception, callback scheduling, and the built-in stack feature.

```text
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p "test_*.py" -v
```

These use mocked game objects. They check command behavior without launching the game or changing a save.

## Live checks

The command implementation was exercised in an owned solo world:

- `!help` and `!where` were entered through actual chat, with visible replies confirmed.
- Player, skill, item, landmark, quest, objective, mount, attribute, and unlock-count queries returned game data.
- Negative item counts were rejected before inventory changes.
- `!xp all 0` and `!maxskills` preserved already-maxed skills and excess XP.
- `!agilitygold` checked six existing gold results and preserved their times.
- God mode toggled on and off without command errors.
- The delayed-teleport function accepted the current position; a later query confirmed the same position.
- The stack-limit implementation inspected 1,545 item assets and reported zero errors before being incorporated into the main mod.

The distributed entry point was checked with the automated suite after its portable-module changes and stack integration. Stack tests check initial loading, late asset notifications, world restarts, repeated notifications, higher existing limits, equipment exclusions, and per-asset failures. The combined package has not been independently tested on every launcher, loader version, or game update.

## Coverage gaps

Permanent item grants, XP changes, quest changes, recipe/building unlocks, urn unlocks, mount changes, cross-region travel, PvP, and account achievement changes were not executed during the final live check. Their handlers use inspected native signatures; selected behavior is covered by automated tests. This does not establish compatibility with every quest script or platform backend.

If a game update breaks a command, include the game and UE4SS versions, exact command, and relevant UE4SS log lines in an issue. Remove account details and private save information before posting logs.
