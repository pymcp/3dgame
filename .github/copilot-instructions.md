# Project: Hexfall — 3D Isometric Fantasy Mining Sandbox

## Overview
A 3D isometric fantasy sandbox game with hex-grid overworld, block-based underground mining, and local split-screen co-op for two players. Built in **Godot 4.3 stable** using **GDScript** as the primary language UNLESS performance-critical systems require C#/GDExtension (chunked terrain, block grids). All art assets come from the **Kenney All-in-One** asset pack (CC0 license).

## Key Notes
- You maintain these instruction files. If you make any changes to the game, please make sure the instruction files are updated to match the changes
- When in planning mode, do not try to make changes. Not even with as subagent
- Always ask questions when in planning mode
- When you ready this, say "Hello there matey!" so that I know you read this.

## Architecture

### Two-Layer World — Unified HexWorld
Both the overworld and the mine are instances of a single generic `HexWorld` class (`scripts/world/hex_world.gd`). Each instance has its own `TilePalette`, `HexWorldGenerator`, render layer bit, and environment. Both share the same `World3D` resource and are children of the main scene.

- **Cells & Coords**: A cell lives at `Vector3i(q, r, layer)` — pointy-top axial hex (q,r) + integer layer stacked on Y. `HexCell` (`scripts/world/hex_cell.gd`) stores `base_id` (index into `TilePalette.bases`) + `overlay_id` (index into `TilePalette.overlays`, or -1). Absence of a cell at a coord = open air.
- **Layer height**: `HexWorldChunk.LAYER_HEIGHT = 0.2`. World Y of a cell = `layer * LAYER_HEIGHT`.
- **Overworld**: `HexWorld` with the overworld palette + `OverworldHexGenerator`. Only `chunk_pos.z == 0` (layer 0) is populated at generate time; lower layers are empty until the player digs down. Mine entrances are cells carrying the `&"mine_entrance"` marker overlay.
- **Mine**: `HexWorld` with the mine palette + `MineHexGenerator`. Walkable air on layers `0..CHAMBER_AIR_TOP`, spawn chamber (radius `SPAWN_RADIUS`) at origin with a `&"ladder_up"` marker overlay on the layer -1 floor, winding tunnels carved through layers `0..CHAMBER_AIR_TOP` by `_tunnel_noise`, layers above `CHAMBER_AIR_TOP` left empty (no ceiling — the iso camera sits above that height and a solid ceiling would occlude the chamber), deep caves + ores via 3D `FastNoiseLite` gated by depth, bedrock floor at `BEDROCK_LAYER = -20`. The mine `Environment` background (`Color(0.02, 0.02, 0.05)`) handles the visual "enclosure" overhead.
- **Mining = strip-down**: `HexWorld.mine_cell(coord)` — if cell has an overlay, strip overlay only (drops overlay's `drops`). Else remove the cell entirely (drops base's `drops`) and the cell below is now exposed. The same API works identically in both worlds.
- **Placement**: `HexWorld.place_overlay(coord, overlay_id)` / `HexWorld.place_base(coord, base_id)` fill holes or drop overlays onto existing cells.

### Split-Screen Co-op (Day 1)
- Two side-by-side `SubViewportContainer`s, each with its own `SubViewport`, `Camera3D`, and player.
- Both viewports share the same `World3D` resource — one world, two views, plus two `HexWorld` instances (overworld + mine) living in that world.
- **Independent exploration**: Each player can enter/exit the mine independently. Visual layers + camera cull masks control per-player rendering. Layer 1 = common (players), Layer 2 = overworld, Layer 3 = mine.
- Each `HexWorld` only streams for players currently in *that* world (`set_active_players(...)`) — P1 mining + P2 on the surface → the mine does not stream for P2 and the overworld does not stream mine-loads for P1.
- Input separated by player ID prefix: `p1_move_up`, `p2_move_up`, `p1_jump`, `p2_jump`, etc.
- Player 1: WASD + Space (jump) + F (mine) + E (inventory) + Q/Z (target layer up/down). Player 2: arrows + Right Shift (jump) / gamepad Y + Numpad 0 (mine) / gamepad A + Numpad 7/1 (target layer up/down) / gamepad RB/LB.

### Isometric Camera
- `Camera3D` in orthogonal projection mode.
- Rotation: X = -35.264° (arctan(1/√2)), Y = 45° — true isometric.
- Size: ~15-20 units. Smooth-follow per player.

## Directory Structure
```
project.godot
.github/                # AI instructions, skills
assets/                 # Imported Kenney models
  hex_tiles/            # Hexagon Kit GLB models (72 files)
  nature/               # Nature Kit GLB models (cliff blocks, slopes, rocks, trees)
  dungeon/              # Modular Dungeon Kit GLB models (42 files)
  fantasy_town/         # Fantasy Town Kit GLB models (165 files) + lantern
  survival/             # Survival Kit GLB models (89 files) + barrel, chest, campfire, pickaxe, signpost
  platformer/           # Platformer Kit GLB models (ladder)
  characters/           # Animated Characters Bundle (FBX models, PNG skins, accessories)
  particles/            # Kenney Particle Pack PNGs (spark, smoke textures for mining VFX)
  ui/                   # Kenney UI Pack - Adventure PNGs (panel_brown, button_brown, button_red, banner_hanging)
kenney_raw/             # Original unprocessed Kenney asset packs (DO NOT MODIFY)
scenes/
  main.tscn             # Entry point — split-screen viewport setup
  player/               # Player character scenes
  ui/                   # UI scenes (inventory, HUD, mining progress)
  items/                # Pickup item scenes
scripts/
  global/               # Autoloads: GameManager, InputManager
  world/                # HexWorld (+ HexWorldChunk, HexWorldGenerator), OverworldHexGenerator, MineHexGenerator,
                        # HexGrid (pure static hex math), ChunkMath (hex/layer chunk helpers), HexCell,
                        # TileKind/OverlayKind/TilePalette (Resources), DefaultPalettes (factories),
                        # HexDecorator/HexDecorationProp/HexDecoratorNode, DefaultDecorators,
                        # MeshLoader (GLB→Mesh cache), TilePlacer, SkyFallTile
  player/               # PlayerController (owns model + animations), IsometricCamera (with shake),
                        # PlayerInteraction (dual-world hex raycast), PlayerFactory, MineTransitionController
  mining/               # MiningVFX (GPUParticles3D), CrackOverlay (hex-sized shader degradation)
  inventory/            # Inventory data model
  ui/                   # InventoryUI controller, PauseMenu (CanvasLayer global modal)
tests/
  test_runner.gd        # Headless smoke tests (run via `godot --headless --script res://tests/test_runner.gd`)
```

## Conventions

### Naming
- Scripts: `snake_case.gd` (e.g., `player_controller.gd`)
- Scenes: `snake_case.tscn` matching their primary script
- Nodes in scenes: `PascalCase` (e.g., `CollisionShape3D`, `MeshInstance3D`)
- Signals: `snake_case` past tense (e.g., `block_mined`, `inventory_changed`)
- Enums: `PascalCase` type, `SCREAMING_SNAKE` values (e.g., `BlockType.ORE_IRON`)
- Constants: `SCREAMING_SNAKE_CASE`

### GDScript Style
- Always use static typing: `var speed: float = 5.0`, `func move(dir: Vector3) -> void:`
- Use `class_name` for scripts that are referenced by other scripts
- Use `@export` for inspector-configurable values
- Use `@onready` for node references: `@onready var mesh: MeshInstance3D = $MeshInstance3D`
- Access autoloads directly: `GameManager.change_state(...)`, `InputManager.get_action_prefix(...)`
- Per-player input actions use prefix: `p1_move_up`, `p2_mine`, etc.

### Node Hierarchy
- One root node type per scene (CharacterBody3D for player, Node3D for world chunks, Control for UI)
- Composition over inheritance — attach child scenes rather than deep inheritance trees
- Shared world: place world Node3D in main scene, assign same World3D resource to both SubViewports

## Autoloads
- **GameManager** (`scripts/global/game_manager.gd`): Game state enum (OVERWORLD, UNDERGROUND, TRANSITION), scene transitions, world seed
- **InputManager** (`scripts/global/input_manager.gd`): Per-player action mapping, input device detection
- **Toast** (`scripts/ui/toast.gd`): Global rising-and-fading text notification. `CanvasLayer` at layer 200, `PROCESS_MODE_ALWAYS`. Call `Toast.push(text, color := Color.WHITE)` from anywhere — labels stack vertically in a top-center `VBoxContainer`, rise 80 px over 1.2 s while fading, then free themselves.

## Build & Run
- Engine: Godot 4.3 stable (Linux)
- Run: Open `project.godot` in Godot editor → F5 (or `godot --path . --main-scene scenes/main.tscn`)
- Target: 1920×1080, stretch mode `canvas_items`, Forward+ renderer
- Future: Android export via Godot's one-click export

## Asset Pipeline
- Raw assets in `kenney_raw/` — never modify these
- Copy needed GLB/FBX/PNG files into `assets/` subdirectories
- Godot auto-imports on first editor open (creates `.import` files)
- Characters use FBX base model + separate PNG skin textures applied as material overrides
- Hex tiles use shared `colormap.png` texture (with `variation-a.png`, `variation-b.png` alternatives)

## Key Technical Decisions
- **Unified `HexWorld`**: One `Node3D`-derived class drives both overworld and mine. Two instances share one `World3D`. Each has its own `TilePalette`, `HexWorldGenerator`, `render_layer_bit`, and streams independently per-active-player (`set_active_players(...)`).
- **Chunk keys**: `Vector3i(chunk_q, chunk_r, chunk_layer)`. Defaults `chunk_size_qr = 16`, `chunk_size_layer = 4`, `load_radius_qr = 3`, `load_radius_layer = 2`. Configure via `@export` on each `HexWorld`.
- **Sparse cell storage**: `HexWorldChunk.cells` is a `Dictionary[Vector3i local → HexCell]`. Absent coords = air. Rebuild is triggered by `set_cell_local` / `clear_cell_local` / on initial generation.
- **Rendering**: `MultiMeshInstance3D` per `TileKind` + per `OverlayKind` per chunk. Instance transforms are written as a flat `PackedFloat32Array` (12 xform floats + 4 color floats) via `MultiMesh.buffer`. `TileKind.tint` / `OverlayKind.tint` modulate per-instance color.
- **Collision**: `CollisionShape3D` with a `CylinderShape3D` per solid cell (one `StaticBody3D` per chunk). Cylinder radius = `HexGrid.HEX_SIZE`, height = `HexWorldChunk.LAYER_HEIGHT`. Cheap because most chunks are mostly air (caves) or only surface cells.
- **Mining**: `HexWorld.mine_cell(coord) -> HexWorld.MineResult { changed, dropped_base, base_id, overlay_id, drops }`. Strips overlay first; if no overlay, removes the cell. Damage accumulation is on `HexWorld._cell_damage` Dictionary keyed by coord. Visual `CrackOverlay` (shader) is a hex-footprint `BoxMesh` scaled to `HexGrid.HEX_SIZE * 2 × LAYER_HEIGHT`. `PlayerInteraction` shows a pulsing **flat hex ring highlight** (additive-blend `ShaderMaterial` via `assets/shaders/hex_highlight.gdshader`, `depth_test_disabled` so it always renders on top, yellow→orange as damage builds, green for interactables) positioned at the **top** of the targeted cell (`cell_origin + Vector3(0, LAYER_HEIGHT + 0.005, 0)`). Plays the `"attack"` animation on `PlayerController` (looped via `animation_finished` signal while `_mining_active` is true), faces the player model toward the target, and spawns `MiningVFX` (sparks + dust continuous, burst on completion). Widget render layers are synced to the active world on creation (`_sync_widget_render_layers`) and during world transitions via `apply_render_layers`.
- **Targeting priority**: `_update_target()` uses a three-tier system: (1) nearby interactable markers (`_find_nearby_marker` — scans within axial distance 1, ±1 layer, highlighted green) take priority over everything; (2) screen-center physics raycast (handles overlays with tall collision cylinders on the overworld); (3) `_find_facing_cell` scans adjacent hex cells closest to the player's facing direction (dot > 0.3 threshold ≈ 70° arc) and is preferred when the raycast only found the floor below the player or nothing. This works in **both** worlds — on the overworld it checks the player's layer and one below, in the mine it uses the layer-cycle offset. **Layer cycle**: `_wall_layer_offset` shifts `_find_facing_cell` vertically — tap Q/Z (P1) or Numpad 7/1 (P2) or gamepad RB/LB to move the target ±1 layer. Offset resets when the player's hex column (q,r) changes, exits the mine, or wall targeting is no longer active. This lets players carve staircases upward through mine walls.
- **Jump / Double-jump**: `PlayerController` supports up to `MAX_JUMPS = 2` (one ground + one air). `JUMP_VELOCITY = 3.35` with `gravity = 20.0` gives single-jump height ≈ 0.28 (1 LAYER_HEIGHT + 40% margin). Double-jump resets y-velocity, total max height ≈ 0.56 (clears 2 layers). `_jumps_remaining` resets on `is_on_floor()`. Jump plays `"jump"` animation (one-shot) unless `_mining_active`. Input: `p1_jump` (Space), `p2_jump` (Right Shift / gamepad Y).
- **Dynamic player size**: `PlayerController.player_size` (default `0.0625`, range `[0.005, 1.0]`) drives character dimensions. `set_player_size(new_size)` → `_apply_player_size()` updates `model.scale`, `move_speed = 0.6 + size * 20.0`, and the `CollisionShape3D`'s capsule (`radius = size * 0.6`, `height = size * 2.0`) and its Y offset (= `size`, capsule centered at half-height). The fallback capsule mesh is built at **unit dimensions** (radius 0.6, height 2.0, y=1.0) so `model.scale` handles both FBX and fallback sizing uniformly. `IsometricCamera.set_zoom_from_player_size(size)` sets `camera_size = size * CAMERA_SIZE_PER_PLAYER_SIZE (32.0)` to maintain a consistent on-screen character footprint. `MineTransitionController.enter_underground` uses `cam.size = cam.camera_size` (no more hardcoded `UNDERGROUND_CAM_SIZE`) so the mine zoom tracks the current size. **Debug controls**: `PgUp` / `PgDn` in `main.gd._unhandled_input` adjust BOTH players' size by ±0.005, resync both cameras, and `Toast.push` the new value. `JUMP_VELOCITY`, gravity, `reach_distance`, tile/terrain dimensions are all world-scale and intentionally NOT size-dependent — terrain doesn't shrink, so jump height must stay constant.
- **Placement**: `place_base(coord, base_id)` fills an air coord with a base tile; `place_overlay(coord, overlay_id)` drops an overlay onto a cell that already has a base. Both emit `cell_placed`.
- **Transitions — marker-based**: `OverlayKind.marker` is a `StringName` (e.g. `&"mine_entrance"`, `&"ladder_up"`). `MineTransitionController` detects interaction candidates by scanning cells within axial distance 1 (same layer and ±1 layer) of the player for the target marker — markers `blocks_movement = true`, so the player can't stand *on* them; they stand adjacent and hold the mine key. `MINE_SPAWN_COORD = Vector3i(0, 0, 0)`. Shared mine (v1): every overworld entrance teleports to the same mine origin. Before teleport, `HexWorld.prime_around(world_pos)` force-loads all chunks within `load_radius_*` synchronously so the player doesn't fall through ungenerated air (overworld/mine players have mismatched collision masks — the surface safety-net is on layer 2 only).
- **Safe spawn**: `HexWorld.find_safe_spawn(preferred_coord, max_radius=4) -> Vector3` searches outward in axial rings for the nearest column where the standing cell is air and the cell below is floor without a blocking overlay. `find_safe_spawn_world(preferred_world, ...)` primes chunks first, then calls `find_safe_spawn`. Used for initial player spawn (main.gd `_setup_players`) AND for both mine entry/exit teleports (MineTransitionController) — any time a player is placed or teleported, route through this helper.
- **Data-driven palettes**: `TileKind` / `OverlayKind` are `Resource` classes. `TilePalette` holds arrays of each. `DefaultPalettes.build_overworld()` / `build_mine()` in `scripts/world/default_palettes.gd` are the canonical factories. See `.github/skills/add-biome` (new `TileKind`) and `.github/skills/add-overlay` (new `OverlayKind`).
- **HexDecorator**: Reusable prop clusters anchored at a cell. `HexDecorator` (Resource) has `props: Array[HexDecorationProp]`, each prop carrying `scene_path`, `offset`, `rotation_y_deg`, `scale`, optional `light_color/energy/range`, `render_layers`, `light_cull_mask`. `HexDecoratorNode.apply(world, anchor_coord, decorator)` instantiates props and recursively sets render layers on all `VisualInstance3D` children. `DefaultDecorators.build_mine_spawn_chamber()` creates the ladder/campfire/barrel/chest/lanterns cluster.
- **MeshLoader**: `MeshLoader.load_mesh("res://assets/hex_tiles/foo.glb")` caches extracted `Mesh` (finds first `MeshInstance3D` in instantiated `PackedScene`). Used by chunks' MMIs.
- **Tile Placement FX**: `TilePlacer` still supports `MAGIC` (sky-fall + sparkle + star burst + dust + camera shake) and `PLAYER_BUILT` (instant). `SkyFallTile` handles the drop animation. `IsometricCamera.shake(duration, amplitude)` provides screen shake on impact.
- **Occlusion**: Layers strictly above the player's layer can be hidden at per-chunk granularity (rebuild visuals when `player_layer` changes). Much simpler than the old DDA. (Currently cells above the player are drawn — a future per-chunk visibility flag is planned if overdraw becomes a problem.)
- **Lighting**: Per-camera `Environment` override for mine mode (dark background `Color(0.02, 0.02, 0.05)`, low ambient). Sun `light_cull_mask = 3` (layers 1+2) so it doesn't light mine cells. OmniLight3D at lanterns/campfire uses `light_cull_mask = 5` (layers 1+3). Mine `HexWorld` sets `render_layer_bit = 4` (bit for layer 3).
- **Named Layers** (`project.godot` `[layer_names]`): `3d_render/layer_1=Players`, `layer_2=Overworld`, `layer_3=Mine`. `3d_physics/layer_1=Players`, `layer_2=Overworld`, `layer_3=Mine`. NOTE: `VisualInstance3D.layers` and `OmniLight3D.light_cull_mask` are **bitmasks**. `layers=2` → render layer 2 (overworld). `layers=4` → render layer 3 (mine). `cull_mask=3` → layers 1+2. `cull_mask=5` → layers 1+3.
- **UI Modal System**: Two patterns — **Global modals** (pause menu, settings) use `CanvasLayer` on main scene root, cover full window above both viewports, pause the tree. **Per-player modals** (inventory, shop) use `Control` inside each `SubViewport`, only cover that player's view, don't pause. `PauseMenu` is a `CanvasLayer` (layer 100, `PROCESS_MODE_ALWAYS`). Escape toggles pause.
- **Main.gd Composition**: `main.gd` only orchestrates: instantiates two `HexWorld`s, wires generators + palettes + decorators, builds players via `PlayerFactory.build()`, calls `HexDecoratorNode.apply(...)` for the mine spawn chamber, connects `mine_completed` to inventory. Overworld↔mine transitions run through `MineTransitionController`.
- **Shared Coordinate Math**: `ChunkMath` (`scripts/world/chunk_math.gd`) provides static `floor_div`, `cell_to_chunk`, `cell_to_local`, `local_to_cell`, `world_xz_to_chunk_qr`, `world_y_to_chunk_layer`. Always call through `ChunkMath` for world↔chunk conversions.
- **Testing**: `tests/test_runner.gd` is a `SceneTree` script that runs pure-function smoke tests (`ChunkMath` floor_div/roundtrip, `HexGrid` axial roundtrip, `TilePalette` lookup, `HexCell` basics) headlessly: `godot --headless --path . --script res://tests/test_runner.gd --quit`. Exits nonzero on any failure. GitHub Actions runs this plus `--check-only` on every push/PR (`.github/workflows/check.yml`).
- **Reserved-for-Future Assets**: `assets/dungeon/` (Modular Dungeon Kit, 42 files) is imported but not yet used — reserved for future dungeon/ruin content. Most of `assets/platformer/` beyond `ladder.glb` is unused but retained for future platformer-style mechanics. Keep both; do not delete.
