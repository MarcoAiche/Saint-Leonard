# Saint-Leonard: Zusammenfassung bisher

Das Spiel heißt seit 2026-11-24 **Saint-Leonard** (vorher Arbeitstitel „Riegersdorf City“). Repo: https://github.com/MarcoAiche/Saint-Leonard (privat).

Kontext für einen neuen Claude-Code-Chat (native Windows-Session statt WSL).

## Idee
Ein Multiplayer-Simulator für Marco und seine Freunde, in dem sie gemeinsam in einem Nachbau ihres Dorfes **Riegersdorf (Kärnten)** spielen.

## Getroffene Entscheidungen
- **Engine: Godot 4** (aktuelle stabile Version), läuft **nativ unter Windows**, nicht in WSL.
  - Begründung: Szenen und Skripte sind Textdateien, Claude kann also alles direkt schreiben. Ein echtes Spielgefühl ist möglich (Physik, Fahrzeuge, installierbare .exe).
  - Verworfen: Unity und Unreal (zu editorlastig, Binärdateien, für das Projekt übertrieben). Browser mit Three.js wäre die Alternative gewesen, Marco hat sich für Godot entschieden.
- **Sprache: GDScript** (schlank, kein .NET-Setup nötig. C# wäre möglich, macht Export und Multiplayer aber umständlicher).
- **Multiplayer:** eingebautes Godot-Networking (ENet / MultiplayerAPI). Einer hostet, die anderen verbinden sich per ZeroTier oder über einen eigenen Server auf Marcos Raspberry Pi im Homelab.

## Plan für den Nachbau des Dorfes
- **Straßen, Gebäudegrundrisse, Bach, Bahnlinie:** aus OpenStreetMap, automatisch in 3D umgewandelt (grobe Höhen und Dachformen).
- **Gelände:** offenes Höhenmodell (DGM, 1 m) von Kärnten (KAGIS) bzw. data.gv.at.
- **Bodentexturen:** Orthofotos von basemap.at.
- **Details:** wichtige Gebäude (Feuerwehrhaus, Kirche, Gasthaus usw.) werden später von Hand nachgearbeitet, mit Marcos Fotos als Vorlage.

## Spielinhalt (entschieden 2026-11-24)
- Herumlaufen und herumfahren
- Feuerwehr-Simulator
- Rollenspiel (RP)
- Das Gasthaus in Riegersdorf 1 (Details noch offen)

## Aktueller Stand (2026-11-24)
- Projektordner: `D:\Library\Documents\Code-Win\Riegersdorf City`
- Godot 4.7.2 per winget installiert (Konsolen-Exe unter `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.2-stable_win64_console.exe`).
- Godot-Projekt angelegt: `project.godot`, `scenes/main.tscn` (Himmel, Sonne, 200x200 m Testboden, Kamera), `icon.svg`, `.gitignore`. Headless-Import und Start laufen fehlerfrei.

## Welt aus echten Daten (2026-11-24)
- `tools/build_world_data.mjs` (Node.js, keine Pakete nötig) lädt OSM über die Overpass API (mit Ersatzservern) und Höhen als AWS-Terrain-Tiles (Terrarium, Zoom 15). Daraus wird `data/riegersdorf.json`: 1,8 × 1,8 km um den Ortskern (46.5491, 13.7806), Höhenraster 5 m, lokale Meter (x = Osten, z = Süden, y = Höhe über 510 m). Die Rohdaten liegen gecacht in `data/raw/`, `--refresh` lädt sie neu.
- `scripts/world/world_builder.gd` baut die Welt beim Start in ca. 0,7 s: Gelände mit Flächenfarben (Acker gestreift, Wald, Wiese), Straßen mit Rand und Mittellinie, Bahn mit Schwellen und Schienen, Bäche, 627 Gebäude (Satteldach auf rechteckigen Grundrissen, sonst Flachdach, Kirchen mit Turm), Wald als MultiMesh (Nadel- und Laubbäume) und Namensschilder (ausgeblendet ab 400 m).
- Look: Toon-Licht (`scripts/world/toon.gd`), Vertexfarben, dunkle Umrisslinie, kräftiger Himmel, leichter Nebel.
- Kollision: HeightMapShape fürs Gelände und Trimesh für die Gebäude.
- `scripts/free_camera.gd`: rechte Maustaste + Maus zum Umsehen, WASD, Q/E, Shift, Mausrad.
- `scripts/debug_tools.gd` (Autoload): `-- --shot=pfad.png --cam=x,y,z,yaw,pitch` speichert einen Screenshot.
- Gefundene Orte: Gasthaus Pirtscher (Riegersdorf 1) bei (-8, 61), FF Siebenbrünn-Riegersdorf bei (317, 40), Kapelle, Kirche Hl. Oswald, Mehrzweckhaus, Haltestelle Neuhaus an der Gail.
- Google Maps wird nicht verwendet: Die Nutzungsbedingungen verbieten es, Karten-, Satelliten- oder 3D-Daten herauszukopieren und in einem eigenen Spiel zu verwenden. Details kommen stattdessen von Marcos Fotos.

## Spielfigur, Auto und GUI (2026-11-24)
- `scripts/game.gd` (an `Main`): Start vor dem Gasthaus Pirtscher, das Auto parkt ein paar Meter weiter. Regelt Ein- und Aussteigen (F oder E, Abstand bis 3,8 m, Aussteigen erst unter 15 km/h), Pause, Ortsanzeige und ein Sicherheitsnetz gegen Durchfallen.
- `scripts/player/player.gd`: CharacterBody3D, läuft relativ zur Kamera (4,5 m/s, mit Shift 9 m/s), springt, Cartoon-Figur aus Grundformen mit Lauf- und Armschwung.
- `scripts/vehicles/car.gd`: VehicleBody3D (vorne ist +Z), Allrad, Tempo bis 130 km/h, Lenkung wird bei hohem Tempo schwächer, Handbremse, R stellt das Auto auf, H hupt (Ton wird im Code erzeugt).
- `scripts/camera_rig.gd`: Third-Person-Kamera mit SpringArm, Mausrad zoomt, im Auto schwenkt sie automatisch hinter das Fahrzeug.
- `scripts/ui/hud.gd` + `minimap.gd`: Ort und Straße oben links, Minimap oben rechts (Norden oben, Gasthaus orange, Feuerwehr rot), Steuerungshilfe (F1), Tacho im Auto, Hinweis "[F] Einsteigen", Pausemenü mit Esc.
- `scripts/controls.gd`: Tastenbelegung, wird im Code angelegt.
- Kollisionsebenen: 1 Welt, 2 Spieler, 3 (Wert 4) Fahrzeuge.
- Debug-Start: `-- --drive --hold=move_forward:2,move_left:1 --cam=yaw,pitch --shot=bild.png`.
- Straßen liegen nur noch 10 bis 12 cm über dem Gelände, `height_at` rechnet mit derselben Dreiecksaufteilung wie das Mesh.

## Große Karte, Grenze, Ton, schönere Häuser (2026-11-24)
Hinweis: Teile der beiden Abschnitte oben sind damit überholt (1,8-km-Ausschnitt, Bauzeit, `free_camera.gd`, Straßenhöhen).
- **Spielgrenze** nach Marcos Kartenbild (rote Linie von Neuhaus/Erlendorf bis Fürnitz/St. Job/Korpitsch, ca. 4,7 × 3,1 km). Umrechnung in `tools/map_border_fit.mjs` (13 Ortsbeschriftungen als Bezugspunkte, Genauigkeit ca. 100 bis 300 m), Ergebnis in `tools/map_border.json`. Im Spiel: rot-weiß gestreifte, halbtransparente Wand (wird erst in der Nähe sichtbar), unsichtbare Kollisionswände, Warnung in der Ortsanzeige, rote Linie auf Minimap und Karte.
- **Konverter** (`build_world_data.mjs`) erzeugt jetzt das Raster für Grenze + 400 m Rand (5 m, ca. 1,1 Mio Punkte, binär als base64), glättet das Gelände unter Straßen und Gleisen (geglättetes Längsprofil, seitlich auslaufend), bestimmt die Flächenart je Punkt (mit Löchern in Multipolygonen) und setzt 165.000 Bäume, aber nicht auf Straßen, Wegen, Gleisen, Bächen oder neben Häusern. Dazu kommt eine grobe Berglandschaft bis 9 km (Zoom 12) und 17 Ortsteile (place-Nodes).
- **Welt** wird in 250-m-Kacheln gebaut (Gelände, Straßen, Häuser, Bäume), der erste Bau dauert ca. 7,6 s und wird in `data/world_baked.scn` (ca. 48 MB) gespeichert. Danach lädt die Welt in ca. 0,8 s. Neu gebaut wird, wenn `riegersdorf.json` neuer ist, wenn sich `BUILD_VERSION` ändert oder mit dem Startparameter `-- --rebuild`.
- **Straßen sauberer:** erst alle Ränder, dann die Beläge nach Rang sortiert, runde Enden an Kreuzungen, Brücken mit eigener Kollision, Autobahn und Auffahrten dabei.
- **Häuser:** Sockel, Fenster mit Rahmen und Sprosse, bei manchen Häusern Fensterläden (grün, braun oder rot), Haustür, Holzbalkon mit Blumenkasten, Kamin, Dachüberstand mit Dachkante, Holzgiebel oder Walmdach; Garagen- und Scheunentore; Kirchturm mit Uhr. Fenster werden ab 700 m ausgeblendet.
- **Ruckeln:** Physik-Interpolation aktiv und 120 Physikschritte pro Sekunde; die Kamera folgt der interpolierten Lage (`get_global_transform_interpolated`).
- **Ton** (alles im Code erzeugt, `scripts/audio/`): Motor mit simulierten Gängen sowie Reifen- und Windrauschen (`engine_sound.gd`), Schritte, Autotür, Hupe, Klick für Menüs, Umgebung mit Wind und Vögeln als 12-s-Schleife (`sfx.gd`).
- **Karte** mit M oder Tab: ganze Spielwelt mit Ortsnamen, Gasthäusern (orange) und Feuerwehren (rot), außerhalb der Grenze abgedunkelt. Die Ortsanzeige zeigt jetzt den nächsten Ortsteil.
- Debug-Parameter zusätzlich: `--player=x,z`, `--dist=m` (Kameraabstand), `--map`.

## Nächste Schritte
1. Feuerwehrauto und Feuerwehrhaus (Einsätze).
2. Gasthaus Pirtscher begehbar machen.
3. Multiplayer-Grundgerüst (Host und Join, Spieler sehen sich gegenseitig).
