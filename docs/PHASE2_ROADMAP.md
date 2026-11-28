# Saint Leonard (Redneck Redemption) — Phase-2-Audit & Milestone-Roadmap

Stand: 2026-11-25 (nach Merge von `feature/start-lobby` `d325310` und lokalem Stand `050c679`).

---

## 1. Neu von Marco gefundene Punkte/Issues seit letztem Stand
Seit dem letzten Rebase (`d325310`) gab es **keine** neuen Commits, PRs oder neuen GitHub-Issues von Marco. Alle offenen GitHub-Issues (#6, #7, #10, #11, #12, #13, #16, #17, #18, #19, #20, #23, #24, #25, #26) sind vollständig in `ZUSAMMENFASSUNG.md` erfasst; im Code (`scripts/`) gibt es keine offenen `TODO`/`FIXME`-Kommentare.

---

## 2. Tiefen-Audit des Ist-Zustands

### a) Was sauber steht
- **Welt & Landmarks:** OSM-basiertes Terrain (`world_builder.gd` + gebackene `data/world_baked.scn`), begehbares Gasthaus Pirtscher + Trophäenwand (`gasthaus.gd`, `trophy_board.gd`), Feuerwehrhaus Korpitsch mit Bar & Casino (`fire_hall.gd`, `casino.gd`, `poker_game.gd`), Camp Hub (GASTON Food Truck + roter Auto-Verkaufskreis, Weapon Shack, Camper RV, Lagerfeuer, Green 4x4 ATV).
- **Fahrzeuge:** Mitsubishi L200 Pickup (`pickup_truck.glb` mit AABB-Radpivots & bündiger Anhängerkupplung), Anhänger (`trailer.gd`), ATV mit sichtbarem `CharacterModel`-Fahrer, erzwungene 3rd-Person-Kamera in allen Fahrzeugen.
- **Figuren, Lobby & Editor:** Einheitliches `CharacterModel` + `Outfit` + `char_palette.gdshader`, 3D-Titelbildschirm, 3D-Lobby vor dem Gasthaus und Kleiderschrank (`figure_editor.gd`, `menu_stage.gd`, `menu_style.gd`).
- **Jagd, Waffen & Audio:** 8 Waffen inkl. 8x-Scope/Bazooka/Plasma-VFX, lokaler 100m-Schuss-Radius, Tier-KI (inkl. Mutanten-Hase & Bigfoot, Fahrzeug-Anker im `AnimalSpawner`, Distanz-Throttling), Co-op-Doppelverkauf-Schutz, Audio-Busse (`SFX`, `Ambience`, `Voice`, Master-Limiter), `F3`-Performance-Overlay & macOS-Optimierungen (`allow_hidpi=false`, `max_fps=60`, 60 Hz Physik).

### b) Was noch fehlt, unfertig ist oder Verbesserung braucht
1. **Welt & Terrain:** Straßen auf Hängen teilweise wellig/kantig (Road Smoothing + Terrain Carving fehlt); landwirtschaftliche Felder/Äcker fehlen; Karten-Erweiterung bis Villach (#17) offen; `CaravanSpot` bei `(300.3, 1536.3)` ist noch ein 20×10×10m-Platzhalter (`caravan_big.glb` fehlt).
2. **Persistenz, Accounts & Besitzsystem:** Google-Login & Cloud-/DB-Saves (#18) fehlen; Spieler spawnen nach Laden/Reconnect noch nicht exakt an `(x, z, yaw, seat)`; Häuser und Fahrzeuge haben noch keine strikte `owner_id`-Zutritts-/Fahrkontrolle („Privatbesitz“) inkl. Aus-/Einlogg-Despawn/Respawn.
3. **Fahrzeug- & Tier-Physik:** Geparkte Fahrzeuge können an Hängen noch wegrollen (Parkbremse fehlt); Roadkill-System fehlt; Ragdoll-Physik (`PhysicalBoneSimulator3D`) wartet auf finale Skelette; aus jedem Autositz in die Luft schießen (#7) und bewusstlose Freunde in den Pickup laden (#13) fehlen.
4. **KI, Polizei & Gameplay-Tiefe:** Polizei-KI läuft noch clientseitig (#6) und Trigger sind teils zu aggressiv (#23); NPCs Hubert & Bibi (#25), 10-l-Bottich + Plane + Schmuggel (#24), Fern-Sounds (#26) und Waffen-/Ladenfortschritt (#20) sind offen.
5. **UI, Assets & Release:** In-Game-UI-Overhaul (#16), „Fehler melden“-Knopf (#19), restliche Blender-Assets (#10), Gruppen-Playtest/Balancing (#11) und itch.io-/Pi-Server-Betrieb (#12).

---

## 3. Logisch geordnete Gesamt-TODO-Liste (nach technischer Abhängigkeit)

| Prio | Aufgabe | Warum an dieser Stelle? | Betroffene Dateien | World-Bake? |
|---|---|---|---|---|
| 1 | **Straßen glätten & Terrain Carving** (`world_builder.gd`) + **Felder/Äcker** + optional **Villach-Erweiterung (#17)** | Fundament der Spielwelt; alle Weltänderungen **einmal** bündeln, danach `world_baked.scn` einfrieren | `scripts/world/world_builder.gd`, `tools/build_world_data.mjs`, `data/world_baked.scn` | **JA** |
| 2 | **Google-Account / DB-Fundament (#18)** + **Exakte Spawn-Position `(x, z, yaw, seat)`** | Grundlage für accountgebundene Saves & Besitzrechte | `scripts/core/game_state.gd`, `scripts/net/net.gd`, `scripts/game.gd` | NEIN |
| 3 | **Besitz- & Zugriffs-System (Häuser & Fahrzeuge, `owner_id`)** | Baut direkt auf Account-ID & DB-Persistenz aus Schritt 2 auf | `scripts/core/game_state.gd`, `scripts/net/net.gd`, `scripts/build/house_builder.gd`, `scripts/vehicles/vehicle.gd` | NEIN |
| 4 | **Fahrzeug-Parkbremse im Stand** | Baut auf stabilem Straßen-Terrain auf; schnell & isoliert in Fahrzeugphysik | `scripts/vehicles/vehicle.gd`, `scripts/vehicles/truck.gd`, `scripts/vehicles/atv.gd` | NEIN |
| 5 | **Roadkill-System + Aus Autositz schießen (#7) + Freunde verladen (#13)** | Fahrzeug-/Co-op-Interaktionen bauen auf Fahrzeug-Sync auf | `scripts/vehicles/vehicle.gd`, `scripts/animals/animal.gd`, `scripts/player/player.gd`, `scripts/net/net.gd` | NEIN |
| 6 | **Polizei-Überarbeitung (#23) & serverseitige Polizei-KI (#6)** | Erfordert sauberen Server-Sync und Straßennetz | `scripts/police/police_manager.gd`, `scripts/police/police_car.gd`, `scripts/net/net.gd` | NEIN |
| 7 | **Wichtige NPCs (#25), Moonshine-Pack (#24), Waffen-Progression (#20), Fern-Sounds (#26)** | Inhaltliche Gameplay-Tiefe ohne Abhängigkeit zu Welt-Bake | `scripts/npc/*`, `scripts/build/placeables.gd`, `scripts/core/items.gd`, `scripts/audio/sfx.gd` | NEIN |
| 8 | **Drop-in 3D-Assets (#10, `caravan_big.glb`) + Ragdoll-Physik** | Ragdoll benötigt finale Skelette/Modelle | `assets/models/*`, `scripts/animals/animal.gd`, `scripts/player/character_model.gd` | NEIN |
| 9 | **UI/UX-Overhaul (#16), Bug-Report (#19), Playtest (#11), itch.io/Pi (#12)** | Abschluss-Polish & Release-Auslieferung | `scripts/ui/*`, `tools/build_release.ps1`, `docs/RELEASE.md` | NEIN |

---

## 4. Phase-2-Milestones mit paralleler Arbeitsteilung (Simon & Marco)

> **Goldene Git-Regel:** Immer auf eigenen Feature-Branches arbeiten (`feature/...`), **nie** gleichzeitig dieselbe Datei (`game.gd`, `world_builder.gd`, `data/world_baked.scn`) anfassen. Vor jedem Merge auf `main`: Headless-Check (`--quit`, 0 Fehler) + `--selftest`.

### **P2-M1: Welt-Fundament (einmaliger World-Bake)** — *`world_builder.gd` / `data/world_baked.scn`: **JA***
- **Spur A (Simon):** Terrain Carving & Road Smoothing (0°-Querneigung unter Straßen, 3–6m Smoothstep-Böschung, Skirts gegen Z-Fighting) + Felder/Äcker in `scripts/world/world_builder.gd`.
- **Spur B (Marco):** Karten-/OSM-Daten-Erweiterung bis Villach (#17) in `tools/build_world_data.mjs` & `tools/map_border.json` (vor Simulations-Bake mit Spur A mergen).
- **Akzeptanz (F5):** Glatte Straßen ohne schwebende Kanten im Dorf & Richtung Südberge, sichtbare Äcker/Felder; einmaliges Neu-Backen von `data/world_baked.scn`, danach Welt wieder eingefroren.

### **P2-M2: Accounts, DB, Spawn-Persistenz & Besitzsystem** — *World-Bake: **NEIN***
- **Spur A (Simon):** `GameState` & `Net` Trennung in **User-Save** (`x, z, yaw, seat`, `owner_id`) vs. **World-Save**, exakter Boden-Spawn (`world.height_at()`), Despawn/Respawn eigener Fahrzeuge beim Aus-/Einloggen (`scripts/core/game_state.gd`, `scripts/net/net.gd`).
- **Spur B (Marco):** Google-Account-Login UI (#18) & Tür-/Fahrzeug-Zutrittskontrolle („Privatbesitz – kein Zutritt“) in `scripts/ui/main_menu.gd`, `scripts/build/house_builder.gd`, `scripts/vehicles/vehicle.gd`.
- **Akzeptanz (F5):** Spieler spawnt nach Speichern/Reconnect exakt an alter Position; fremde Häuser und fremde Fahrzeuge blockieren unbefugte Mitspieler sauber.

### **P2-M3: Fahrzeug-Physik, Roadkill & Co-op-Rettung** — *World-Bake: **NEIN***
- **Spur A (Simon):** Parkbremse gegen Wegrollen (`scripts/vehicles/vehicle.gd`), Roadkill-System (geschwindigkeitsabhängiger Schaden + Kadaver-Impuls + Co-op-Sync in `scripts/animals/animal.gd` & `vehicle.gd`).
- **Spur B (Marco):** Aus jedem Autositz in die Luft schießen (#7) + bewusstlose Freunde tragen & in den Pickup laden (#13) in `scripts/player/player.gd` & `scripts/vehicles/truck.gd`.
- **Akzeptanz (F5):** Geparkter Pickup/ATV rollt am Hang nicht weg; Tiere sterben bei hartem Aufprall sauber synchron; Beifahrer können schießen und K.o.-Freunde verladen.

### **P2-M4: KI, Polizei, Gameplay-Tiefe & Fern-Audio** — *World-Bake: **NEIN***
- **Spur A (Simon):** Realistische Fern-Sounds auf Distanz (#26) in `scripts/audio/sfx.gd` + Moonshine-Pack (10-l-Bottich, Pickup-Plane, Schmuggel, #24) in `scripts/build/placeables.gd` & `scripts/core/items.gd`.
- **Spur B (Marco):** Polizei-Überarbeitung (#23, serverseitige Polizei-KI #6) in `scripts/police/*` + wichtige NPCs Hubert & Bibi (#25) in `scripts/npc/*` + Waffen-/Ladenfortschritt (#20).
- **Akzeptanz (F5):** Fairere, server-synchronisierte Polizei; Schüsse/Explosionen klingen über Distanz realistisch; 10-l-Bottich & neue NPC-Quests spielbar.

### **P2-M5: 3D-Assets, Ragdoll & UI/UX-Overhaul** — *World-Bake: **NEIN***
- **Spur A (Simon):** Drop-in `.glb`-Assets (#10, u. a. `caravan_big.glb` bei `(300.3, 1536.3)`) + Ragdoll-Physik (`PhysicalBoneSimulator3D`) in `scripts/animals/animal.gd` & `scripts/player/character_model.gd`.
- **Spur B (Marco):** Einheitliches UI-System (UI/UX-Overhaul #16): Ein konsistentes UI-Design & Framework für Inventar, Einkaufen/Shops, Verkauf, Werkbänke/Brennanlage/Abfülltisch und Menüs, plus „Fehler melden“-Knopf (#19) in `scripts/ui/*`.
- **Akzeptanz (F5):** Wohnwagen & weitere `.glb`-Modelle sitzen sauber im Terrain; Ragdoll reagiert physikalisch; alle Shop-/NPC-/Casino-Menüs im einheitlichen Stil.

### **P2-M6: Playtest, Balancing & Release** — *World-Bake: **NEIN***
- **Spur A (Simon):** Performance-/Memory-Check (`F3`), Multi-Client-Stresstest (`mp_test.gd`) & Balancing (#11).
- **Spur B (Marco):** Export-Templates, itch.io-Upload (`tools/build_release.ps1`) & Raspberry-Pi-24/7-Server (#12).
- **Akzeptanz (F5):** Stabiler Co-op-Playtest ohne Desync/Leaks; spielbare Windows-/macOS-/Linux-Builds & laufender Pi-Server.
