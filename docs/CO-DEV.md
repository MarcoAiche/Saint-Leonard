# Saint Leonard: Co-Developer Guide

Welcome! This guide gets you from zero to contributing. It covers the engine decision, setup, how we work together without breaking each other's work, how the code is organised, how the main systems work, how to add new content, how to test, and what is still open.

The full game idea is in "Saint Leonard - Full Game Brief" plus "Saint Leonard - Update & New Ideas" (tone like Redneck Redemption without aliens, Feuerwehrhaus Korpitsch, gambling). We take genre and tone from that reference, not its art or characters. The German project summary for Marco and Claude is [ZUSAMMENFASSUNG.md](../ZUSAMMENFASSUNG.md).

---

## 1. Engine decision: Godot 4, not Unity

The kickoff doc proposed Unity. We stayed on **Godot 4.7.2 with GDScript** because:
- The brief was written for Godot (VehicleBody3D, MultiplayerSpawner, headless Linux server), and a first version of all three stages already runs in Godot.
- Godot scenes and scripts are plain text. Git merges work, and AI tools (Marco uses Claude Code) can read and write everything.
- Built-in ENet multiplayer and the headless export give us the 24/7 dedicated server without extra services or licenses.

Coming from Unity: GDScript reads like Python, a Node is a GameObject, a scene is a prefab, an autoload is a singleton, and signals are C# events.

---

## 2. Setup (about 15 minutes)

1. **Godot 4.7.2** (standard version, not .NET): `winget install GodotEngine.GodotEngine` or download from godotengine.org. Everyone must use the same version.
2. **Git** and access to the private repo `MarcoAiche/Saint-Leonard` (ask Marco to add you as a collaborator).
3. Clone: `git clone https://github.com/MarcoAiche/Saint-Leonard.git`
4. Open `project.godot` in Godot and press **F5**. The first start bakes the world into `data/world_baked.scn` (a few seconds); later starts load it in about a second.
5. Optional: **Node.js** (only to regenerate map data) and **VS Code** with the "godot-tools" extension.

For multiplayer tests with friends over the internet: ZeroTier (everyone in one virtual network) or port forwarding for UDP 24680.

---

## 3. Working together

We use **GitHub** (no file locking), so we follow the golden rule from the kickoff doc:

- **Never edit the same file at the same time.** The game is built almost entirely in code, one system per script (see section 4). Claim a system before you start (GitHub issue or WhatsApp).
- `scenes/main.tscn` is intentionally tiny (sky, sun, world node). Avoid editing it in parallel.
- **Branch per feature:** `feature/trailer`, `fix/police-sync`. Open a pull request, merge when the self-test passes.
- **Before every push**, run the self-test (section 7). It must end with `SELBSTTEST FERTIG` and no `ERROR` lines.
- **Never commit** `data/world_baked.scn`, `data/raw/` or `.godot/` (already in `.gitignore`).
- Line endings are normalised to LF (`.gitattributes`).
- **Language:** in-game text and most comments are German (the players are from Carinthia). English comments in new code are fine. Keep player-facing text German.
- **No asset files so far:** models are built from primitives, sounds are synthesised, icons are drawn. If you add real assets (Blender models, audio), put them under `assets/` and talk to Marco first about Git LFS.

---

## 4. Project structure

| Path | Contents |
|---|---|
| `project.godot` | Settings: 120 physics ticks with interpolation, mic input on, autoloads `GameState`, `Net`, `Voice`, `DebugTools` |
| `scenes/main.tscn` | Main scene: `Main` (game.gd), `WorldEnvironment`, `Sun`, `World` (world_builder.gd) |
| `scripts/game.gd` | Glue code: starts the game, input, interactions, vehicles, shops, houses, placing, shooting, photos, multiplayer callbacks |
| `scripts/core/` | `game_state.gd` (autoload: profile, world state, save/load, save slots), `items.gd` (item catalogue, houses, upgrades, recipes), `interactions.gd` ([F] interaction points), `settings.gd` (options in `user://settings.cfg`) |
| `scripts/world/` | `world_builder.gd` (terrain, roads, houses, trees, border, road tiers, fast queries), `landmarks.gd` (city shops, gas station, garage, plots, checkpoint, spawn), `sky_cycle.gd` (day/night, fog, rain), `toon.gd` and `mesh_buffer.gd` (materials, mesh helper) |
| `scripts/player/` | `player.gd` (first/third person movement, crouch, stamina, carrying, passing out), `character_model.gd` (shared character model and animation) |
| `scripts/weapons/` | `weapon_hand.gd` (rifle, scope, binoculars, flashlight, viewmodel animations for reload, smoking, drinking, eating) |
| `scripts/animals/` | `animal.gd` (species and AI), `carcass.gd`, `animal_spawner.gd` |
| `scripts/vehicles/` | `vehicle.gd` (shared driving physics), `truck.gd` (player pickup) |
| `scripts/police/` | `police_car.gd` (AI driving), `police_manager.gd` (patrols, checkpoint, controls, chases) |
| `scripts/build/` | `placeables.gd` (still, hunting stand, trail cam, campfire, furniture), `house_builder.gd` (player houses) |
| `scripts/missions/` | `missions.gd` (story and side jobs) |
| `scripts/ui/` | `hud.gd`, `main_menu.gd`, `menus.gd` (shops, garage, inventory, still, settings), `inventory_view.gd` + `item_icons.gd` (grid inventory), `phone.gd`, `minimap.gd` |
| `scripts/net/` | `net.gd` (autoload: host/join/server and sync), `voice.gd` (autoload: voice chat), `remote_player.gd` |
| `scripts/audio/` | `sfx.gd` (synthesised sounds), `engine_sound.gd`, `radio.gd` (online radio, generated music, own files) |
| `scripts/npc/` | `npc.gd` (standing NPCs with speech bubbles), `lines.gd` (their sayings) |
| `scripts/casino/` | `casino.gd` (slot machines, roulette, poker table, raids, UIs), `poker_game.gd` (Texas Hold'em engine, NPC players, hand evaluation) |
| `scripts/world/fire_hall.gd` | Feuerwehrhaus Korpitsch (hangout, bar, casino tables) |
| `scripts/debug_tools.gd` | Autoload: test parameters, self-test |
| `tools/` | `build_world_data.mjs` (map pipeline), `map_border.json`, `map_border_fit.mjs`, `check_scripts.gd` |
| `data/` | Generated world data (JSON, in Git) and the baked world (not in Git) |
| `export_presets.cfg` | Windows, Linux server, Raspberry Pi server (ARM64) |

---

## 5. How the main systems work

### World and map data
`tools/build_world_data.mjs` downloads OpenStreetMap data (Overpass API) and elevation tiles (AWS Terrarium), flattens terrain under roads, classifies land use per 5 m grid point and places trees. It writes one JSON file. Local coordinates are metres: x = east, z = south, y = height above 498 m.

`WorldBuilder` turns that into 250 m chunks and saves the result as a PackedScene. Bump `BUILD_VERSION` whenever you change how the world is built, otherwise old bakes are reused.

Road tiers (from the brief) come from `WorldBuilder.road_info(pos)`: 1 main road, 2 village road, 3 dirt road, 4 mountain trail, 0 off-road. Police, grip, damage and missions use them.

`Landmarks` picks real buildings and free spots at startup (deterministic): shops in the city, gas station, garage, 10 house plots, checkpoint, spawn.

### Game state and saving
`GameState` holds the local player's profile and the shared world. Saves are JSON files in `user://saves/` (on Windows `%APPDATA%\Godot\app_userdata\Saint-Leonard\saves`). Anything you add to `profile_dict()` or `world_dict()` is saved automatically. Note: JSON turns ints into floats; cast when loading.

### Interactions
Everything you can use with [F] is an entry in `game.interactions` (`Interactions.add(pos, radius, text, action, condition, node)`). Entries attached to a node move with it and disappear with it. The HUD shows the nearest valid entry.

### Player, weapons and animals
The player is a CharacterBody3D; the camera rig follows the interpolated transform. The rifle raycasts from the camera (layers: 1 world, 2 player, 4 vehicles, 8 animals, 16 carcasses). Animals listen to `GameState.noise_made` and look at `Animal.threats`. On death they become a `Carcass` (RigidBody3D) that can be carried, loaded, gutted or sold.

### Vehicles
`Vehicle` handles input (player or AI), grip per surface and wetness, bumps, crashes, lights and reset. `Truck` adds upgrades (rebuilt visually by `rebuild()`), cargo, fuel, damage, winch, radio and seats. `PoliceCar` adds AI driving modes (patrol, pursue, parked, go to).

### Police
`PoliceManager` spawns patrols on main roads near the player, watches for offences, runs the control dialog (breathalyzer, search, bribe, talk, flee) and chases. It is local per player in multiplayer.

### Feuerwehrhaus and gambling
`FireHall` replaces the real OSM building (id in `WorldBuilder.SKIP_BUILDINGS`) with an enterable hall. `Casino` handles slot machines (local), roulette (a shared server round every 26 s in multiplayer) and poker (`PokerGame` runs on the server or locally; clients send actions via `Net.poker_cmd` and get their own view via `Net.poker_state`; other players' hole cards stay hidden until showdown). Every poker hand raises the chance of a police raid.

### Comedy
`CharacterModel.set_expression()` (happy, angry, drunk, surprised, pain, focus), `soot()`, NPC speech bubbles (`Npc.say`, lines in `NpcLines`), hiccups, stumbling and knockdowns in `Player.knockdown()`.

### UI
The HUD is a CanvasLayer built in code. Windows (shops, garage, inventory, phone) go into `hud.menu_root`; while one is open the mouse is free and game input is blocked. `Menus.window()` gives you a scrollable panel; `Menus.row()` adds a line with a button.

### Multiplayer
There is **one dedicated server everyone connects to** (no listen/host mode). Start it with `tools/start_server.bat` / `tools/start_server.sh` or `<godot> --headless --path . -- --server`, options `--port=`, `--password=`, `--name=`, `--max=` (also stored in `user://server.cfg`). The main menu can also start a server process on the local PC and connect to it.

Authority model:
- **Server:** animals (AI, hits, deaths), placed objects and their data, houses (confirms purchases, refunds the loser of a race), time, weather, roulette rounds, the poker table, raids, all player profiles (by name, saved on every disconnect).
- **Each client:** its own player, truck (with upgrades, lights, cargo) and its own police cars (others see them), 15 updates per second (police 5 per second), unreliable.
- **Requests:** clients ask the server to place, remove, update or buy a house; the server applies and broadcasts.
- **Effects for everyone:** `Net.fx(kind, pos)` for shots, horn, explosions, burps. Chat and voice go through the server relay.
- **Joining:** the client sends name, outfit, `Net.VERSION` and password; the server rejects wrong versions, wrong passwords, duplicate names and full servers with a reason shown in the menu.
- Remote vehicles are puppets (`Vehicle.puppet`, moved with `puppet_to`); do not freeze VehicleBody3D nodes, Godot then produces NaN wheel transforms.
- Bump `Net.VERSION` whenever an RPC signature changes, so old clients get a clear message.

Godot RPCs live in `net.gd`. If you add a synced feature, add an RPC there and a callback in `game.gd` (`on_remote_*`).

---

## 6. How to add content

**A new item:** add an entry to `Items.ITEMS` (name, kind, price, shops, optional sell prices or effects). Add a size in `InventoryView.SIZES` and, if you like, an icon case in `ItemIcons.draw_icon`. Shops pick it up automatically.

**A new shop:** add the id to `Items.SHOP_NAMES`, to `Landmarks.SHOP_ORDER` and `SHOP_SIGNS`, and an NPC name in `Landmarks._build_props`.

**A new animal:** add a species to `Animal.SPECIES` (hp, speeds, senses, colours, loot), a model case in `Animal._build_model`, a call sound in `Sfx.animal_call`, and spawn rules in `AnimalSpawner._targets` and `_ok`.

**A new truck upgrade:** add it to `Items.UPGRADES`, draw it in `Truck.rebuild()` and apply its effect (grip, damage, power) in `Truck` or `Vehicle`.

**A new placeable:** add the item (kind `placeable` or `furniture`), a model in `Placeables.model`, placement rules in `Placeables.check`, and behaviour in `Game._spawn_placed`.

**A story goal or side job:** goals live in `Missions.CHAPTERS` and are completed by `_complete(id)` from events (`missions.event(name, data)`) or polling in `_process`. Side jobs are generated in `_make_job`.

**A sound:** add a static function to `Sfx` that builds samples and returns a cached `AudioStreamWAV`. Avoid names that GDScript already uses on scripts (for example `reload`, `new`, `free`).

---

## 7. Testing

The console executable is `Godot_v4.7.2-stable_win64_console.exe` (shown as `<godot>` below).

- **Self-test (run before every push):** `<godot> --headless --path . -- --selftest`
  Plays shopping, shooting, reloading, hunting, gutting, selling, garage, house, placing, still and explosion, police control and chase, phone, inventory, jobs, driving, radio, winch, drinking, festival, save/load and server start.
- **Syntax check:** `<godot> --headless --path . --script tools/check_scripts.gd` (missing autoloads are reported in this mode; ignore those). After adding a new `class_name`, run `<godot> --headless --path . --import` once.
- **Screenshots without playing:** for example `<godot> --path . -- --player=300,900 --animal=deer+boar --freeze --tp --time=12 --shot=test.png --wait=1`. All parameters are listed at the top of `scripts/debug_tools.gd`.
- **Multiplayer test (run before pushing network changes):** start `<godot> --headless --path . -- --server --mptest --quit_after=320`, wait ~8 s, then start both clients at the same time: `<godot> --headless --path . -- --join=127.0.0.1 --name=Anna --mptest=a` and `... --name=Bert --mptest=b`. Both must end with `MPTEST a FERTIG: 0 Fehler` / `MPTEST b FERTIG: 0 Fehler` (57 checks: presence, positions, trucks, chat, placing, house race, animal kill and carcass, passenger seat and GPS rule, effects, voice, police, roulette, poker with hidden cards, raid, profile after reconnect). See `scripts/mp_test.gd`.
- **Manual multiplayer on one PC:** `tools/start_server.bat`, then start the game twice and connect to `127.0.0.1` with different names.
- **Logs:** `%APPDATA%\Godot\app_userdata\Saint-Leonard\logs\godot.log`.

**Feature tests** (all after `--`, with a window): `--trailertest`, `--housetest`, `--gasthaustest`, `--trophytest`, `--wardrobetest`. Menu screenshots: `--showmenu=figure|lobby|multi --menuwait=2 --shot=file.png`. Lobby flow with a running server: two clients with `--showmenu=lobbyjoin --join=127.0.0.1 --name=Anna`. Before the multiplayer test, make sure no other server holds port 24680, otherwise the test server cannot start and every check fails.

---

## 8. Status against the brief (2026-11-25)

**Stage 1: done (first version)**
- Real map with forests, paved roads, dirt and mountain trails; southern mountains added.
- First-person movement, rifle with scope, recoil, sway, reload animation; binoculars, flashlight.
- Deer, boar, rabbit, bear and a legendary stag with hearing, sight, fleeing, charging, bleeding, physics carcasses, gutting and selling.
- Drivable 4x4 pickup with suspension, mud, bumps and damage.

**Stage 2: done (first version)**
- City shops, gas station, Gasthaus Pirtscher, garage upgrades, cigarettes and alcohol with animations and screen effects, police patrols, checkpoint, bribes and chases, moonshine still with mini game and explosions, day/night and weather, hunting stands, trail cams, campfires, phone, story in 3 chapters, side jobs, houses, furniture, crafting, grid inventory, save slots and settings.

**Update "New Ideas": done (first version)**
- Feuerwehrhaus Korpitsch as a hangout with bar, slot machine, roulette and illegal poker (NPCs and friends), police raids.
- Slot machines at the pub, gas station, supermarket and fire hall.
- Comedy: facial expressions, red drunk nose, NPC sayings, hiccups, burps, stumbling, knockdowns, soot face.

**Stage 3: done (first version)**
- Host, join and dedicated server with persistent world and profiles; synced players, trucks, animals, placed objects and houses; passenger seats and truck bed; passenger-only GPS; proximity voice chat and group radio.

**Added after the first version (2026-11-25)**
- Trailer for the pickup with hitch, cargo and straps (`scripts/vehicles/trailer.gd`).
- House interiors with upper floor, stairs, built-in chest and more furniture (`scripts/build/house_builder.gd`, `scripts/ui/chest_menu.gd`).
- Enterable Gasthaus Pirtscher with bar, tables and regulars (`scripts/world/gasthaus.gd`) and a trophy wall for big antlers and rare animals (`scripts/world/trophy_board.gd`).
- New title screen (your character on a rock above the village at sunset), logo and game icon (`assets/ui`, drawn by `tools/make_logo.tscn`).
- Character editor (categories left, mirror in the middle, Done and Cancel bottom right) and an outfit system: a recolor shader on the 3D model plus hats, hair, beards, glasses, jackets, vests and backpacks that follow the head and body bones (`scripts/player/outfit.gd`). Work clothes at the Bauhaus, casual clothes at the supermarket, hide and leather gear at the workbench.
- Multiplayer lobby in front of the Gasthaus: players stand in a row, Ready button, big Play button, shared countdown once everyone is ready.
- Release builds for itch.io and a Raspberry Pi server service (`docs/RELEASE.md`).
- Debug launch options only work in the editor and in debug builds, so release builds have no cheats.

**Not done or limited**
- Police is paused on main (`PoliceManager.ENABLED = false`); the overhaul lives on `feature/police-overhaul` (#23).
- Police AI runs on each player's client; everyone sees the cars (#6).
- Spotify is not possible (no allowed API for games). The radio streams real Austrian stations instead.
- The female model has her hair baked into the mesh, so only the hair colour changes.
- The itch.io upload needs Marco's itch.io account; only the Windows export templates are installed.

---

## 9. Good first tasks

- Trailer with hitch and physical cargo straps.
- Enterable Gasthaus Pirtscher (bar, tables, trophy wall).
- Run police AI on the server (server-owned patrols that can chase anyone).
- Real 3D models for the pickup and animals (Blender), replacing primitives one by one.
- Balancing pass on prices, fines, damage and animal behaviour after the first group playtest.

---

## 10. Kickoff answers (Marco)

- OS: Windows 11. Engine: Godot 4.7.2. Tools: Claude Code and the Godot editor.
- Version control: GitHub (private repo).
- Multiplayer: Godot's built-in ENet.
- Hosting: one dedicated server for everyone (Marco's PC, Raspberry Pi or a rented server), friends via ZeroTier.

Please send your own answers (experience, OS, which parts you want to own, time per week) to Marco via WhatsApp or as a GitHub issue.
