# Saint Leonard

**Jagen, Schnaps brennen, Offroad fahren und der Polizei entwischen: eine Koop-Sandbox in einem Kärntner Dorf.**

Du ziehst nach Saint Leonard, einem kleinen Ort zwischen Feldern, Wäldern und steilen Bergen. Das Gasthaus Pirtscher, der Treffpunkt des Dorfes, ist pleite, und der Inspektor aus der Stadt will zusperren. Mit deinem 4x4-Pickup, einem Gewehr und einem versteckten Brennkessel im Wald rettest du es, allein oder mit Freunden.

Gebaut mit Godot 4 und GDScript. Die Landschaft entsteht aus echten Kartendaten, Modelle, Geräusche und Musik werden im Code erzeugt.

---

## Was man tun kann

- **Jagen:** Rehe, Wildschweine, Hasen und Bären mit eigener KI. Sie hören Schüsse, Schritte und Husten und sehen dich im Nebel oder vom Hochstand aus schlechter. Wildschweine und Bären greifen an. Angeschossenes Wild blutet und hinterlässt eine Spur. Erlegtes Wild trägst du, lädst es auf den Pickup, nimmst es aus und verkaufst es.
- **Fahren:** ein 4x4-Pickup mit Federung, Matsch bei Regen, Schäden auf Schotter, Sprit, Ladefläche, Seilwinde und Online-Radio mit echten österreichischen Sendern. In der Werkstatt gibt es Geländereifen, Höherlegung, Rammschutz, Dachscheinwerfer, Auspuff und Lack.
- **Schnaps brennen:** einen Brennkessel tief im Wald aufstellen, Maische ansetzen und die Temperatur halten. Wird er zu heiß, fliegt er in die Luft, und die Rauchsäule lockt die Polizei an.
- **Der Polizei ausweichen:** Streifen auf den Hauptstraßen und eine Kontrolle vor der Stadt mit Alkotest und Durchsuchung. Du kannst kooperieren, bestechen, dich rausreden oder abhauen. Auf Feldwegen hängst du sie leichter ab.
- **Leben im Dorf:** Haus kaufen und einrichten, Trophäen und Fotos an die Wand hängen, an der Werkbank Lederjacke und Jägerhut mit Gamsbart herstellen. Dazu Rauchen und Trinken mit Animationen und Rausch, ein Handy mit Aufträgen, Kamera und Pannenhilfe.
- **Geschichte:** "Rettet das Gasthaus Pirtscher" in drei Kapiteln bis zum großen Fest, dazu Nebenaufträge.
- **Welt:** Tag und Nacht, Morgennebel, Regen, Hochstand, Wildkamera und Feuerstelle.
- **Mehrspieler:** Host oder dedizierter 24/7-Server, gemeinsame Welt mit gespeichertem Fortschritt, Mitfahren auf Beifahrersitz und Ladefläche, Sprachchat in der Nähe und per Funk.

---

## Starten

1. **Godot 4.7.2** installieren: `winget install GodotEngine.GodotEngine`
2. Dieses Repository klonen und `project.godot` in Godot öffnen.
3. **F5** drücken. Beim allerersten Start wird die Welt gebaut (einige Sekunden), danach lädt sie schnell.
4. Im Hauptmenü Namen eingeben und "Neues Spiel" wählen.

Das Hauptmenü hat Spielstände (weiterspielen, laden, löschen), Mehrspieler, Figur (Hemd, Hose, Haut, Kappe oder Jägerhut) und Einstellungen (Maus, Sichtfeld, Lautstärke, Radio, Vollbild, Grafik).

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

- **Hosten:** Hauptmenü, "Mehrspieler", "Server hosten". Freunde treten über deine IP bei, zum Beispiel über ZeroTier. Port **24680 (UDP)**.
- **Dedizierter Server (rund um die Uhr):**
  ```
  Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --server
  ```
  Der Server speichert die Welt (Uhrzeit, Wetter, Kessel, Hochstände, Häuser) und den Fortschritt jedes Spielers unter seinem Namen.
- **Sprachchat:** In der Nähe wird die Stimme mit dem Abstand leiser und klingt im Auto dumpf. Der Funk (im Handy unter Einstellungen) gilt für die ganze Karte.
- **Rallye-Navi:** Sitzt ein Freund auf dem Beifahrersitz, sieht nur er das Navi und muss ansagen.

---

## Für Entwickler

- Anleitung für Mitentwickler (Englisch): [docs/CO-DEV.md](docs/CO-DEV.md)
- Ausführliche Projektzusammenfassung (Deutsch): [ZUSAMMENFASSUNG.md](ZUSAMMENFASSUNG.md)
- **Selbsttest:** `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --selftest` muss mit `SELBSTTEST FERTIG` enden.
- **Kartendaten neu erzeugen:** `node tools/build_world_data.mjs` (Node.js, keine Pakete). Die Spielgrenze steht in `tools/map_border.json`.
- **Export:** Vorlagen für Windows, Linux-Server und Raspberry Pi stehen in `export_presets.cfg`. Vorher in Godot die Export-Templates installieren.

---

## Daten und Lizenzen

- Kartendaten: © OpenStreetMap-Mitwirkende, Lizenz ODbL (https://www.openstreetmap.org/copyright)
- Höhendaten: Terrain Tiles auf AWS (Mapzen/Tilezen, unter anderem aus SRTM und EU-DEM)
- Radiosender: Verzeichnis von radio-browser.info; die Streams gehören den jeweiligen Sendern
- Modelle, Geräusche, Symbole und die erzeugte Radiomusik entstehen im Code.
