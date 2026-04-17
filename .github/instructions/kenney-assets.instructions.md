---
description: "Use when working with Kenney assets, importing models, choosing 3D models for features, referencing specific asset filenames, textures, character skins, or animations. Complete inventory of all available Kenney asset packs."
---
# Kenney Asset Encyclopedia

All assets are CC0 (public domain). Raw files in `kenney_raw/`, imported copies in `assets/`.

## Hexagon Kit (72 GLB models)
Source: `kenney_raw/3D assets/Hexagon Kit/Models/GLB format/`
Target: `assets/hex_tiles/`
Texture: `colormap.png` (also `variation-a.png`, `variation-b.png`)

### Terrain Tiles
- `grass.glb`, `grass-forest.glb`, `grass-hill.glb`
- `dirt.glb`, `dirt-lumber.glb`
- `sand.glb`, `sand-desert.glb`, `sand-rocks.glb`
- `stone.glb`, `stone-hill.glb`, `stone-mountain.glb`, `stone-rocks.glb`
- `water.glb`, `water-island.glb`, `water-rocks.glb`

### Path Tiles (12)
- `path-straight.glb`, `path-corner.glb`, `path-corner-sharp.glb`
- `path-crossing.glb`, `path-end.glb`, `path-start.glb`
- `path-square.glb`, `path-square-end.glb`
- `path-intersectionA.glb` through `path-intersectionH.glb`

### River Tiles (12)
- `river-straight.glb`, `river-corner.glb`, `river-corner-sharp.glb`
- `river-crossing.glb`, `river-end.glb`, `river-start.glb`
- `river-intersectionA.glb` through `river-intersectionH.glb`

### Buildings (19)
- `building-archery.glb`, `building-cabin.glb`, `building-castle.glb`
- `building-dock.glb`, `building-farm.glb`, `building-house.glb`
- `building-market.glb`, `building-mill.glb`, **`building-mine.glb`** (mine entrance!)
- `building-port.glb`, `building-sheep.glb`, **`building-smelter.glb`**
- `building-tower.glb`, `building-village.glb`, `building-wall.glb`
- `building-walls.glb`, `building-watermill.glb`, `building-wizard-tower.glb`

### Units & Other
- `unit-house.glb`, `unit-mansion.glb`, `unit-mill.glb`
- `unit-ship.glb`, `unit-ship-large.glb`, `unit-tower.glb`
- `unit-tree.glb`, `unit-wall-tower.glb`, `bridge.glb`

---

## Nature Kit (393 GLB models)
Source: `kenney_raw/3D assets/Nature Kit/Models/GLB format/`
Target: `assets/nature/`

### Cliff Blocks (primary underground terrain — 12 variants)
- `cliff_block_rock.glb`, `cliff_block_stone.glb` — full blocks
- `cliff_blockSlope_rock.glb`, `cliff_blockSlope_stone.glb` — sloped edges
- `cliff_blockCave_rock.glb`, `cliff_blockCave_stone.glb` — cave openings
- `cliff_blockDiagonal_rock.glb`, `cliff_blockDiagonal_stone.glb`
- `cliff_blockHalf_rock.glb`, `cliff_blockHalf_stone.glb`
- `cliff_blockQuarter_rock.glb`, `cliff_blockQuarter_stone.glb`

### Ground Tiles
- `ground_grass.glb`, `ground_pathTile.glb`, `ground_riverTile.glb`
- Path system: `ground_pathStraight.glb`, `ground_pathBend.glb`, `ground_pathCorner.glb`, `ground_pathCross.glb`, `ground_pathEnd.glb`, `ground_pathEndClosed.glb`, `ground_pathOpen.glb`, `ground_pathRocks.glb`, `ground_pathSide.glb`, `ground_pathSideOpen.glb`, `ground_pathSplit.glb`
- River system: `ground_riverStraight.glb`, `ground_riverBend.glb`, `ground_riverCorner.glb`, `ground_riverCross.glb`, `ground_riverEnd.glb`, `ground_riverEndClosed.glb`, `ground_riverOpen.glb`, `ground_riverRocks.glb`, `ground_riverSide.glb`, `ground_riverSideOpen.glb`, `ground_riverSplit.glb`

### Rocks & Stones (52 variants)
- `rock_smallA.glb` through `rock_smallI.glb` (9), `rock_largeA.glb` through `rock_largeF.glb` (6), `rock_tallA.glb` through `rock_tallJ.glb` (10)
- `stone_smallA.glb` through `stone_smallI.glb` (9), `stone_largeA.glb` through `stone_largeF.glb` (6), `stone_tallA.glb` through `stone_tallJ.glb` (10)
- Plus `rock_smallFlatA-C.glb`, `rock_smallTopA-B.glb`, `stone_smallFlatA-C.glb`, `stone_smallTopA-B.glb`

### Cliff Formations
- Full cliffs: `cliff_rock.glb`, `cliff_stone.glb`, `cliff_half_rock.glb`, `cliff_half_stone.glb`
- Corners: `cliff_corner_rock.glb`, `cliff_cornerInner_rock.glb`, `cliff_cornerLarge_rock.glb`, `cliff_cornerTop_rock.glb` (×2 for stone)
- Steps: `cliff_steps_rock.glb`, `cliff_stepsCorner_rock.glb` (×2 for stone)
- Waterfall: `cliff_waterfall_rock.glb`, `cliff_waterfallTop_rock.glb` (×2 for stone)

### Trees (200+ variants)
- Pine, oak, palm, etc. with multiple size/shape variants
- `tree_*.glb` naming pattern

### Other
- Grass: `grass.glb`, `grass_large.glb`, `grass_leafs.glb`, `grass_leafsLarge.glb`
- Platforms: `platform_grass.glb`, `platform_stone.glb`, `platform_beach.glb`
- Crops: `crops_dirtRow.glb`, `crops_dirtDoubleRow.glb`, `crops_dirtSingle.glb`, etc.
- Paths: `path_stone.glb`, `path_stoneCircle.glb`, `path_wood.glb`, etc.

---

## Modular Dungeon Kit (42 GLB models)
Source: `kenney_raw/3D assets/Modular Dungeon Kit/Models/GLB format/` (or FBX)
Target: `assets/dungeon/`

### Floor Templates (7)
- `template-floor.glb`, `template-floor-big.glb`, `template-floor-layer.glb`
- `template-floor-layer-raised.glb`, `template-floor-layer-hole.glb`
- `template-floor-detail.glb`, `template-floor-detail-a.glb`

### Wall Templates (6)
- `template-wall.glb`, `template-wall-half.glb`, `template-wall-corner.glb`
- `template-wall-top.glb`, `template-wall-detail-a.glb`, `template-wall-stairs.glb`

### Rooms (7)
- `room-small.glb`, `room-small-variation.glb`, `room-large.glb`, `room-large-variation.glb`
- `room-wide.glb`, `room-wide-variation.glb`, `room-corner.glb`

### Corridors (11)
- `corridor.glb`, `corridor-wide.glb`, `corridor-corner.glb`, `corridor-wide-corner.glb`
- `corridor-end.glb`, `corridor-wide-end.glb`
- `corridor-junction.glb`, `corridor-wide-junction.glb`
- `corridor-intersection.glb`, `corridor-wide-intersection.glb`, `corridor-transition.glb`

### Stairs & Gates
- `stairs.glb`, `stairs-wide.glb`
- `gate.glb`, `gate-door.glb`, `gate-door-window.glb`, `gate-metal-bars.glb`
- `template-corner.glb`, `template-detail.glb`

---

## Animated Characters Bundle
Source: `kenney_raw/3D assets/Animated Characters Bundle/`
Target: `assets/characters/`

### Base Models (FBX)
- `characterMedium.fbx` — **primary model for this game**
- `characterLargeFemale.fbx`, `characterLargeMale.fbx`, `characterSmall.fbx`

### Animations (16 FBX files)
- Movement: `idle.fbx`, `walk.fbx`, `run.fbx`, `jump.fbx`
- Combat: `attack.fbx`, `punch.fbx`, `kick.fbx`, `shoot.fbx`
- Crouch: `crouch.fbx`, `crouchIdle.fbx`, `crouchWalk.fbx`
- Interaction: **`interactGround.fbx`** (mining!), `interactStanding.fbx`
- Other: `death.fbx`, `racingIdle.fbx`, `racingLeft.fbx`, `racingRight.fbx`

### Fantasy-Appropriate Skins (10 PNG files for random player assignment)
- `fantasyFemaleA.png`, `fantasyFemaleB.png`, `fantasyMaleA.png`, `fantasyMaleB.png`
- `farmerA.png`, `farmerB.png`
- `survivorFemaleA.png`, `survivorFemaleB.png`, `survivorMaleA.png`, `survivorMaleB.png`

### All Human Skins (54 total)
- Alien/Astro (6), Athlete (8), Business (2), Casual (4), Cyborg/Robot (4)
- Fantasy (4), Farmer (2), Military (4), Racer (10), Survivor (4), Zombie (3)

### Fantasy Accessories (FBX)
- Headwear: `fantasyCap.fbx`, `strawhat.fbx`
- Backpack: `fantasyBackpack.fbx`
- Armor: `fantasyShoulderL.fbx`, `fantasyShoulderR.fbx`, `fantasyArmguard.fbx`
- Holster: `fantasyHolster.fbx`
- Weapons: **`sword.fbx`**, **`shield.fbx`**, `pitchfork.fbx`

### Other Accessories
- Hair: `hairBobcut.fbx`, `hairPigtail.fbx`, `hairPonytail.fbx`, `hairTail.fbx`, `beard.fbx`
- Eyewear: `glassesRetro.fbx`, `glassesRound.fbx`
- Military: `militaryBeret.fbx`, `militaryHelmet.fbx`, `militaryBackpack.fbx`, `militaryShoulderL/R.fbx`

---

## Fantasy Town Kit (165 GLB models)
Source: `kenney_raw/3D assets/Fantasy Town Kit/Models/GLB format/`
Target: `assets/fantasy_town/`
Key models: walls (stone + wood variants), roofs (standard + high), roads, stairs, fences, hedges, fountains, market stalls, windmill, watermill.

## Survival Kit (89 GLB models)
Source: `kenney_raw/3D assets/Survival Kit/Models/GLB format/`
Target: `assets/survival/`
Key models: modular structures (floor, walls, roof), tents, fences, workbenches, storage (boxes, barrels, chests), resource nodes (stone, wood), campfire.
