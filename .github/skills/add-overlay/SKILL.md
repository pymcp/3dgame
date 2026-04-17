---
name: add-overlay
description: "Add a new OverlayKind (ore, rock, tree, hill, mine-entrance marker, etc.) to a TilePalette. Use when adding minable ores, decorative features, or marker overlays that drive gameplay."
---
# Add Overlay

## When to Use
- Adding a new ore type (iron, gold, crystal, diamond, \u2026)
- Adding a decorative feature that sits on top of a base cell (trees, rocks, hills)
- Adding a gameplay marker overlay (e.g. mine entrance, ladder, portal)

## Background
Overlays are `OverlayKind` resources (`scripts/world/overlay_kind.gd`) held in a `TilePalette`'s `overlays` array. Each cell (`HexCell`) may have at most one overlay. Mining strips the overlay first (drops its `drops`), and only after that is stripped does a second mine remove the base cell itself. Marker overlays (`marker: StringName`) drive transitions \u2014 e.g. `&"mine_entrance"` on the overworld, `&"ladder_up"` in the mine.

## Procedure

### 1. Add an `OverlayKind` to the appropriate palette
For an ore, extend `DefaultPalettes.build_mine()` in [scripts/world/default_palettes.gd](scripts/world/default_palettes.gd):
```gdscript
var ore_diamond: OverlayKind = OverlayKind.new()
ore_diamond.id = &"ore_diamond"
ore_diamond.mesh = MeshLoader.load_mesh("res://assets/hex_tiles/stone-rocks.glb")
ore_diamond.tint = Color(0.6, 0.9, 1.0)       # icy blue
ore_diamond.y_offset = 0.0
ore_diamond.hardness = 3.5                    # seconds to mine
ore_diamond.blocks_movement = false
ore_diamond.drops = [ &"diamond" ]
ore_diamond.allowed_on_bases = [&"dark_stone", &"bedrock"]
ore_diamond.valid_layers = []                 # any mine layer (depth-gate in generator)
ore_diamond.marker = &""                      # no special marker
palette.overlays.append(ore_diamond)
```
For a feature overlay (overworld tree/rock), add to `build_overworld()` instead.

### 2. Pick or reuse a Kenney hex mesh
Good overlay meshes in `assets/hex_tiles/`:
- **Ore-style**: `stone-rocks.glb`, `sand-rocks.glb` (tint via `OverlayKind.tint` for different ores)
- **Feature-style**: `grass-forest.glb`, `grass-hill.glb`, `stone-hill.glb`, `stone-mountain.glb`, `dirt-lumber.glb`
- **Structure**: `building-mine.glb`, `building-*.glb` (for markers)

Prefer tinting a shared mesh over committing a new file.

### 3. Wire a marker (for transitions / interactions)
If the overlay drives a gameplay marker, set `marker` to a stable `StringName`:
```gdscript
var entrance: OverlayKind = OverlayKind.new()
entrance.id = &"mine_entrance"
entrance.mesh = MeshLoader.load_mesh("res://assets/hex_tiles/building-mine.glb")
entrance.marker = &"mine_entrance"   # MineTransitionController looks up by marker
```
`MineTransitionController` detects a marker match via `_standing_on_marker(...)`; look for existing `&"mine_entrance"` / `&"ladder_up"` handling in [scripts/player/mine_transition_controller.gd](scripts/player/mine_transition_controller.gd) for the pattern.

### 4. Teach the generator when to place the overlay
In the relevant generator (`scripts/world/overworld_hex_generator.gd` or `scripts/world/mine_hex_generator.gd`), sample a noise field and set `cell.overlay_id` to the palette index:
```gdscript
if base_id == &"dark_stone" and cell.layer <= -10:
    var diamond_val: float = diamond_noise.get_noise_3d(q, r, layer)
    if diamond_val > 0.55:
        cell.overlay_id = palette.overlay_index(&"ore_diamond")
```
Use `palette.overlay_index(&"your_id")` (or `overlay_index_by_marker(&"marker")`) to resolve the int id.

Follow the existing per-ore pattern in `MineHexGenerator._pick_ore_overlay(...)` \u2014 each ore uses a unique noise seed-offset plus a depth gate.

### 5. Register drops with the inventory
The `drops` array is a list of `StringName` resource ids. Ensure the inventory UI (`scripts/ui/inventory_ui.gd`) and data model (`scripts/inventory/inventory.gd`) recognize any new drop id.

### 6. (Optional) Attach a decorator cluster
If the overlay should spawn props (e.g. lanterns around a mine entrance), pair it with a `HexDecorator` applied in `main.gd` via `HexDecoratorNode.apply(world, coord, decorator)`. See the `add-hex-building` skill.

### 7. Tests
Extend `tests/test_runner.gd` if needed \u2014 the existing `_test_palette_lookup` covers `overlay_index` and `overlay_index_by_marker`.

## Available Overlay Meshes (Kenney Hexagon Kit)
- `stone-rocks.glb`, `sand-rocks.glb` \u2014 generic ore / rock cluster (tint per-ore)
- `grass-forest.glb`, `dirt-lumber.glb` \u2014 tree overlays
- `grass-hill.glb`, `stone-hill.glb`, `stone-mountain.glb` \u2014 elevation features
- `water-rocks.glb`, `water-island.glb` \u2014 water-tile overlays
- `building-mine.glb`, `building-tower.glb`, `building-castle.glb`, etc. \u2014 marker/structure overlays
