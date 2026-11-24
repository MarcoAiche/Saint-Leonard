# Saint Leonard: Projektzusammenfassung

Stand: 2026-11-24. Diese Datei ist der Einstieg für neue Claude-Code-Chats (und für alle, die das Projekt übernehmen). Sie beschreibt Idee, Entscheidungen, Aufbau, alle Spielsysteme, Werkzeuge, Tests und offene Punkte.

## 1. Idee

**Saint Leonard** ist eine Koop-Sandbox für Marco und seine Freunde: jagen, Schnaps brennen, mit dem 4x4-Pickup über Feld- und Bergwege fahren, der Polizei ausweichen und gemeinsam das Gasthaus Pirtscher retten. Schauplatz ist ein Nachbau von Marcos Heimat in Kärnten (Gemeinde Arnoldstein), gebaut aus echten Kartendaten.

Vorlage sind zwei Dokumente von Marco: "Saint Leonard - Full Game Brief" (Spielidee, Karte, Systeme, 3 Stufen) und "Saint Leonard - Co-Dev Kickoff & Questions" (Zusammenarbeit mit einem Mitentwickler). Der frühere Arbeitstitel war "Riegersdorf City" mit Feuerwehr-Thema; das ist durch den Brief abgelöst.

## 2. Entscheidungen

| Thema | Entscheidung | Warum |
|---|---|---|
| Engine | **Godot 4.7.2**, nativ unter Windows | Szenen und Skripte sind Text (Claude kann alles schreiben, Git funktioniert), eingebautes Netzwerk, Headless-Server. Das Kickoff-Dokument wollte Unity; Marco hat sich für Godot entschieden. |
| Sprache | **GDScript** | schlank, kein .NET nötig |
| Look | Mischung aus Cartoon und semi-realistisch | Marcos Wahl: weiches Licht, natürlichere Farben, stilisierte Modelle, witzige Figuren |
| Karte | echte Daten (OpenStreetMap + Höhenmodell), Stadt an den Rand | Marcos Wahl: Saint Leonard (Heimatdorf) = Riegersdorf + St. Leonhard, Stadt = Fürnitz, Tankstelle = echte Eni bei Hart, Südberge Richtung Wurzenpass ergänzt |
| Google Maps | wird nicht verwendet | Nutzungsbedingungen verbieten das Übernehmen von Karten- und 3D-Daten. Marcos Kartenbild diente nur zum Abzeichnen der Spielgrenze. |
| Umfang | alles aus dem Brief, alle 3 Stufen | Marcos Wahl ("Alles") |
| Versionsverwaltung | GitHub, privates Repo `MarcoAiche/Saint-Leonard` | Commits mit `MarcoAiche@users.noreply.github.com` |
| Mehrspieler | Godot ENet, Host oder dedizierter Server | Hosting über ZeroTier oder Marcos Raspberry Pi |
| Assets | alles im Code erzeugt | Modelle, Geräusche, Symbole und erzeugte Radiomusik brauchen keine Dateien |

## 3. Projekt und Werkzeuge

- Projektordner: `D:\Library\Documents\Code-Win\Riegersdorf City` (der Ordnername ist historisch).
- Godot per winget installiert, Konsolen-Exe: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`. Desktop-Verknüpfung "Riegersdorf City (Godot)" öffnet den Editor.
- GitHub CLI per winget installiert und angemeldet (Konto MarcoAiche).
- Node.js für die Kartendaten (keine Pakete nötig).
- Projekteinstellungen (`project.godot`): Fenster 1600 × 900, MSAA 2×, 120 Physikschritte pro Sekunde mit Physik-Interpolation, Mikrofoneingang an (Sprachchat), Autoloads `GameState`, `Net`, `Voice`, `DebugTools`.

## 4. Kartendaten

`tools/build_world_data.mjs` erzeugt `data/riegersdorf.json` (ca. 18 MB):
- **Quellen:** OpenStreetMap über die Overpass API (mehrere Ersatzserver, gecacht in `data/raw/`) und AWS Terrain Tiles (Terrarium, Zoom 15; Berge rundherum Zoom 12 bis 9 km).
- **Koordinaten:** lokale Meter, x = Osten, z = Süden, y = Höhe über 498 m. Ursprung ist der OSM-Dorfpunkt Riegersdorf (46.5491278, 13.7806496).
- **Spielgrenze:** `tools/map_border.json`. Ursprünglich aus Marcos Kartenbild umgerechnet (`tools/map_border_fit.mjs`, 13 Ortsnamen als Bezugspunkte, Genauigkeit 100 bis 300 m), danach im Süden um die Berge erweitert. Raster = Grenze + 400 m Rand, 5 m Abstand, ca. 1100 × 1164 Punkte.
- **Vorverarbeitung:** Gelände unter Straßen und Gleisen geglättet; Flächenart je Rasterpunkt (Wiese, Acker, Wald, Wohngebiet ...); ca. 357.000 Bäume, aber nicht auf Straßen, Wegen, Gleisen, Bächen oder neben Häusern.
- **Inhalt:** 2595 Gebäude, 1251 Straßen (mit Art, Belag `surface` und `tracktype`), Bahn, Bäche, Flächen, Orte und Sehenswürdigkeiten.
- Aufruf: `node tools/build_world_data.mjs` (mit `--refresh` neu herunterladen). Für eine andere Grenze den Cache `data/raw/osm_world.json` löschen.

## 5. Welt im Spiel

`scripts/world/world_builder.gd` (Klasse `WorldBuilder`):
- baut Gelände in 250-m-Kacheln (HeightMapShape für die Kollision), Berge rundherum, Wasser, Straßen, Bahn, Häuser (Fenster, Läden, Türen, Balkone, Kamine, Kirchturm mit Uhr), Bäume als MultiMesh, Spielgrenze (gestreifte Wand mit Kollision) und Namensschilder.
- **Baken:** Das Ergebnis wird in `data/world_baked.scn` gespeichert (nicht im Git). Neu gebaut wird, wenn die JSON neuer ist, `BUILD_VERSION` (derzeit 5) sich ändert oder mit `-- --rebuild`.
- **Straßenklassen** (`road_info`): 1 Hauptstraße (Autobahn, Bundes-, Landesstraßen), 2 Dorfstraße, 3 Schotterweg (Feld- und Waldwege, unbefestigte Zufahrten), 4 Bergpfad (Grade 4/5 oder steiler als 14 %). Rand und Belag nutzen dieselbe Höhe, damit der Rand an Hängen nicht durchschaut.
- **Abfragen:** `height_at`, `road_info` (schnelles Raster), `trees_near`, `kind_at`, `slope_at`, `border_distance`, `nearest_poi`, `nearest_place`.
- `scripts/world/landmarks.gd` (Klasse `Landmarks`) setzt beim Start alle Spielorte auf die echte Karte: Gasthaus Pirtscher mit Wirt Sepp, Läden der Stadt auf echten großen Gebäuden in Fürnitz (Bauhaus, Supermarkt, Waffengeschäft, Fleischerei, Polizei) mit Schildern und Verkäufern, Tankstelle mit Dach, Zapfsäulen und Shop, Werkstatt in St. Leonhard, 10 Bauplätze an Dorfstraßen, Polizeikontrolle an der Hauptstraße ca. 650 m vor der Stadt, Startpunkt vor dem Gasthaus. Dazu `in_mountains` (Südberge) und `near_village`.
- `scripts/world/sky_cycle.gd`: Tag und Nacht (ein Tag = 24 Minuten), Sonne und Mond, Himmelsfarben, Wolken, Nebel (Morgennebel, leichter bei Regen), Regen mit Partikeln und Geräusch. Höhennebel und SSAO sind bewusst aus.

## 6. Spielsysteme

### Spielstand (`scripts/core/game_state.gd`, Autoload `GameState`)
Geld, Inventar (mit Rasterposition `inv_layout`), Magazin, Gesundheit, Ausdauer, Promille, Rauchzeit, Kleidung, Pickup (Lack, Umbauten, Sprit, Schaden), Haus, Möbel, Fotos, Geschichte, Nebenaufträge, Statistik. Gemeinsame Welt: Uhrzeit, Tag, Wetter, Nässe, aufgestellte Dinge, gekaufte Häuser, Polizeidruck. Speichern als JSON in `user://saves/<slot>.json` mit Metadaten (Titel, Spieler, Tag, Geld, Kapitel, Spielzeit), automatisch alle 90 s, beim Pausieren und Beenden. `list_saves`, `delete_save`, `new_slot_name`. Startausrüstung: Gewehr, 20 Patronen, Messer, Taschenlampe, Fernglas, Bier, Zigaretten, Wurstsemmeln, 600 €.

### Gegenstände (`scripts/core/items.gd`)
Katalog mit Preisen, Läden und Ankaufspreisen: Waffen und Ausrüstung, Getränke (Bier, Schnaps, Schwarzgebrannter), Zigaretten, Essen, Zutaten (Zucker, Hefe, Obst, Getreide), Aufstellbares (Brennkessel, Hochstand, Wildkamera, Feuerstelle), Möbel, Beute (Fleisch, Fell, Geweih, Keilerwaffen, Riesengeweih), Rezepte für die Werkbank (Trophäe, Lederjacke, Jägerhut mit Gamsbart, Grillfleisch), 10 Häuser (2.500 bis 35.000 €), 8 Werkstatt-Umbauten, 8 Lackierungen.

### Spielfigur und Waffen
- `scripts/player/player.gd`: Ego-Perspektive (V schaltet auf Third Person), laufen, rennen mit Ausdauer, ducken (leiser, schlechter zu sehen), springen, Hochstand, Wild tragen, Ohnmacht. Erzeugt Geräusche für die Tiere (Schritte, Husten).
- `scripts/player/character_model.gd`: Figur aus Grundformen mit großen Augen und Schnurrbart, Kappe, Jägerhut, Gamsbart, Lederjacke, Polizeiuniform; Animationen für Laufen, Zielen, Sitzen, Nachladen, Hand zum Mund, Umfallen.
- `scripts/weapons/weapon_hand.gd`: Repetierbüchse (5 Schuss, Schaden 120), Zielfernrohr 4x oder 8x, Fernglas, Taschenlampe. Waffenwechsel mit 1/2/3 oder Mausrad, Rückstoß, Zielwackeln (ruhiger mit Zigarette, geduckt, vom Hochstand; schlechter betrunken oder außer Atem), Mündungsfeuer. Animationen: Waffenwechsel, Repetieren, Nachladen (kippen, Kammer auf), Rauchen (Zigarette mit Glut, Rauchwolke), Trinken (Flasche), Essen. Die Wirkung tritt in der Mitte der Animation ein.
- `scripts/camera_rig.gd`: Ego- und Third-Person-Kamera, im Auto Ego-Sicht vom Sitz (Kabine ausgeblendet), Rückstoß, Wackeln bei Alkohol, Mausempfindlichkeit und Sichtfeld aus den Einstellungen.

### Wild (`scripts/animals/`)
- Arten: Reh (Böcke mit Geweih), Wildschwein (Keiler mit Waffen, greift an), Hase, Braunbär (nur Südberge, greift an), Riesenhirsch (Kapitel 3, tief in den Südbergen).
- KI: äsen, umherziehen, sichern, flüchten, angreifen. Hört Schüsse (900 m), Hupe, Husten, Schritte; sieht Spieler schlechter bei Nebel, Regen, Nacht, wenn man geduckt oder auf dem Hochstand ist. Meidet Dörfer, Wasser und die Grenze.
- Treffer: Kopf ×3, Blatt ×1,6, hinten ×0,6. Angeschossene Tiere bluten (Blutspur am Boden) und brechen zusammen. Trefferanzeige im Fadenkreuz (rot = tödlich).
- Kadaver (`carcass.gd`) fällt per Physik um, kann getragen (G), auf den Pickup geladen, mit Messer ausgenommen (F halten) oder ganz bei der Fleischerei verkauft werden.
- `animal_spawner.gd` hält rund um alle Spieler Wild bereit (mehr in der Dämmerung, Wildschweine nachts), entfernt weit entfernte Tiere.

### Fahrzeuge (`scripts/vehicles/`)
- `vehicle.gd`: Fahrphysik (VehicleBody3D, vorne = +Z), Haftung je Straßenklasse und Nässe (Matsch), Holpern auf Schotter und im Gelände, Aufprall-Erkennung, verzögerte und zitternde Lenkung bei Alkohol, Scheinwerfer, Aufstellen mit R (nur umgekippt oder festgefahren, 5 s Wartezeit).
- `truck.gd`: 4x4-Pickup mit Kabine, Ladefläche (4 Plätze), Sprit (70 l, ca. 2,5 l pro km), Schaden (Unfälle, Rasen über 60 km/h im Gelände; ab 50 % weniger Leistung, bei 100 % Motorschaden, Rauch), Umbauten mit eigenem Aussehen (Geländereifen, Höherlegung, Rammschutz, Dachscheinwerfer, Dachträger, Sportauspuff, Seilwinde, Unterfahrschutz, Lack). Ohne Spanngurte kann Ladung herunterfallen. Seilwinde (T) hakt am nächsten Baum oder Fahrzeug ein, W zieht. Sitzplätze für Fahrer, Beifahrer und zwei auf der Ladefläche.
- `scripts/audio/engine_sound.gd`: Motorgeräusch mit simulierten Gängen.
- `scripts/audio/radio.gd`: Autoradio (K). Echte Online-Sender über radio-browser.info (österreichische MP3-Streams, Kärntner Sender zuerst; gestreamt in 5-s-Stücken mit HTTPClient), zwei im Code erzeugte Sender (Volksmusik, Rock) und "Eigene Musik" aus `Dokumente/Saint Leonard/Musik`. Spotify ist nicht möglich (keine erlaubte Schnittstelle für Spiele).

### Polizei (`scripts/police/`)
- Streifenwagen (weiß-blau, Blaulicht, Sirene) fahren Routen über zusammenhängende Haupt- und selten Dorfstraßen; nie auf Feld- oder Bergwegen.
- Feste Kontrolle vor der Stadt hält jedes Fahrzeug an.
- Anhaltegründe: zu schnell (über 68 km/h im Ort, über 118 auf der Hauptstraße), Schlangenlinien (Alkohol), ohne Licht in der Nacht, Fahndung bei hohem Polizeidruck.
- Kontrolle: Alkotest (300 € unter 1,2 ‰, sonst 800 €), Durchsuchen (Schwarzgebrannter: 500 € und Beschlagnahme), Optionen kooperieren, bestechen (200 €, gelingt etwa jedes zweite Mal), rausreden (mit Jägerhut besser), abhauen.
- Verfolgung: abgehängt bei über 350 m für 10 s oder auf Feldwegen über 110 m für 6 s. Erwischt: Strafe plus 400 €.
- Einsätze bei Kesselexplosionen und Schüssen im Ort. Offene Strafen zahlt man bei der Polizei in der Stadt.

### Schnapsbrennen und Aufstellbares (`scripts/build/`)
- `placeables.gd`: Modelle und Regeln für Brennkessel (mindestens 350 m von Dörfern, Stadt und Tankstelle), Hochstand (besteigen mit F), Wildkamera (meldet vorbeiziehendes Wild ins Handy), Feuerstelle (Fleisch grillen, Licht, Knistern) und Möbel (nur im eigenen Haus; Bilder und Trophäen an die Wand).
- Brennkessel-Minispiel (`Menus.still`): Maische ansetzen (2 Zucker, 1 Hefe, 2 Obst oder 2 Getreide), Temperatur zwischen 78 und 92 °C halten. Über 100 °C (Getreide schon über 96 °C) explodiert der Kessel: Rauchsäule, Schaden, Polizeieinsatz. Ertrag 4 bis 6 Flaschen (Obst) oder 2 bis 4 (Getreide).
- `house_builder.gd`: begehbares Spielerhaus mit Tür zur Straße, Fenstern, Dach, Licht, Werkbank und Bett (schlafen bis 7 Uhr, heilt, macht nüchtern).

### Geschichte und Aufträge (`scripts/missions/missions.gd`)
- Kapitel 1 "Ankommen": mit Wirt Sepp reden, Reh erlegen und Fleisch verkaufen, Geländereifen einbauen, Haus kaufen (300 € Belohnung).
- Kapitel 2 "Der geheime Kessel": Kessel kaufen, Zutaten kaufen, Kessel im Wald aufstellen, 5 Flaschen brennen, 5 Flaschen bei Sepp abliefern (600 €).
- Kapitel 3 "Die Legende und das Fest": Riesenhirsch erlegen, Geweih für die Trophäenwand abgeben, 4 Festkisten mit dem Pickup bringen, nach 19 Uhr trotz Großrazzia zum Fest fahren (1.500 €, Fest mit Lichtern, Musik und Gästen).
- Nebenaufträge (3 Angebote pro Tag, höchstens 3 gleichzeitig): Bestellungen der Fleischerei, Bestellung von Sepp, Pannenhilfe mit Reservekanister, Festgefahrenen mit der Seilwinde helfen, Mutprobe der Tankstelle (Kiste in die Berge, nur über Feldwege).

### Oberfläche (`scripts/ui/`)
- `hud.gd`: Ort und Straßenklasse, Uhrzeit, Wetter, Geld, Gesundheit, Ausdauer, Patronen, Promille, Minimap (N), Fadenkreuz, Zielfernrohr- und Fernglas-Ansicht, Trefferanzeige, Tacho mit Tank, Schaden und Untergrund, Hinweise, Polizei-Warnung, Benachrichtigungen, Dialoge, Fortschrittsbalken, Rausch-Effekt (Shader: Verschwimmen, Doppeltsehen, Vignette), Pausemenü (weiter, speichern, Einstellungen, Hauptmenü, beenden).
- `main_menu.gd`: Name, Weiterspielen, Neues Spiel (mit Titel), Spielstände (laden, löschen mit Rückfrage), Mehrspieler (hosten, beitreten), Figur anpassen, Einstellungen.
- `menus.gd`: Läden (kaufen, verkaufen, Häuser im Bauhaus), Werkstatt, Inventar mit Werkbank, Brennkessel, Einstellungen (`scripts/core/settings.gd`, gespeichert in `user://settings.cfg`: Maus, invertieren, Sichtfeld, Lautstärken, Vollbild, VSync, Auflösung mit FSR2, Schatten, Sichtweite).
- `inventory_view.gd` + `item_icons.gd`: Inventar im Raster wie in Tarkov (Ausrüstung links, Rucksack 10 × 8 rechts, unterschiedliche Größen, Stapel, Ziehen, Rechtsklick-Menü, Tooltips, gezeichnete Symbole).
- `phone.gd` (P): Nachrichten, Aufträge, Kamera (Foto in `user://photos`), Fotos, Wildkameras, Karte, Pannenhilfe (250 €), Freunde und Chat, Einstellungen.
- `minimap.gd`: Karte mit Straßen, Häusern, Grenze, Läden, Bauplätzen, Mitspielern, Wegpunkt (Klick auf die große Karte) und Navi-Linie.

### Mehrspieler (`scripts/net/`)
- `net.gd` (Autoload `Net`): Einzelspieler, Host, Client, dedizierter Server (`-- --server` oder Export mit Feature `dedicated_server`), Port 24680 UDP.
- Der Server verwaltet Tiere, aufgestellte Dinge, Häuser, Uhrzeit, Wetter und die Profile aller Spieler (nach Name, Speichern alle 20 s vom Client).
- Jeder Client schickt 15-mal pro Sekunde seine Position und die seines Pickups. Treffer auf Tiere werden an den Server gemeldet, Geräusche ebenfalls.
- Mitfahren auf Beifahrersitz und Ladefläche, Navi nur für den Beifahrer (Rallye-Ansage), Chat übers Handy.
- `voice.gd` (Autoload `Voice`): Sprachchat mit B (halten), J stumm; 16 kHz µ-law, in der Nähe räumlich (im Auto dumpf) oder als Funk über die Karte. Im Headless-Modus aus.
- `remote_player.gd`: Mitspieler-Figur mit Namen und Stimme.
- Die Polizei läuft pro Spieler lokal und wird nicht abgeglichen.

### Ton (`scripts/audio/sfx.gd`)
Alles synthetisch: Schritte, Tür, Hupe, Klick, Umgebung (Wind, Vögel), Schuss, Repetieren, Husten, Explosion, Sirene, Tierrufe, Regen, Benachrichtigung, Feuer, Kamera-Auslöser, Schluck.

## 7. Tests und Entwicklerhilfen

- **Selbsttest:** `<godot> --headless --path . -- --selftest` spielt durch: Einkaufen, Schießen und Nachladen, Reh erlegen und ausnehmen, Wildschwein auf den Pickup und verkaufen, Werkstatt, Haus, Aufstellen, Brennkessel mit Explosion, Polizeikontrolle und Verfolgung, Handy, Inventar, Aufträge, Fahren, Radio, Seilwinde, Trinken bis zur Ohnmacht, Fest, Speichern und Laden, Server starten. Muss mit `SELBSTTEST FERTIG` und ohne `ERROR` enden.
- **Syntaxprüfung:** `<godot> --headless --path . --script tools/check_scripts.gd` (meldet fehlende Autoloads als Fehler; das ist in diesem Modus normal). Nach neuen `class_name` einmal `--import` laufen lassen.
- **Mehrspieler-Test:** `-- --server` in einem Fenster, dann `-- --join=127.0.0.1 --name=Anna --wait=20` und ein zweiter Client.
- **Debug-Parameter** (nach `--`, siehe `scripts/debug_tools.gd`): `player=x,z`, `drive`, `tp`, `cam=yaw,pitch`, `dist`, `time`, `weather`, `money`, `upgrades`, `animal=deer+boar` mit `freeze`, `shoot`, `use=beer`, `drunk=0.1`, `reloadtest`, `buyhouse=n`, `place=still+stand`, `police`, `menu=shop:gun|garage|inventory|phone|jobs|map`, `showmenu[=saves|settings]`, `hold=aktion:sek`, `aim`, `keytest`, `radiotest`, `join`, `host`, `name`, `wait`, `shot=bild.png`, `rebuild`.
- **Export:** `export_presets.cfg` mit Windows, Linux-Server und Raspberry-Pi-Server (ARM64). Dafür in Godot die Export-Templates installieren. Die gebakte Welt wird mit exportiert, wenn das Spiel vorher einmal lief.

## 8. Verlauf

1. Grundprojekt, Godot-Installation, Verknüpfung.
2. Welt aus OSM und Höhendaten, Cartoon-Look, Spielfigur, Auto, GUI.
3. Größere Welt nach Marcos Grenze, Grenzwand, Karte, Ton, schönere Häuser, saubere Straßen, Physik-Interpolation gegen Ruckeln.
4. Umbenennung in Saint Leonard, GitHub-Repo.
5. Umbau nach dem Brief: alle Systeme aus Stufe 1 bis 3.
6. Nachbesserungen nach Marcos erstem Test: Waffenwechsel mit Anzeige, tödliche Treffer und Blutspur, Animationen für Nachladen, Rauchen, Trinken, Rausch-Effekt, weniger Nebel, Straßenränder repariert, kein Hochschießen mit R, realistischer Motorschaden, schneller nüchtern, Online-Radio, Raster-Inventar, Hauptmenü mit Spielständen und Einstellungen.

## 9. Offene Punkte und Ideen

- Polizei im Mehrspieler abgleichen (derzeit pro Spieler lokal).
- Anhänger fehlt; Spanngurte sind nur ein Inventar-Gegenstand.
- Häuser sind einfache Hüllen; Innenräume schöner machen, Gasthaus Pirtscher begehbar.
- Spielgefühl, Balancing (Preise, Polizei, Schaden) und Sound mit den Freunden testen.
- Windows-Build für Freunde (itch.io) und Server auf dem Raspberry Pi einrichten.
- Antworten des Mitentwicklers auf die Kickoff-Fragen fehlen noch.
