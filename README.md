# Saint-Leonard

Ein Simulator, in dem man mit Freunden durch einen Nachbau von Riegersdorf (Arnoldstein, Kärnten) läuft und fährt. Gebaut mit Godot 4 und GDScript, Cartoon-Look.

## Starten
1. Godot 4.7 installieren (`winget install GodotEngine.GodotEngine`).
2. Projekt in Godot öffnen und mit F5 starten.
3. Beim ersten Start wird die Welt aus `data/riegersdorf.json` gebaut (ca. 8 s) und in `data/world_baked.scn` gespeichert, danach lädt sie in ca. 1 s.

## Steuerung
WASD laufen oder fahren, Shift rennen, Leertaste springen oder Handbremse, F ein- und aussteigen, H hupen, R Auto aufstellen, M oder Tab Karte, F1 Hilfe, Esc Pause.

## Weltdaten neu erzeugen
`node tools/build_world_data.mjs` (Node.js, keine Pakete). Mit `--refresh` werden die Rohdaten neu geladen.

Mehr Details stehen in [ZUSAMMENFASSUNG.md](ZUSAMMENFASSUNG.md).

## Datenquellen
- Karte: © OpenStreetMap-Mitwirkende, Lizenz ODbL (https://www.openstreetmap.org/copyright)
- Höhen: Terrain Tiles auf AWS (Mapzen/Tilezen, u. a. aus SRTM und EU-DEM)
