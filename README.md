<p align="center"><img src="assets/ui/logo.png" alt="Saint Leonard" width="560"></p>

# Saint Leonard

**Jagen, Schnaps brennen, Offroad fahren, pokern und der Polizei entwischen: eine Koop-Sandbox in einem Kärntner Dorf.**

Du ziehst nach Saint Leonard, einem kleinen Ort zwischen Feldern, Wäldern und steilen Bergen. Das Gasthaus Pirtscher, der Treffpunkt des Dorfes, ist pleite, und der Inspektor aus der Stadt will zusperren. Mit deinem 4x4-Pickup, einem Gewehr und einem versteckten Brennkessel im Wald rettest du es, allein oder mit Freunden.

Gebaut mit Godot 4 und GDScript. Die Landschaft entsteht aus echten Kartendaten, Modelle, Geräusche und Musik werden im Code erzeugt.

---

## Was man tun kann

- **Jagen:** Rehe, Wildschweine, Hasen und Bären mit eigener KI. Sie hören Schüsse, Schritte und Husten und sehen dich im Nebel oder vom Hochstand aus schlechter. Wildschweine und Bären greifen an. Angeschossenes Wild blutet und hinterlässt eine Spur. Erlegtes Wild trägst du, lädst es auf den Pickup, nimmst es aus und verkaufst es.
- **Fahren:** ein 4x4-Pickup mit Federung, Matsch bei Regen, Schäden auf Schotter, Sprit, Ladefläche, Seilwinde und Online-Radio mit echten österreichischen Sendern. In der Werkstatt gibt es Geländereifen, Höherlegung, Rammschutz, Dachscheinwerfer, Auspuff und Lack.
- **Schnaps brennen:** einen Brennkessel tief im Wald aufstellen, Maische ansetzen und die Temperatur halten. Wird er zu heiß, fliegt er in die Luft, und die Rauchsäule lockt die Polizei an.
- **Der Polizei ausweichen:** Streifen auf den Hauptstraßen und eine Kontrolle vor der Stadt mit Alkotest und Durchsuchung. Du kannst kooperieren, bestechen, dich rausreden oder abhauen. Auf Feldwegen hängst du sie leichter ab.
- **Leben im Dorf:** Haus kaufen und einrichten, Trophäen und Fotos an die Wand hängen, an der Werkbank Lederjacke und Jägerhut mit Gamsbart herstellen. Dazu Rauchen und Trinken mit Animationen und Rausch, ein Handy mit Aufträgen, Kamera und Pannenhilfe.
- **Feuerwehrhaus Korpitsch:** der Treffpunkt der Truppe. Bar mit Kommandant Ferdl, Biertische, Darts und ein altes Löschfahrzeug vor dem Tor. Ab 20 Uhr läuft im Hinterzimmer die illegale Pokerrunde gegen Hias, Mitzi, Lois und deine Freunde. Wird es zu laut, kommt die Razzia.
- **Glücksspiel:** Spielautomaten im Gasthaus, an der Tankstelle und in der Stadt, Roulette am Tisch (im Mehrspieler eine gemeinsame Runde) und Texas Hold'em. Gespielt wird nur mit Spielgeld.
- **Schmäh:** Die Leute im Dorf reden mit dir. Betrunken bekommst du eine rote Nase und Schluckauf und stolperst über die eigenen Füße, nach dem Bier wird gerülpst, und wer beim Knall neben dem Kessel steht, hat danach ein Rußgesicht.
- **Geschichte:** "Rettet das Gasthaus Pirtscher" in drei Kapiteln bis zum großen Fest, dazu Nebenaufträge.
- **Welt:** Tag und Nacht, Morgennebel, Regen, Hochstand, Wildkamera und Feuerstelle.
- **Mehrspieler:** ein gemeinsamer Server rund um die Uhr, mit dem sich alle verbinden, gemeinsame Welt mit gespeichertem Fortschritt, Mitfahren auf Beifahrersitz und Ladefläche, Sprachchat in der Nähe und per Funk.

---

## Starten

1. **Godot 4.7.2** installieren: `winget install GodotEngine.GodotEngine`
2. Dieses Repository klonen und `project.godot` in Godot öffnen.
3. **F5** drücken. Beim allerersten Start wird die Welt gebaut (einige Sekunden), danach lädt sie schnell.
4. Im Hauptmenü Namen eingeben und "Neues Spiel" wählen.

Im Titelbildschirm steht deine Figur auf einem Felsen über dem Dorf. Das Menü hat Spielstände (weiterspielen, laden, löschen), Mehrspieler, Figur und Einstellungen (Maus, Sichtfeld, Lautstärke, Radio, Vollbild, Grafik).

**Figur und Kleidung:** Im Menüpunkt "Figur" (und im Spiel zu Hause über den Rucksack, "Kleiderschrank") stehst du vor einem Standspiegel: Körper und Hautton, Frisur und Haarfarbe, Bart und Brille, Kopfbedeckung, Oberteil, Hose und Rücken, jeweils mit Farben. Ziehen mit der Maus dreht die Figur. Arbeitskleidung (Warnweste, Bauhelm, Arbeitsjacke, Arbeitshose) gibt es im Bauhaus, Freizeitkleidung (Kapuzenpulli, Haube, Sonnenbrille, Trachtenjanker) im Supermarkt. Aus Fell und Leder stellst du an der Werkbank Fellmütze, Lederweste, Lederhose, Fellrucksack, Pelzmantel, Lederjacke und den Jägerhut mit Gamsbart her. Einmal angezogen bleibt ein Teil im Kleiderschrank freigeschaltet.

---

## Steuerung

**Zu Fuß**
| Taste | Aktion |
|---|---|
| W A S D | laufen |
| Shift / C / Leertaste | rennen / ducken / springen |
| Maus links / rechts | schießen / zielen (Zielfernrohr, Fernglas) |
| 1 / 2 / 3 oder Mausrad | Gewehr / Fernglas / Hände frei |
| R | nachladen |
| F | benutzen: Laden, Zapfsäule, Kessel, Hochstand, einsteigen; Wild ausnehmen (halten) |
| G | Wild tragen, auf den Pickup laden, abladen |
| Z / X | rauchen / trinken |
| L | Taschenlampe |
| V | Ego- oder Third-Person-Ansicht |
| I | Rucksack (Raster-Inventar) und Werkbank |
| P | Handy |
| M oder Tab | Karte (Klick setzt Wegpunkt) |
| N | Minimap ein/aus |
| B / J | Sprachchat: sprechen (halten) / Mikrofon stumm |
| F1 / Esc | Hilfe / Pause |

**Im Pickup**
| Taste | Aktion |
|---|---|
| W / S | Gas / Bremse und rückwärts |
| A D / Leertaste | lenken / Handbremse |
| L / K / H | Licht / Radio weiterschalten / Hupe |
| T, dann W | Seilwinde einhaken und ziehen |
| R | umgekipptes Auto aufstellen |
| F | aussteigen |

---

## Mehrspieler

Alle spielen auf **einem gemeinsamen Server**, mit dem sich jeder verbindet. Die Welt läuft dort weiter, auch wenn gerade niemand online ist, und der Server speichert die Welt (Uhrzeit, Wetter, Kessel, Hochstände, Häuser) und den Fortschritt jedes Spielers (Geld, Rucksack, Pickup, Haus, Geschichte) unter seinem Namen.

- **Verbinden:** Hauptmenü, "Mehrspieler", Serveradresse (und Passwort, falls gesetzt) eingeben, "Verbinden". Port **24680 (UDP)**, eine andere Port-Nummer schreibt man als `adresse:port`.
- **Lobby:** Nach dem Verbinden stehen alle, die gerade in der Lobby sind, mit ihren Figuren vor dem Gasthaus Pirtscher. Mit "Bereit" zeigst du, dass du startklar bist. Sind alle in der Lobby bereit, geht es nach einem kurzen Countdown gemeinsam los, mit "Spielen" sofort. Wer schon spielt, steht in der Liste als "im Spiel".
- **Server auf dem eigenen PC:** Im selben Menü startet "Server auf diesem PC starten und verbinden" einen Server ohne Fenster und verbindet dich gleich damit. Freunde verbinden sich mit deiner IP, zum Beispiel über ZeroTier.
- **Server rund um die Uhr** (eigener PC, Raspberry Pi oder Mietserver):
  ```
  tools\start_server.bat
  ```
  oder unter Linux `tools/start_server.sh`. Optionen: `--port=24680`, `--password=geheim`, `--name="Mein Server"`, `--max=16`. Dieselben Werte stehen nach dem ersten Start auch in `server.cfg` im Godot-Benutzerordner. Der Server schreibt jede Minute einen Status (Spieler online, Tiere, Häuser) und speichert bei jedem Verlassen.
- **Was alle gemeinsam erleben:** Spieler und ihre Pickups samt Ladung, Mitfahren auf Beifahrersitz und Ladefläche, Wild (der Server steuert es), Schüsse, Hupen und Explosionen, Brennkessel, Hochstände, Häuser, Uhrzeit und Wetter, Chat, Roulette-Runden, der Pokertisch und Razzien. Polizeiautos der anderen sieht man auch.
- **Sprachchat:** B halten zum Sprechen. In der Nähe wird die Stimme mit dem Abstand leiser und klingt im Auto dumpf. Der Funk (im Handy unter Einstellungen) gilt für die ganze Karte.
- **Rallye-Navi:** Sitzt ein Freund auf dem Beifahrersitz, sieht nur er das Navi und muss ansagen.
- Server und Spiel müssen dieselbe Version haben, sonst lehnt der Server die Verbindung ab. Jeder Name kann nur einmal gleichzeitig online sein.

---

## Für Entwickler

- Anleitung für Mitentwickler (Englisch): [docs/CO-DEV.md](docs/CO-DEV.md)
- Ausführliche Projektzusammenfassung (Deutsch): [ZUSAMMENFASSUNG.md](ZUSAMMENFASSUNG.md)
- **Selbsttest:** `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --selftest` muss mit `SELBSTTEST FERTIG` enden.
- **Mehrspieler-Test:** ein Server und zwei Clients spielen alle Mehrspieler-Funktionen automatisch durch (Anleitung in [docs/CO-DEV.md](docs/CO-DEV.md)).
- **Kartendaten neu erzeugen:** `node tools/build_world_data.mjs` (Node.js, keine Pakete). Die Spielgrenze steht in `tools/map_border.json`.
- **Release und Server rund um die Uhr:** [docs/RELEASE.md](docs/RELEASE.md) (`tools/build_release.ps1` baut alle Plattformen und lädt sie auf Wunsch zu itch.io hoch, `tools/install_pi_server.sh` richtet den Raspberry-Pi-Server als Dienst ein).
- **Export:** Vorlagen für Windows, Linux-Server und Raspberry Pi stehen in `export_presets.cfg`. Vorher in Godot die Export-Templates installieren.
- **Debug-Startparameter** (`--money`, `--tp`, `--selftest` usw.) wirken nur im Editor und in Debug-Builds. Ein Release-Export ignoriert sie, damit niemand damit schummelt.
- **Logo und Spielsymbol:** `godot --path . res://tools/make_logo.tscn` zeichnet `assets/ui/logo.png`, `icon.png` und `icon.ico` neu. `res://tools/outfit_sheet.tscn` rendert alle Kleidungsstücke nebeneinander zum Prüfen.

---

## Daten und Lizenzen

- Kartendaten: © OpenStreetMap-Mitwirkende, Lizenz ODbL (https://www.openstreetmap.org/copyright)
- Höhendaten: Terrain Tiles auf AWS (Mapzen/Tilezen, unter anderem aus SRTM und EU-DEM)
- Radiosender: Verzeichnis von radio-browser.info; die Streams gehören den jeweiligen Sendern
- Modelle, Geräusche, Symbole und die erzeugte Radiomusik entstehen im Code.
