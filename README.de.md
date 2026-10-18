# G1R Cheat-Menü (DIESE MOD WURDE MIT CLAUDE ERSTELLT)

Ein Cheat-Menü für **Gothic 1 Remake**, geschrieben als UE4SS-Lua-Mod.

English version: [README.md](README.md)

Mit **F7** wird es im Spiel geöffnet. Das Menü ist eine Einblendung: Es pausiert das Spiel
nicht, fängt die Maus nicht ein und wird nur mit der Tastatur bedient.

## Funktionen

| Seite | Was sie kann |
|---|---|
| Spieler | Gottmodus, unendlich Mana / Ausdauer / Atem, Leben-Mana-Ausdauer auffüllen, Verbrechen löschen |
| Werte | Stärke, Geschicklichkeit, max. Mana, max. Lebenspunkte, Lernpunkte, Stufe, Erfahrung |
| Gilde | Zwischen den 12 Gilden von Altem Lager, Neuem Lager und Sumpflager wechseln oder die Gilde verlassen |
| Talente | 58 Talente lernen oder entfernen |
| Gegenstände | Erz, Dietriche, Tränke, Munition, Fackeln, dauerhafte Elixiere sowie Untermenüs mit 26 Runen und 43 Zauberschriftrollen |
| Teleport | Zu 28 Orten in der Kolonie springen oder bis zu 10 eigene Positionen speichern und dorthin zurückkehren |
| Welt | Uhrzeit, Zeit anhalten, Wetter, Spieltempo, Kapitel |
| NPCs | Feindliche NPCs töten, geladene NPCs freundlich machen |
| Errungenschaften | Einzelne Errungenschaften oder alle 42 auf einmal freischalten |

## Sprachen

Das Menü gibt es auf Englisch, Deutsch, Französisch, Italienisch, Spanisch, brasilianischem
Portugiesisch, Polnisch und Russisch. Es richtet sich nach der Anzeigesprache des Spiels und
prüft sie bei jedem Öffnen, sodass ein Wechsel in den Spieleinstellungen ohne Neustart
übernommen wird.

Um die Sprache selbst festzulegen, setze `language` in `Scripts\config.lua` auf `"en"`, `"de"`,
`"fr"`, `"it"`, `"es"`, `"pt"`, `"pl"` oder `"ru"`.

Die Texte jeder Sprache stehen in `Scripts\lang_<Code>.lua`. Die Namen der Lager und die
Formulierungen der Errungenschaften folgen den Texten des Spiels. Andere Spielbegriffe
(Gildenränge, Zauber, Talente, Orte) sind frei übersetzt und können von den Bezeichnungen im
Spiel abweichen. Korrekturen sind willkommen; ein Text, der in einer Sprachdatei fehlt, wird
auf Englisch angezeigt.

## Voraussetzungen

- Gothic 1 Remake (Steam, Windows)
- UE4SS für Gothic 1 Remake. Entwickelt mit dem AngelScript-Fix-Build
  („G1R UE4SS“ auf Nexus Mods, Version 0.4). Andere UE4SS-Builds sind ungetestet.

## Installation

1. Installiere UE4SS für Gothic 1 Remake, falls noch nicht geschehen. Danach gibt es diesen
   Ordner: `<Spielordner>\G1R\Binaries\Win64\ue4ss\Mods`
2. Kopiere den Ordner `G1R_CheatMenu` aus diesem Repository in diesen `Mods`-Ordner. Das
   Ergebnis muss so aussehen:

   ```
   ue4ss\Mods\G1R_CheatMenu\enabled.txt
   ue4ss\Mods\G1R_CheatMenu\Scripts\main.lua
   ue4ss\Mods\G1R_CheatMenu\Scripts\config.lua
   ue4ss\Mods\G1R_CheatMenu\Scripts\lang_de.lua   (und die anderen lang_*.lua-Dateien)
   ue4ss\Mods\G1R_CheatMenu\Assets\panel.png
   ```
3. Starte das Spiel und lade einen Spielstand. Drücke **F7**.

`enabled.txt` schaltet die Mod ein, in `mods.txt` muss also nichts eingetragen werden.
Zum Deinstallieren den Ordner `G1R_CheatMenu` löschen.

Erscheint das Menü nicht, öffne `ue4ss\UE4SS.log` und suche nach Zeilen mit
`[G1R_CheatMenu]`. Die Zeile `Loaded 1.6.0: toggle key F7` bedeutet, dass die Mod gestartet
wurde.

## Steuerung

| Taste | Aktion |
|---|---|
| F7 | Menü öffnen / schließen |
| Hoch / Runter, Ziffernblock 8 / 2 | Auswahl bewegen (gedrückt halten zum Durchlaufen) |
| Links / Rechts, Ziffernblock 4 / 6 | Wert ändern (Links entfernt ein Talent oder eine gespeicherte Position) |
| Enter, Ziffernblock 5 | Seite öffnen, Cheat ausführen, an- / ausschalten |
| Rücktaste, Ziffernblock `,` | Zurück zur vorherigen Seite |

Tasten, Tastenwiederholung, Sprache, Position und Größe des Menüs, der Hintergrund und die Pause nach einem
Teleport lassen sich in `Scripts\config.lua` ändern. Geänderte Tasten gelten erst nach einem
Neustart des Spiels. Das Spiel erhält die gedrückten Tasten weiterhin, auch wenn das Menü
offen ist.

## Vor der Benutzung lesen

- **Speichere vorher manuell.** Gilden- und Kapitelwechsel setzen den Wert direkt. Sie spielen
  keinen Aufnahmedialog ab, vergeben keine Belohnungen und lösen keine Quest-Ereignisse aus.
- **Freigeschaltete Errungenschaften sind dauerhaft** auf deinem Steam-Konto. Das Menü kann sie
  nicht wieder sperren.
- Schalter wie der Gottmodus bleiben an, bis du sie ausschaltest oder das Spiel beendest. Sie
  werden nicht im Spielstand gespeichert.
- **Teleportieren:** Nach einem weiten Sprung schwebt der Held etwa drei Sekunden, während das
  Gebiet lädt, und fällt dann auf den Boden. Fällst du bei der Ankunft durch die Welt, erhöhe
  `teleportHoldSeconds` in `config.lua`. Manche Ziele sind gefährlich oder gehören zu späteren
  Kapiteln (Orkstadt, Schläfertempel), also vorher speichern.
- Gespeicherte Positionen liegen in `saved_positions.txt` im Mod-Ordner.
- Ein Spiel-Patch kann die Mod unbrauchbar machen, weil sie Spielfunktionen über ihren Namen
  aufruft.

## Stand

Alle Seiten wurden im Spiel mit der Steam-Version und dem oben genannten UE4SS-Build getestet,
und das Menü hat im Test auf jede der acht Sprachen umgeschaltet. Die Übersetzungen außer
Deutsch wurden auf Vollständigkeit geprüft, aber nicht von Muttersprachlern gegengelesen.
Funktioniert etwas bei dir nicht, melde es bitte zusammen mit den `[G1R_CheatMenu]`-Zeilen aus
`UE4SS.log`.

## Danksagung

Alle Spielfunktionen, Klassen und IDs, die die Mod verwendet, sind in den Dateien des Spiels
deklariert und wurden damit abgeglichen. Viele davon habe ich zuerst beim Studium der Mod
**G1R Console Tools** gefunden; wie man in diesem Spiel eine UMG-Einblendung aus Lua baut, habe
ich von der Mod **MapFastTravel** („Fast Travel From Map“) gelernt. Danke an beide Autoren.
Keine der beiden Mods wird benötigt oder ist enthalten, und keine ihrer Dateien ist Teil dieser
Mod.

Die Teleportziele sind Standpunkte aus den Kartendaten des Spiels
(`G1R\Script\Map\MainMap\InteractionSpots.json`). Der Menühintergrund, `Assets\panel.png`,
wurde für diese Mod erzeugt.

## Lizenz

Die Mod steht unter der MIT-Lizenz, siehe [LICENSE](LICENSE). Gothic 1 Remake, seine
