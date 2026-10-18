# G1R Cheat Menu (THIS MOD HAS BEEN MADE WITH CLAUDE)

A Cheat menu for **Gothic 1 Remake**, written as a UE4SS Lua mod.

Deutsche Fassung: [README.de.md](README.de.md)

Press **F7** in-game to open it. The menu is an overlay: it does not pause the game, does not
capture the mouse, and is controlled with the keyboard only.

## Features

| Page | What it does |
|---|---|
| Player | God mode, infinite mana / stamina / breath, restore health-mana-stamina, clear crimes |
| Stats | Strength, dexterity, max mana, max health, learning points, level, experience |
| Faction | Switch between the 12 guilds of the Old Camp, New Camp and Swamp Camp, or leave your faction |
| Skills | Learn or remove 58 skills |
| Items | Ore, lockpicks, potions, ammunition, torches, permanent elixirs, and submenus with 26 runes and 43 spell scrolls |
| Teleport | Jump to 28 places in the colony, or save up to 10 positions of your own and return to them |
| World | Time of day, freeze time, weather, game speed, story chapter |
| NPCs | Kill hostile NPCs, make loaded NPCs friendly |
| Achievements | Unlock single achievements or all 42 at once |

## Languages

The menu is available in English, German, French, Italian, Spanish, Brazilian Portuguese,
Polish and Russian. It follows the game's display language and checks it every time the menu
opens, so a change in the game's settings is picked up without a restart.

To fix the language yourself, set `language` in `Scripts\config.lua` to `"en"`, `"de"`, `"fr"`,
`"it"`, `"es"`, `"pt"`, `"pl"` or `"ru"`.

The texts of each language are in `Scripts\lang_<code>.lua`. Camp names and the wording of the
achievement entries follow the game's own texts. Other game terms (guild ranks, spells,
talents, places) are translated freely and may differ from what the game calls them.
Corrections are welcome; a text that is missing in a language file is shown in English.

## Requirements

- Gothic 1 Remake (Steam, Windows)
- UE4SS for Gothic 1 Remake. Developed against the AngelScript-fix build
  ("G1R UE4SS" on Nexus Mods, version 0.4). Other UE4SS builds are untested.

## Installation

1. Install UE4SS for Gothic 1 Remake if you have not already. After that this folder exists:
   `<game folder>\G1R\Binaries\Win64\ue4ss\Mods`
2. Copy the `G1R_CheatMenu` folder from this repository into that `Mods` folder. The result
   must look like this:

   ```
   ue4ss\Mods\G1R_CheatMenu\enabled.txt
   ue4ss\Mods\G1R_CheatMenu\Scripts\main.lua
   ue4ss\Mods\G1R_CheatMenu\Scripts\config.lua
   ue4ss\Mods\G1R_CheatMenu\Scripts\lang_de.lua   (and the other lang_*.lua files)
   ue4ss\Mods\G1R_CheatMenu\Assets\panel.png
   ```
3. Start the game and load a save. Press **F7**.

`enabled.txt` is what switches the mod on, so nothing has to be added to `mods.txt`.
To uninstall, delete the `G1R_CheatMenu` folder.

If the menu does not appear, open `ue4ss\UE4SS.log` and look for lines tagged
`[G1R_CheatMenu]`. A line `Loaded 1.6.0: toggle key F7` means the mod was started.

## Controls

| Key | Action |
|---|---|
| F7 | Open / close the menu |
| Up / Down, Numpad 8 / 2 | Move the selection (hold to keep moving) |
| Left / Right, Numpad 4 / 6 | Change a value (Left removes a skill or a saved position) |
| Enter, Numpad 5 | Open a page, run a cheat, switch on / off |
| Backspace, Numpad `.` | Back to the previous page |

Keys, key repeat, the language, menu position and size, the background and the pause after a teleport can
be changed in `Scripts\config.lua`. Key changes need a game restart. The game still receives
the keys you press while the menu is open.

## Read before using

- **Make a manual save first.** Faction and chapter changes set the value directly. They do
  not play the joining dialogue, hand out rewards or fire quest triggers.
- **Achievement unlocks are permanent** on your Steam account. The menu cannot lock them again.
- Switches such as god mode last until you turn them off or quit the game. They are not
  stored in the save.
- **Teleporting:** after a long jump the hero floats for about three seconds while the area
  loads, then drops to the ground. If you fall through the world on arrival, raise
  `teleportHoldSeconds` in `config.lua`. Some destinations are dangerous or belong to later
  chapters (orc town, Sleeper temple), so save first.
- Saved positions are kept in `saved_positions.txt` in the mod folder.
- A game patch can break the mod, because it calls game functions by name.

## Status

All pages were tested in-game on the Steam version with the UE4SS build named above, and the
menu was seen switching to each of the eight languages. The translations other than German
were checked for completeness but have not been proofread by native speakers. If something
does not work for you, please report it together with the `[G1R_CheatMenu]` lines from
`UE4SS.log`.

## Credits

All game functions, classes and ids the mod uses are declared in the game's own files and
were checked against them. I first found many of them by studying the **G1R Console Tools**
mod, and learned how to build a UMG overlay from Lua on this game from the **MapFastTravel**
("Fast Travel From Map") mod. Thanks to both authors. Neither mod is required or included,
and no files from them are part of this mod.

The teleport destinations are standing points from the game's own map data
(`G1R\Script\Map\MainMap\InteractionSpots.json`). The menu background, `Assets\panel.png`, was
generated for this mod.

## License

The mod is released under the MIT License, see [LICENSE](LICENSE). Gothic 1 Remake, its
