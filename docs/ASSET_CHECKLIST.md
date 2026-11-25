# Redneck Redemption (Saint-Leonard) — 3D Asset Checklist (`.glb`)

Drop `.glb` models into `res://assets/models/...`. `AssetLoader` automatically measures each `.glb`'s visual `AABB`, uniformly scales it to `target_height` (in meters), and aligns its bottom cleanly at `y = 0.0` while preserving original materials/textures. If a `.glb` is not present yet, the game falls back to procedural placeholder geometry with zero errors.

**Global Conventions:**
- **Orientation:** `-Z` forward in Godot (`+Y` up).
- **Art Style:** Clean Stylized Low-Poly 3D without heavy black comic outlines; matte-to-satin materials.

---

## 1. Nature (`res://assets/models/nature/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/nature/pine_tree.glb` | `9.5` | Any | None | Reddish-brown trunk (`#6E3B1E`), bare lower third, layered angular needle tiers (`#2D6E22`–`#438C2A`). |
| `res://assets/models/nature/birch_tree.glb` | `7.5` | Any | None | White bark (`#E6E6E0`) with dark horizontal streaks (`#2A2A2A`), green canopy (`#59A828`). |
| `res://assets/models/nature/deciduous_tree.glb` | `7.5` | Any | None | Tan-brown Y-branched trunk (`#8B5A2B`), clumpy leaf crown (`#59A828`). |
| `res://assets/models/nature/willow_tree.glb` | `8.5` | Any | None | Drooping olive-green weeping willow branches for the Swamp biome. |
| `res://assets/models/nature/grass_tuft.glb` | `0.45` | Any | None | Stylized 3D grass tuft (`#6EC81E`–`#82D928`). |
| `res://assets/models/nature/wildflower.glb` | `0.35` | Any | None | Small wildflower cluster (Yellow `#F2D024`, Purple `#8E5CE6`, White `#F4F4EE`). |
| `res://assets/models/nature/cattail.glb` | `1.3` | Any | None | Swamp reed/cattail stalk with brown head. |
| `res://assets/models/nature/boulder.glb` | `2.2` | Any | None | Faceted low-poly gray/blue-gray boulder (`#7A828C`, highlights `#9AA3AD`). |

## 2. Landmarks (`res://assets/models/landmarks/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/landmarks/hunting_lodge_facade.glb` | `4.5` | `-Z` | None | Timber log porch/facade (`#8C5E34`/`#5C3D22`), stone-base pillars (`#7A828C`), `"HUNTING LODGE"` plaque. |
| `res://assets/models/landmarks/gaston_food_truck.glb` | `3.6` | `-Z` | None | Cream box van (`#EFE8D8`), crimson skirt & awning (`#B82828`), serving window, rooftop 3D Steak-on-a-Bone sign. |
| `res://assets/models/landmarks/weapon_shack.glb` | `3.4` | `-Z` | None | Open-front timber shed (`#6E4B2F`) with slanted roof and front counter. |
| `res://assets/models/landmarks/wildlife_office_07.glb` | `3.2` | `-Z` | None | White/gray mobile box trailer (`#DCE2E8`) labeled `"DEPT. OF WILDLIFE / FIELD OFFICE 07"`. |
| `res://assets/models/landmarks/camper_rv.glb` | `2.9` | `-Z` | None | White & turquoise camping trailer (`#EAECE8` / `#4CA6A8`). |
| `res://assets/models/landmarks/lucky_buck_slot.glb` | `1.8` | `-Z` | Optional (`Spin`) | Red cabinet (`#A82020`), gold/bulb trim, neon deer topper, 3 reels, `"BET"`/`"CASH OUT"` buttons, chute. |
| `res://assets/models/landmarks/wooden_dock.glb` | `1.1` | `-Z` | None | Swamp wooden pier/dock over murky water (`#2E3B25`). |
| `res://assets/models/landmarks/swamp_billboard.glb` | `3.8` | `-Z` | None | Roadside wooden area-unlock billboard for the Foggy Swamp zone. |

## 3. Props (`res://assets/models/props/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/props/campfire.glb` | `0.6` | Any | None | Stone ring with charred logs (`#FF7711` flame area). |
| `res://assets/models/props/rocking_chair.glb` | `1.1` | `-Z` | None | Wooden rocking chair (`#8C5E34`) for lakeside campfire tip-over. |
| `res://assets/models/props/ammo_crate.glb` | `0.55` | `-Z` | None | Olive-green (`#4E6838`) or red/black (`#A82828`/`#24262A`) military ammo crate. |
| `res://assets/models/props/lantern.glb` | `0.4` | Any | None | Hanging yellow cabin lantern (`#FFCC55`). |
| `res://assets/models/props/traffic_cone.glb` | `0.7` | Any | None | Orange/white striped traffic cone (`#FF6A1A`/`#FFFFFF`). |
| `res://assets/models/props/steak_sign.glb` | `1.0` | `-Z` | None | 3D Steak-on-a-Bone sign (`#C83838` / `#F0EDE6`). |

## 4. Vehicles (`res://assets/models/vehicles/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/vehicles/pickup_4x4.glb` | `2.1` | `-Z` | Optional (`HoodOpen`) | Lifted 4x4 Pickup: camo green/tan (`#6D8058`/`#9C885C`), orange fenders (`#D86A20`), blue bed liner (`#2B6CB0`), roof lights (`#F0B020`). |
| `res://assets/models/vehicles/atv_4x4.glb` | `1.3` | `-Z` | None | Forest-green 4x4 ATV / Quad Bike (`#2D5A27`) with black seat & knobby tires (`#1E2022`). |

## 5. Characters (`res://assets/models/characters/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/characters/redneck_player.glb` | `1.8` | `-Z` | `Idle`, `Walk`, `Run`, `Jump` | Stylized cartoon Redneck (Overalls `#4A70B8`, floppy hat `#6B4E35`, sunglasses `#141414`, stubble). |
| `res://assets/models/characters/npc_gaston.glb` | `1.85` | `-Z` | `Idle`, `Talk` | Butcher Gaston: white chef toque (`#F4F4F0`), curly hair (`#4E3220`), handlebar mustache, blood-stained apron (`#F0F0EC`/`#A81818`). |
| `res://assets/models/characters/npc_wildlife_agent.glb` | `1.8` | `-Z` | `Idle`, `Talk` | Bald head, black sunglasses, black suit & tie (`#18181A`), white dress shirt (`#F0F0F0`). |

## 6. Animals & Bosses (`res://assets/models/animals/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/animals/boar.glb` | `0.95` | `-Z` | `Idle`, `Walk`, `Run`, `Attack`, `Death` | Dark brown wild hog (`#3B2E26`–`#5A3A22`), tusks (`#EFECE0`), oversized googly eyes. |
| `res://assets/models/animals/deer.glb` | `1.6` | `-Z` | `Idle`, `Walk`, `Run`, `Attack`, `Death` | Brown coat (`#6B4423`), cream belly (`#DDD0B4`), dark antlers (`#2E2218`), googly eyes. |
| `res://assets/models/animals/rabbit.glb` | `0.4` | `-Z` | `Idle`, `Hop`, `Death` | Small black-and-white bunny (`#222222`/`#F2F2F2`). |
| `res://assets/models/animals/mutant_rabbit.glb` | `1.5` | `-Z` | `Idle`, `Run`, `Leap`, `Attack`, `Death` | Upright clawed mutant bunny with bloodshot glowing red-rimmed eyes (`#FF2020`). |
| `res://assets/models/animals/grizzly_bear.glb` | `2.2` | `-Z` | `Idle`, `Walk`, `Run`, `Attack`, `Death` | Large brown bear (`#6E4220`) with googly eyes and roaring mouth. |
| `res://assets/models/animals/bigfoot.glb` | `3.2` | `-Z` | `Idle`, `Walk`, `Run`, `Grab`, `Throw`, `Death` | Shaggy brown fur (`#6E4220`), tan face/chest/hands/feet (`#D8BA92`), heavy brow, sharp teeth. |

## 7. Weapons & Consumables (`res://assets/models/weapons/`)
| File Path | Target Height (m) | Facing | Animations | Blueprint Visual Notes |
| :--- | :---: | :---: | :---: | :--- |
| `res://assets/models/weapons/pistol.glb` | `0.18` | `-Z` | Optional (`Fire`) | Brushed gray/steel slide (`#78808A`) with white rear sight dots. |
| `res://assets/models/weapons/shotgun.glb` | `0.22` | `-Z` | Optional (`Fire`, `Pump`) | Wood stock, dark double/pump barrel. |
| `res://assets/models/weapons/bolt_action.glb` | `0.24` | `-Z` | Optional (`Fire`, `Bolt`) | Warm wood stock (`#B8743B`), gray bolt/receiver (`#68707A`). |
| `res://assets/models/weapons/ak47.glb` | `0.26` | `-Z` | Optional (`Fire`) | Olive-green ribbed receiver (`#4E7342`/`#6A8548`), wood handguard/stock (`#A66832`). |
| `res://assets/models/weapons/lmg.glb` | `0.28` | `-Z` | Optional (`Fire`) | Gray receiver (`#5E6670`), box mag + brass ammo belt, square red-dot optic. |
| `res://assets/models/weapons/sniper.glb` | `0.28` | `-Z` | Optional (`Fire`) | Lime/olive stock (`#7A9A2E`), dark barrel, scope with green lens (`#40A840`). |
| `res://assets/models/weapons/bazooka.glb` | `0.32` | `-Z` | Optional (`Fire`) | Olive tube (`#556B38`) with yellow/orange hazard stripes (`#E5A020`). |
| `res://assets/models/weapons/plasma_blaster.glb` | `0.24` | `-Z` | Optional (`Fire`) | Cream/gray shell (`#D4D8C8`), black grip (`#202428`), neon-green emitter (`#50FF50`). |
| `res://assets/models/weapons/machete.glb` | `0.45` | `-Z` | None | Hunting knife / machete. |
| `res://assets/models/weapons/moonshine_bottle.glb` | `0.28` | `-Z` | None | Green `"ABSINTH"` bottle (`#78E840` glow) or clear Mason Jar with white lid. |
