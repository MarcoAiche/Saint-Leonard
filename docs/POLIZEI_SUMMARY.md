# Polizei-Overhaul – Zusammenfassung für den späteren Wiedereinbau

**Status:** Pausiert auf `main` (`PoliceManager.ENABLED = false`), vollständiger Zwischenstand gesichert auf Branch `feature/police-overhaul` (Commit `73154d4`), GitHub Issue `#23`.

---

## 1. Streifen & Erkennung
- **Streifen-Verteilung:** Zufälliges Patrouillieren auf **allen Haupt- und Dorfstraßen** (`TIER_MAIN` und `TIER_VILLAGE` gleichberechtigt). Feld- und Bergwege werden nie bestreift (Ausnahme: Kesselexplosion).
- **Dichte:** Maximal `2` Streifen auf einem Fleck (`200 m`), insgesamt ca. `3–5` Streifen im aktiven Bereich rund um den Spieler. Streifen bleiben auch dann im Auto, wenn der Spieler zu Fuß ist.
- **Erkennungsradius:** `50 m`, **sofortige** Reaktion (Blaulicht + Sirene, keine Gnadenfrist) bei:
  - `> 65 km/h` im Ortsgebiet (`TIER_VILLAGE`)
  - `> 118 km/h` auf Hauptstraßen (`TIER_MAIN`)
  - Alkohol (`bac > 0.05` / Schlangenlinien)
  - Nacht ohne Licht
  - Frischem Unfall / Abkommen von der Straße (`last_crash_t`)
  - Moonshine offen in der Hand oder auf der Ladefläche: **100 %** Anhalte-Chance
  - Moonshine versteckt im Rucksack (oder später unter Ladeflächen-Plane): **60 %** Anhalte-Chance

## 2. Verfolgung, Offroad & Verstärkung
- **Tempolimits:**
  - Polizei: `150 km/h` auf Asphalt, `15 km/h` auf Feldwegen/Gelände (mit gelegentlichem Festfahren).
  - Spieler: normale Fahrzeuge `20 km/h` abseits von Asphalt; 4x4 Pickup Serie `115/50/20`, getunt `130/100/90`.
- **Alarmierungs-Regel:** Wenn bereits Polizei alarmiert ist (Kontrolle, Verfolgung oder Schuss-Einsatz unterwegs), wird durch weitere Schüsse oder Vergehen **keine** weitere Polizei alarmiert. Neue Verstärkung rückt **ausschließlich** dann per Auto über Straßen nach, wenn ein Polizist getötet wird (`+2` Streifenwagen).
- **Verfolgung zu Fuß & Schusswechsel:**
  - Steigt der Spieler aus oder ist zu Fuß, steigen die alarmierten Polizisten aus und verfolgen zu Fuß (etwas langsamer als Spieler-Sprint).
  - Bewaffnung der Polizisten: **70 % Pistole**, **30 % Maschinengewehr** mit Ziel- und Schieß-Animation.
  - Treffer-System (Polizisten, NPCs, Spieler): Kopfschuss (`hit_y - pos_y > 1.35`) = sofort tödlich; Körpertreffer = `3–9` Schüsse.
  - Wichtige NPCs (`Wirt Sepp`, `Kommandant Ferdl`, Laden-NPCs, später `#25` Hubert & Bibi) töten = automatisch `1.000 €` Strafe.

## 3. Kontrollpunkte (`CHECKPOINT_SPOTS`)
- Vorgegebene Kontrollpunkte auf der Karte (Koordinaten + Fahrtrichtung + Favoriten-Gewichtung — finale Koordinaten werden auf der fertigen Map ergänzt).
- Eine Kontrolle sperrt immer **nur eine Fahrtrichtung / einen Fahrstreifen** mit Hütchen.
- `80 %` Anhalte-Chance; Ausrede *"Ich wurde gerade erst kontrolliert!"* hat `90 %` Erfolg; Durchfahren ohne Anhalten = sofortige Verfolgung.
- `100 %` Alkotest an Kontrollen; `50 %` Durchsuchung (bei frecher Antwort `90 %`).

## 4. Dialoge, Strafen & Verhaftung
- **Antwort-Optionen:** Höflich vs. Frech (`-20 %` Rausreden-Erfolg pro frecher Antwort und `90 %` Durchsuchung).
- **Strafen:**
  - Alkohol: `0,5–1,0 ‰` = `500 €`, `>= 1,0 ‰` = `1.000 €` + Fahrzeug `300 s` (5 Echtzeit-Minuten) sichergestellt (Polizei patrouilliert `500 m` darum, später wieder klau-bar).
  - Moonshine: `50 €` pro Flasche + Beschlagnahmung.
  - Flucht gefasst: `1.000 €`.
  - Bestechung: `200 €` (`64 %` Erfolg, sonst `+300 €`).
- **Verhaftung** (`< 5 m` & `< 4 km/h` für `2,3 s`, bzw. `5 s` Stehenbleiben am Schussort):
  - Beschlagnahmt **alle Waffen und Moonshine**.
  - Addiert alle fälligen Strafen + **`+50 €` Bearbeitungsgebühr** (extra ausgewiesen als Gag).
  - Teleportiert den Spieler zur **Polizeistation**.

## 5. Schüsse, Kesselexplosion, Heat & Tod
- **Schüsse:**
  - `<= 100 m` von einer Streife: `1` Schuss alarmiert `1` Streifenwagen.
  - In Orts-/Hausnähe (`<= 999 m`): zufällig `4–15` Schüsse alarmieren `1` Streifenwagen.
  - Tiefer Wald (`> 999 m`): ignoriert.
- **Kesselexplosion:** Einzige Ausnahme für Feldwege; Polizei bleibt `300 s` (5 Echtzeit-Minuten) bei der Rauchsäule, beschlagnahmt Kessel/Moonshine und verhängt `5.000 €` Strafe.
- **Heat-Cooldown:** `police_heat` kühlt nach Schlafen / neuem Ingame-Tag / Fahrzeugwechsel ab.
- **Tod & Friendly Fire:**
  - Respawn **zuhause** (nicht Polizeistation), `500 €` Kosten.
  - Waffen & Moonshine werden beim Tod **nur** beschlagnahmt, wenn man **von der Polizei getötet** wurde.
  - **Friendly Fire (Multiplayer):** Tötet man einen Mitspieler, zahlt der **Schütze** die `500 €`.

---

## 6. Verknüpfte Issues & Technische Notizen für den Wiedereinbau
- **GitHub Issues:**
  - `#23`: Polizei-Overhaul (Branch `feature/police-overhaul`, Commit `73154d4`).
  - `#24`: Schnapsbrenn-Paket (10L Bottich, Ladeflächen-Plane mit `60 %` Tarnung).
  - `#25`: Wichtige NPCs (Hubert & Bibi).
- **Wichtige Tech-Notiz zu `PoliceCar` (`scripts/police/police_car.gd`):**
  - Auf `feature/police-overhaul` blieben Streifenwagen in `Mode.GOTO` stehen oder kreisten, wenn `_make_route_to` auf einem Einzelsegment endete (`route.size() < 2` -> `want_kmh = 0.0`) oder Wegpunkte innerhalb des Wendekreises lagen.
  - Für den finalen Wiedereinbau:
    1. Einheitliches Straßen-Navigations-System (fertiger Graph aller Kreuzungen mit `A*`-Wegpunktabstand `>= 15 m`) bauen und separat mit einem Fahrtest-Skript testen.
    2. `CHECKPOINT_SPOTS` mit den finalen Koordinaten der fertigen Karte befüllen.
