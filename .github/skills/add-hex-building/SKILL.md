---
name: add-hex-building
description: "Add a new hex-tile building / structure to the overworld via the HexDecorator + marker-overlay pattern. Use when placing new structures, points of interest, or interactive buildings on the hex grid."
---
# Add Hex Building

## When to Use
- Placing a new building type on the overworld hex grid
- Adding interactive structures (shops, quest givers, crafting stations)
- Creating points of interest that spawn prop clusters (lanterns, signposts, NPCs)

## Background
A "building" in the unified `HexWorld` system is:
1. An **`OverlayKind`** carrying a `marker: StringName` placed on a cell (so it shows up in the hex MMI and can be detected by `MineTransitionController` / other interaction code), and
2. (Optional) A **`HexDecorator`** resource that spawns additional scene-level props (lights, signposts, doors) anchored at that cell.

See `HexDecorator` / `HexDecorationProp` / `HexDecoratorNode` in [scripts/world/](scripts/world/).

## Procedure

### 1. Add the building as an overlay (see `add-overlay` skill)
Create an `OverlayKind` with:
- `mesh` → your Kenney `building-*.glb`
- `marker` → a stable `StringName` like `&"shop_entrance"` (used by interaction code)
- `allowed_on_bases` → which base tiles it may sit on (e.g. `[&"grass", &"dirt"]`)
- `blocks_movement = true` if the building should be a wall

Append it to `DefaultPalettes.build_overworld()` in [scripts/world/default_palettes.gd](scripts/world/default_palettes.gd).

### 2. Teach the generator to place it
In [scripts/world/overworld_hex_generator.gd](scripts/world/overworld_hex_generator.gd), sample a sparse noise field (or use a deterministic `hash(q, r, seed)` check) and set `cell.overlay_id = palette.overlay_index(&"shop_entrance")`.

For rare/unique buildings, pair a spacing check: keep a running set of placed coords and skip placements within `min_spacing` axial distance (use `HexGrid.axial_distance`).

For a **guaranteed** placement (e.g. starting-area shop), force-place the overlay after the generator populates the chunk — mirror how `OverworldHexGenerator` force-places the guaranteed mine entrance at `(4, 4)`.

### 3. Build a `HexDecorator` for the prop cluster
Extend [scripts/world/default_decorators.gd](scripts/world/default_decorators.gd) with a new factory:
```gdscript
static func build_shop_entrance() -> HexDecorator:
    var dec: HexDecorator = HexDecorator.new()
    dec.display_name = "Shop Entrance"
    var lantern: HexDecorationProp = HexDecorationProp.new()
    lantern.scene_path = "res://assets/fantasy_town/lantern.glb"
    lantern.offset = Vector3(0.4, 0.0, 0.0)
    lantern.scale = 0.6
    lantern.light_color = Color(1.0, 0.85, 0.5)
    lantern.light_energy = 1.2
    lantern.light_range = 3.0
    lantern.render_layers = 2    # overworld render layer bit
    lantern.light_cull_mask = 3  # layers 1+2
    dec.props.append(lantern)
    # ... more props (signpost, door, etc.)
    return dec
```

### 4. Apply the decorator in `main.gd`
After the generator places the marker overlay, call:
```gdscript
HexDecoratorNode.apply(overworld, coord, DefaultDecorators.build_shop_entrance())
```
See how the mine spawn chamber is decorated in `main.gd._setup_decorations()` for the pattern. For buildings that appear in newly-streamed chunks, hook `HexWorld.chunk_loaded` and scan the chunk for cells carrying the marker.

### 5. Add interaction behavior
Handle the marker in the relevant system:
- **Transitions** → extend `MineTransitionController._standing_on_marker(...)` to recognize the marker (or create an analogous controller).
- **Shops / dialog** → add a handler in `PlayerInteraction` that, on hold-F, checks `world.get_cell(coord).overlay_id` against `palette.overlay_index_by_marker(&"shop_entrance")`, then opens a per-player UI.

### 6. Tests
If the building overlay contributes a new marker, the existing `_test_palette_lookup` case can be extended to assert `overlay_index_by_marker(&"shop_entrance") >= 0`.

## Available Hex Kit Building Models (`assets/hex_tiles/`)
- **`building-mine.glb`** — Mine entrance (existing `&"mine_entrance"` marker)
- **`building-smelter.glb`** — Smelting/crafting candidate
- `building-archery.glb`, `building-cabin.glb`, `building-castle.glb`, `building-dock.glb`, `building-farm.glb`, `building-house.glb`, `building-market.glb`, `building-mill.glb` (animated!), `building-port.glb`, `building-sheep.glb`, `building-tower.glb`, `building-village.glb`, `building-wall.glb`, `building-walls.glb`, `building-watermill.glb`, `building-wizard-tower.glb`

## Decorator Prop Sources
- **Fantasy Town Kit** (`assets/fantasy_town/`) — lanterns, signposts, doors, barrels, crates
- **Survival Kit** (`assets/survival/`) — barrel, chest, campfire, pickaxe, signpost
- **Platformer Kit** (`assets/platformer/`) — ladder (currently only `ladder.glb` is used)
- **Modular Dungeon Kit** (`assets/dungeon/`) — reserved for future dungeon/ruin content
