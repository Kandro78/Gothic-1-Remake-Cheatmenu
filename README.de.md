# G1R Cheat Menu (DIESE MOD WURDE MIT CLAUDE ERSTELLT)

Ein Cheat-Menü für **Gothic 1 Remake**, gebaut auf dem offiziellen Mod-System des Spiels
(AngelScript), das mit Update 1.1 gekommen ist.

English version: [README.md](README.md)

Auch auf [Nexus Mods](https://www.nexusmods.com/gothic1remake/mods/661) und im
[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3829622912).

Im Spiel öffnet **F7** das Menü. Es liegt über dem Spiel: Es pausiert nicht, fängt die Maus
nicht ein und wird nur mit der Tastatur bedient.

> **Wichtig: UE4SS funktioniert nicht mehr.** Seit Update 1.1 startet das Spiel nicht, solange
> UE4SS installiert ist. Wer es noch hat (etwa von Version 1.9.0 dieses Menüs), löscht
> `dwmapi.dll` und den Ordner `ue4ss` in `G1R\Binaries\Win64`. Version 2.0.0 braucht kein UE4SS.

## Funktionen

| Seite | Was sie macht |
|---|---|
| Spieler | Gottmodus, unendlich Mana und Atem, Leben und Mana auffüllen, Verbrechen löschen, Fliegen (der Flugmodus des Spiels), Gegner mit einem Schlag töten, unzerbrechliche Dietriche, kein Fallschaden, unendlich Munition, für NPCs unsichtbar, sicherer Taschendiebstahl, Truhe oder Tür im Blick öffnen, Heldentempo, Sprunghöhe |
| Attribute | Stärke, Geschick, max. Mana, max. Leben, Lernpunkte, Stufe, Erfahrung, mit Schrittweite; Stärke, Geschick und max. Mana in einem Schritt auf 100 |
| Gilde | Zwischen den 12 Gilden von Altem Lager, Neuem Lager und Sumpflager wechseln oder die Gilde verlassen |
| Fertigkeiten | 58 Fertigkeiten lernen oder entfernen oder alle auf einmal lernen; kostenloses Lernen bei den Lehrern, alle Fertigkeiten zurücksetzen und die Lernpunkte zurückbekommen |
| Gegenstände | Erz, Dietriche, Tränke, Munition, Fackeln, permanente Elixiere und Untermenüs mit Runen, Spruchrollen, Nahkampf- und Fernkampfwaffen, Rüstungen, Karten, Jagdtrophäen, Schmiedematerial, Alchemiezutaten, Pflanzen, Schlüsseln und Questgegenständen (jeder einzeln oder alle auf einmal) |
| Teleport | Zu den Markierungen auf der Weltkarte, zu 105 Personen, zu 28 Orten der Kolonie, oder bis zu 10 eigene Positionen speichern und zu ihnen zurückkehren |
| Welt | Tageszeit, Zeit anhalten, Wetter, Spieltempo, Kapitel |
| NPCs | NPC im Blick heilen, töten oder wiederbeleben, 30 Arten von Kreaturen erschaffen, Altes Lager, Neues Lager oder Sumpflager freundlich machen, feindliche NPCs töten, geladene NPCs freundlich machen |
| Quests | Listet fehlgeschlagene und laufende Quests mit ihren Tagebuchnamen; eine als erledigt markieren oder eine fehlgeschlagene neu starten |
| Erfolge | Einzelne Erfolge oder alle 42 auf einmal freischalten |

## Cheat-Menü oder Marvin-Modus?

Update 1.1 hat auch das Entwickler-Cheatwerkzeug des Spiels freigegeben, den Marvin-Modus.
Wer ihn einschaltet, markiert den Spielstand, und das Spiel schaltet für diesen Spielstand
Erfolge und automatisches Speichern dauerhaft ab. Das Cheat-Menü schaltet den Marvin-Modus nie
ein und setzt diese Markierung nicht. Es hat außerdem Cheats, die dem Marvin-Modus fehlen
(Gegner mit einem Schlag töten, unendlich Mana, Atem und Munition, Gildenwechsel, kostenloses
Lernen und Zurücksetzen der Fertigkeiten, NPCs wiederbeleben, freundliche Lager, Teleport zu
Kartenmarkierungen und gespeicherten Positionen, Erfolge), und zeigt lesbare Namen statt
interner Codes.

## Sprachen

Englisch, Deutsch, Französisch, Italienisch, Spanisch, brasilianisches Portugiesisch, Polnisch
und Russisch. Das Menü folgt der Anzeigesprache des Spiels und übernimmt einen Wechsel ohne
Neustart.

Die Texte stehen in [translations/strings.json](translations/strings.json); `tools/gen-lang.py`
erzeugt daraus `Script/CheatMenu/Lang/CMLang_<code>.as`. Die Übersetzungen wurden mit KI
(Claude) geschrieben. Nur die deutschen Texte hat ein Muttersprachler geprüft. Lagernamen und
die Erfolgstexte folgen den Texten des Spiels; andere Begriffe können abweichen. Korrekturen
sind willkommen.

## Voraussetzungen

- Gothic 1 Remake (Steam, Windows) mit Update 1.1 oder neuer
- Sonst nichts. UE4SS darf **nicht** installiert sein.

## Installation

**Steam Workshop:** den
[Workshop-Eintrag](https://steamcommunity.com/sharedfiles/filedetails/?id=3829622912) abonnieren.

**Von Hand:** den Ordner `Kandro78-G1RCheatMenu` aus diesem Repository nach
`<Spielordner>\G1R\Mods` kopieren, sodass `G1R\Mods\Kandro78-G1RCheatMenu\GothicMod.json`
existiert. (Das Release-Zip auf Nexus hat schon den Aufbau `G1R\Mods\...`; einfach in den
Spielordner entpacken.)

Danach:

1. In Steam auf Spielen klicken und **Gothic 1 Remake Mod Management UI** wählen.
2. Darauf achten, dass **G1R Cheat Menu** angehakt ist, und **Start Game** klicken.
3. Einen Spielstand laden und **F7** drücken.

Ein Spielstand ohne die Mod zeigt beim Laden „This save was made with a different modlist“.
**Continue anyway** klicken; der Spielstand lädt normal.

Zum Entfernen die Mod in der Mod Management UI abhaken, das Abo beenden oder den Ordner
löschen. Was die Cheats in einem Spielstand geändert haben (Gegenstände, Attribute,
Fertigkeiten, Quests), bleibt.

## Steuerung

| Taste | Aktion |
|---|---|
| F7 | Menü öffnen / schließen |
| Hoch / Runter, Num 8 / 2 | Auswahl bewegen (gedrückt halten zum Weiterlaufen) |
| Bild hoch / Bild runter, Num 9 / 3 | Eine Seite weiter |
| Pos1 / Ende, Num 7 / 1 | Erster / letzter Eintrag |
| Enter, Num 5 | Seite öffnen, Cheat ausführen, an / aus |
| Links / Rechts, Num 4 / 6 | Wert ändern, aus / an; Rechts öffnet eine Seite, Links geht zurück (Links entfernt auch eine Fertigkeit oder gespeicherte Position) |
| Rücktaste | Zurück zur vorigen Seite |

Jede Seite merkt sich ihre Auswahl. Die Kopfzeile zeigt, wo man ist (etwa
Cheat Menu / Quests), und die Position in langen Listen.

## Vor dem Benutzen lesen

- **Vorher von Hand speichern.** Gilden- und Kapitelwechsel setzen den Wert direkt. Sie spielen
  keinen Aufnahmedialog ab, vergeben keine Belohnungen und lösen keine Quest-Auslöser aus.
- **Eine Quest abzuschließen ist endgültig** in diesem Spielstand. Das Spiel führt seine eigene Erfolgsbehandlung aus (Tagebuch, Erfahrung), aber keinen Dialog, der normalerweise dorthin führt.
- **Eine fehlgeschlagene Quest neu starten** setzt sie wieder auf laufend. Besteht der Grund für das Scheitern noch (etwa eine tote Figur), sagt das Menü das stattdessen.
- **Erfolge** werden dauerhaft im Steam-Konto freigeschaltet. Das Menü kann sie nicht wieder sperren. „Unlock ALL“ verlangt ein zweites Enter.
- Schalter wie der Gottmodus bleiben an, bis man sie abschaltet oder das Spiel beendet.
- Nach einem weiten Teleport schwebt der Held einige Sekunden, während das Gebiet lädt, und fällt dann auf den Boden. Manche Ziele sind gefährlich oder gehören zu späteren Kapiteln.
- **Kartenmarkierungen:** eine Markierung auf der Weltkarte setzen (nicht auf einer Lagerkarte), dann Teleport > Map markers öffnen. Eine Markierung auf einem Dach kann einen aufs Dach setzen.
- **Fliegen** ist der Flugmodus des Spiels und schaltet die Kollision ab. Vor dem Abschalten im Freien landen.
- **NPC wiederbeleben:** Der NPC lebt sofort wieder, aber der Körper bleibt liegen, bis das Gebiet neu lädt (weg- und zurückreisen).
- Gespeicherte Positionen liegen in einem eigenen Speicherplatz (`Kandro78-G1RCheatMenu-Positions`) und bleiben so über Spielstände hinweg erhalten. Mit 1.9.0 gespeicherte Positionen werden nicht übernommen.
- Nicht in 2.0.0: unendlich Ausdauer (die Skripte von 1.1 haben keinen Ausdauerwert) und die
  Einstellungen aus `config.lua` von 1.9.0.

## Entwicklung

- `Kandro78-G1RCheatMenu/` ist das Mod-Paket (`GothicMod.json`, `Script/CheatMenu/*.as`, `Preview.jpg`).
- `tools/deploy-mod.ps1` spiegelt es in den Ordner `G1R\Mods` des Spiels; `-Launch` startet das Spiel mit der Mod im AngelScript-Entwicklungsmodus (Hot Reload).
- `tools/extract-strings.py` listet neue oder unbenutzte Texte; `tools/gen-lang.py` baut die Sprachdateien aus `translations/strings.json`.

## Version 1.9.0 (UE4SS)

Der Ordner `G1R_CheatMenu` ist die alte UE4SS-Lua-Version 1.9.0. Sie läuft nur auf
Spielversionen vor Update 1.1 (Steam-Betazweig „previousrelease“) und braucht UE4SS. Sie bleibt
zum Nachschlagen erhalten und wird nicht mehr weiterentwickelt.

## Stand

Alle Seiten wurden im Spiel auf der Steam-Version mit Update 1.1 getestet, sowohl bei normalem
Start über die Mod Management UI als auch im Entwicklungsmodus.

## Danksagung

Gebaut auf dem offiziellen Mod-System und den lesbaren Spielskripten, die Alkimia Interactive
mit Update 1.1 ausliefert; die Befehle des Marvin-Modus zeigten, wie viele der Cheats
funktionieren. Die Versionen bis 1.9.0 haben die Funktionsnamen des Spiels aus der Mod
**G1R Console Tools** und die Lua-Overlay-Technik aus der Mod **MapFastTravel** („Fast Travel
From Map“) gelernt. Danke an alle. Keine Dateien anderer Mods sind Teil dieser Mod.

## Lizenz

Die Mod steht unter der MIT-Lizenz, siehe [LICENSE](LICENSE). Gothic 1 Remake, seine Namen und
Inhalte gehören ihren Eigentümern. Dies ist eine inoffizielle Modifikation. Sie wird nicht von
THQ Nordic erstellt, unterstützt oder befürwortet.
