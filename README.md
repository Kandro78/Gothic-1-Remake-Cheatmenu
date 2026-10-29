# G1R Cheat Menu (THIS MOD HAS BEEN MADE WITH CLAUDE)

A Cheat menu for **Gothic 1 Remake**, written as a UE4SS Lua mod.

Deutsche Fassung: [README.de.md](README.de.md)

Press **F7** in-game to open it. The menu is an overlay: it does not pause the game, does not
capture the mouse, and is controlled with the keyboard only.

## Features

| Page | What it does |
|---|---|
| Player | God mode, infinite mana / stamina / breath, restore health-mana-stamina, clear crimes, fly through walls and ground, one-hit kills, unbreakable lockpicks, no fall damage, infinite ammo, invisible to NPCs, sure pickpocketing, unlock the chest or door in view, hero speed, jump height |
| Stats | Strength, dexterity, max mana, max health, learning points, level, experience; strength, dexterity and max mana to 100 in one step |
| Faction | Switch between the 12 guilds of the Old Camp, New Camp and Swamp Camp, or leave your faction |
| Skills | Learn or remove 58 skills, or learn all of them at once; free training at the teachers, reset all skills and get the learning points back |
| Items | Ore, lockpicks, potions, ammunition, torches, permanent elixirs, and submenus with runes, spell scrolls, melee weapons, ranged weapons, armours, maps, animal trophies, smithing materials, alchemy ingredients, plants, keys and quest items (each item on its own or all at once) |
| Teleport | Jump to the markers you set on the world map, to 105 people, to 28 places in the colony, or save up to 10 positions of your own and return to them |
| World | Time of day, freeze time, weather, game speed, story chapter |
| NPCs | Heal, kill or revive the NPC in view, spawn 30 kinds of creatures, make the Old Camp, New Camp or Swamp Camp friendly, kill hostile NPCs, make loaded NPCs friendly |
| Quests | Lists your failed and running quests by their quest-log names; mark one as completed, or restart a failed one |

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
`[G1R_CheatMenu]`. A line `Loaded 1.9.0: toggle key F7` means the mod was started.

## Controls

| Key | Action |
|---|---|
| F7 | Open / close the menu |
| Up / Down, Numpad 8 / 2 | Move the selection (hold to keep moving) |
| Left / Right, Numpad 4 / 6 | Change a value (Left removes a skill or a saved position) |
| Enter, Numpad 5 | Open a page, run a cheat, switch on / off |
| Backspace, Numpad `.` | Back to the previous page |
| W / A / S / D, Page Up / Page Down | Fly (when switched on in the Player page): along the camera, sideways, straight up / down |

Keys, key repeat, the fly keys and speed, the language, menu position and size, the background and the pause after a teleport can
be changed in `Scripts\config.lua`. Key changes need a game restart. The game still receives
the keys you press while the menu is open.

## Read before using

- **Make a manual save first.** Faction and chapter changes set the value directly. They do
  not play the joining dialogue, hand out rewards or fire quest triggers.
- **Completing a quest is permanent** in that save. The game runs its own success handling (log entry, experience), but no dialogue that would normally lead up to it, so later story steps can still depend on that dialogue.
- **Restarting a failed quest** sets it running again. If the reason it failed still holds (for example a character is dead), the menu says so instead, because the game would fail it again at once.
- **Achievements** are unlocked permanently on your Steam account. The menu cannot lock them again.
- Switches such as god mode last until you turn them off or quit the game. They are not
  stored in the save.
- **Teleporting:** after a long jump the hero floats for about three seconds while the area
  loads, then drops to the ground. If you fall through the world on arrival, raise
  `teleportHoldSeconds` in `config.lua`. Some destinations are dangerous or belong to later
  chapters (orc town, Sleeper temple), so save first.
- **Map markers:** set a marker on the world map (not on a camp map), then open Teleport > Map markers. The list names each marker after the closest known place. The hero arrives on the highest walkable surface at the marker, except near a known place, where the floor at that place's height is used (so a marker in the New Camp leads into the cave, not onto the rock above it). A marker on a roof or a rock overhang can put you on top of it.
- **Fly** switches off collision: you pass through walls and the ground. Land in the open before switching it off.
- **One-hit kills** finishes hostile NPCs within 40 m as soon as they take damage. It can take half a second.
- **Free training** makes learning at the teachers cost no learning points and no ore while it is on. **Reset skills** refunds the learning points the skills normally cost, but not the ore paid for them.
- **Reviving an NPC:** the NPC is alive again at once, but the body stays on the ground until the area reloads (travel away and back). After that the NPC goes on with the daily routine and may be somewhere else. During testing the game crashed once right after a revive; this could not be reproduced, but save first.
- **Spawned creatures** appear about 6 m in front of you a moment after you pick them. They behave as they do in the wild.
- **People:** the hero is put next to the person if they are nearby, otherwise at their bed first and then next to them once the area has loaded.
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
