# G1R Cheat Menu (THIS MOD HAS BEEN MADE WITH CLAUDE)

A cheat menu for **Gothic 1 Remake**, built on the game's official mod system (AngelScript)
that came with update 1.1.

Deutsche Fassung: [README.de.md](README.de.md)

Also on [Nexus Mods](https://www.nexusmods.com/gothic1remake/mods/661) and the
[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3829622912).

Press **F7** in-game to open it. The menu is an overlay: it does not pause the game, does not
capture the mouse, and is controlled with the keyboard only.

> **Important: UE4SS no longer works.** Since update 1.1 the game does not start while UE4SS is
> installed. If you have it (for example from version 1.9.0 of this menu), delete `dwmapi.dll`
> and the `ue4ss` folder in `G1R\Binaries\Win64`. Version 2.0.0 does not need UE4SS.

## Features

| Page | What it does |
|---|---|
| Player | God mode, infinite mana and breath, restore health and mana, clear crimes, fly (the game's own fly mode), one-hit kills, unbreakable lockpicks, no fall damage, infinite ammo, invisible to NPCs, sure pickpocketing, unlock the chest or door in view, hero speed, jump height |
| Stats | Strength, dexterity, max mana, max health, learning points, level, experience, with a step multiplier; strength, dexterity and max mana to 100 in one step |
| Faction | Switch between the 12 guilds of the Old Camp, New Camp and Swamp Camp, or leave your faction |
| Skills | Learn or remove 58 skills, or learn all of them at once; free training at the teachers, reset all skills and get the learning points back |
| Items | Ore, lockpicks, potions, ammunition, torches, permanent elixirs, and submenus with runes, spell scrolls, melee weapons, ranged weapons, armours, maps, animal trophies, smithing materials, alchemy ingredients, plants, keys and quest items (each item on its own or all at once) |
| Teleport | Jump to the markers you set on the world map, to 105 people, to 28 places in the colony, or save up to 10 positions of your own and return to them |
| World | Time of day, freeze time, weather, game speed, story chapter |
| NPCs | Heal, kill or revive the NPC in view, spawn 30 kinds of creatures, make the Old Camp, New Camp or Swamp Camp friendly, kill hostile NPCs, make loaded NPCs friendly |
| Quests | Lists your failed and running quests by their quest-log names; mark one as completed, or restart a failed one |
| Achievements | Unlock single achievements or all 42 at once |

## Cheat Menu or Marvin Mode?

Update 1.1 also opened up the game's own developer cheat tool, Marvin Mode. Switching it on
marks the save, and the game turns off achievements and autosave for that save for good. The
cheat menu never switches on Marvin Mode and does not set that mark. It also has cheats Marvin
Mode lacks (one-hit kills, infinite mana, breath and ammo, guild change, free training and
skill reset, reviving NPCs, friendly camps, teleport to map markers and saved positions,
achievements) and uses readable names instead of internal codes.

## Languages

English, German, French, Italian, Spanish, Brazilian Portuguese, Polish and Russian. The menu
follows the game's display language and picks up a change without a restart.

The texts are kept in [translations/strings.json](translations/strings.json);
`tools/gen-lang.py` turns them into `Script/CheatMenu/Lang/CMLang_<code>.as`. The translations
were written with AI (Claude). Only the German texts were checked by a German speaker. Camp
names and achievement wording follow the game's own texts; other game terms may differ.
Corrections are welcome.

## Requirements

- Gothic 1 Remake (Steam, Windows) with update 1.1 or later
- Nothing else. UE4SS must **not** be installed.

## Installation

**Steam Workshop:** subscribe to the
[workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3829622912).

**Manually:** copy the `Kandro78-G1RCheatMenu` folder from this repository into
`<game folder>\G1R\Mods`, so that `G1R\Mods\Kandro78-G1RCheatMenu\GothicMod.json` exists.
(The release zip on Nexus already has the `G1R\Mods\...` layout; extract it into the game
folder.)

Then:

1. In Steam, press Play and choose **Gothic 1 Remake Mod Management UI**.
2. Make sure **G1R Cheat Menu** is ticked and click **Start Game**.
3. Load a save and press **F7**.

Loading a save made without the mod shows "This save was made with a different modlist".
Click **Continue anyway**; the save loads normally.

To uninstall, untick the mod in the Mod Management UI, unsubscribe, or delete the folder.
What the cheats changed in a save (items, stats, skills, quests) stays.

## Controls

| Key | Action |
|---|---|
| F7 | Open / close the menu |
| Up / Down, Numpad 8 / 2 | Move the selection (hold to keep moving) |
| Page Up / Page Down, Numpad 9 / 3 | Move a page |
| Home / End, Numpad 7 / 1 | First / last entry |
| Enter, Numpad 5 | Open a page, run a cheat, switch on / off |
| Left / Right, Numpad 4 / 6 | Change a value, switch off / on; Right opens a page, Left goes back (Left also removes a skill or a saved position) |
| Backspace | Back to the previous page |

Each page remembers its selection. The header shows where you are (for example
Cheat Menu / Quests) and the position in long lists.

## Read before using

- **Make a manual save first.** Faction and chapter changes set the value directly. They do
  not play the joining dialogue, hand out rewards or fire quest triggers.
- **Completing a quest is permanent** in that save. The game runs its own success handling (quest log, experience), but no dialogue that would normally lead up to it.
- **Restarting a failed quest** sets it running again. If the reason it failed still holds (for example a character is dead), the menu says so instead.
- **Achievements** are unlocked permanently on your Steam account. The menu cannot lock them again. "Unlock ALL" asks for a second Enter.
- Switches such as god mode last until you turn them off or quit the game.
- After a long-distance teleport the hero floats for a few seconds while the area loads, then drops to the ground. Some destinations are dangerous or belong to later chapters.
- **Map markers:** set a marker on the world map (not a camp map), then open Teleport > Map markers. A marker on a roof can put you on the roof.
- **Fly** is the game's own fly mode and switches off collision. Land in the open before switching it off.
- **Reviving an NPC:** the NPC is alive again at once, but the body stays on the ground until the area reloads (travel away and back).
- Saved positions are kept in their own save slot (`Kandro78-G1RCheatMenu-Positions`), so they last across games. Positions saved with 1.9.0 are not carried over.
- Not in 2.0.0: infinite stamina (the 1.1 game scripts have no stamina value) and the
  `config.lua` settings of 1.9.0.

## Development

- `Kandro78-G1RCheatMenu/` is the mod package (`GothicMod.json`, `Script/CheatMenu/*.as`, `Preview.jpg`).
- `tools/deploy-mod.ps1` mirrors it into the game's `G1R\Mods` folder; `-Launch` starts the game with the mod and AngelScript development mode (hot reload).
- `tools/extract-strings.py` lists new or unused texts; `tools/gen-lang.py` builds the language files from `translations/strings.json`.

## Version 1.9.0 (UE4SS)

The `G1R_CheatMenu` folder is the old UE4SS Lua version 1.9.0. It only works on game versions
before update 1.1 (Steam beta branch "previousrelease") and needs UE4SS. It is kept for
reference and is no longer developed.

## Status

All pages were tested in-game on the Steam version with update 1.1, both with a normal launch
from the Mod Management UI and in development mode.

## Credits

Built on the official mod system and the readable game scripts that Alkimia Interactive ships
with update 1.1; the game's own Marvin Mode commands showed how many of the cheats work.
Versions up to 1.9.0 learned the game function names from the **G1R Console Tools** mod and
the Lua overlay technique from the **MapFastTravel** ("Fast Travel From Map") mod. Thanks to
all of them. No files from other mods are part of this mod.

## License

The mod is released under the MIT License, see [LICENSE](LICENSE). Gothic 1 Remake, its names
and assets belong to their owners. This is an unofficial modification. It is not made,
endorsed or supported by THQ Nordic.
