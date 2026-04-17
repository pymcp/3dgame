class_name DefaultPalettes
extends RefCounted

## Factory for the default overworld + mine palettes. These are built
## programmatically at runtime rather than shipped as `.tres` files
## because the Mesh resources come from Kenney `.glb` scenes and are
## easier to fetch via `MeshLoader`.

const HEX := "res://assets/hex_tiles/"

# --- overworld -----------------------------------------------------------

static func build_overworld() -> TilePalette:
	var pal: TilePalette = TilePalette.new()

	var bedrock: TileKind = _base(&"bedrock", "Bedrock", HEX + "stone.glb", 999.0, [])
	bedrock.tint = Color(0.3, 0.3, 0.32)
	bedrock.unbreakable = true

	# Base tiles — ids match the strings used in generators / skills.
	pal.bases = [
		_base(&"grass", "Grass", HEX + "grass.glb", 1.2, ["dirt_clod"]),
		_base(&"dirt", "Dirt", HEX + "dirt.glb", 1.0, ["dirt_clod"]),
		_base(&"sand", "Sand", HEX + "sand.glb", 0.8, ["sand"]),
		_base(&"stone", "Stone", HEX + "stone.glb", 2.0, ["stone"]),
		_base_water(&"water", "Water", HEX + "water.glb"),
		bedrock,
	]

	pal.overlays = [
		_overlay(&"forest", "Forest", HEX + "grass-forest.glb", 1.5, ["wood"], [&"grass"], true),
		_overlay(&"hill", "Hill", HEX + "grass-hill.glb", 1.2, ["stone"], [&"grass", &"dirt"], true),
		_overlay(&"mountain", "Mountain", HEX + "stone-mountain.glb", 2.5, ["stone"], [&"stone"], true),
		_overlay(&"rocks_stone", "Rocks", HEX + "stone-rocks.glb", 1.0, ["stone"], [&"stone"], true),
		_overlay(&"rocks_sand", "Desert Rocks", HEX + "sand-rocks.glb", 1.0, ["stone"], [&"sand"], true),
		_overlay_ore(&"ore_iron", "Iron Deposit", HEX + "stone-rocks.glb", Color(0.85, 0.65, 0.45), 1.5, ["iron_ore"]),
		_overlay_ore(&"ore_gold", "Gold Deposit", HEX + "stone-rocks.glb", Color(1.0, 0.85, 0.25), 2.0, ["gold_ore"]),
		_overlay_ore(&"ore_crystal", "Crystal Deposit", HEX + "stone-rocks.glb", Color(0.55, 0.75, 1.0), 2.5, ["crystal"]),
		_overlay_mine_entrance(),
	]
	return pal


# --- mine ----------------------------------------------------------------

static func build_mine() -> TilePalette:
	var pal: TilePalette = TilePalette.new()

	var dark_stone_tint: Color = Color(0.55, 0.55, 0.6)
	var bedrock_tint: Color = Color(0.3, 0.3, 0.32)

	var dark_stone: TileKind = _base(&"dark_stone", "Dark Stone", HEX + "stone.glb", 2.0, ["stone"])
	dark_stone.tint = dark_stone_tint

	var mine_dirt: TileKind = _base(&"mine_dirt", "Mine Dirt", HEX + "dirt.glb", 1.0, ["dirt_clod"])
	mine_dirt.tint = Color(0.7, 0.65, 0.55)

	var bedrock: TileKind = _base(&"bedrock", "Bedrock", HEX + "stone.glb", 999.0, [])
	bedrock.tint = bedrock_tint
	bedrock.unbreakable = true

	pal.bases = [dark_stone, mine_dirt, bedrock]

	pal.overlays = [
		_overlay_ore(&"ore_iron", "Iron Deposit", HEX + "stone-rocks.glb", Color(0.85, 0.65, 0.45), 1.5, ["iron_ore"]),
		_overlay_ore(&"ore_gold", "Gold Deposit", HEX + "stone-rocks.glb", Color(1.0, 0.85, 0.25), 2.0, ["gold_ore"]),
		_overlay_ore(&"ore_crystal", "Crystal Deposit", HEX + "stone-rocks.glb", Color(0.55, 0.75, 1.0), 2.5, ["crystal"]),
		_overlay_rocks_mine(),
		_overlay_ladder_up(),
	]
	return pal


# --- builders ------------------------------------------------------------

static func _base(id: StringName, display: String, mesh_path: String, hardness: float, drops: Array) -> TileKind:
	var tk: TileKind = TileKind.new()
	tk.id = id
	tk.display_name = display
	tk.mesh = MeshLoader.load_glb(mesh_path)
	tk.hardness = hardness
	tk.drops = PackedStringArray(drops)
	return tk


static func _base_water(id: StringName, display: String, mesh_path: String) -> TileKind:
	var tk: TileKind = TileKind.new()
	tk.id = id
	tk.display_name = display
	tk.mesh = MeshLoader.load_glb(mesh_path)
	tk.hardness = 0.5
	tk.walkable_top = false
	tk.unbreakable = false
	return tk


static func _overlay(id: StringName, display: String, mesh_path: String, hardness: float,
		drops: Array, allowed_bases: Array[StringName], blocks_movement: bool) -> OverlayKind:
	var ok: OverlayKind = OverlayKind.new()
	ok.id = id
	ok.display_name = display
	ok.mesh = MeshLoader.load_glb(mesh_path)
	ok.hardness = hardness
	ok.drops = PackedStringArray(drops)
	ok.allowed_on_bases = allowed_bases
	ok.blocks_movement = blocks_movement
	return ok


static func _overlay_mine_entrance() -> OverlayKind:
	var ok: OverlayKind = OverlayKind.new()
	ok.id = &"mine_entrance"
	ok.display_name = "Mine Entrance"
	ok.mesh = MeshLoader.load_glb(HEX + "building-mine.glb")
	ok.hardness = 999.0   # not directly mineable — interaction enters the mine
	ok.blocks_movement = true
	ok.marker = &"mine_entrance"
	ok.allowed_on_bases = [&"stone", &"dirt", &"grass"]
	return ok


static func _overlay_ore(id: StringName, display: String, mesh_path: String,
		tint: Color, hardness: float, drops: Array) -> OverlayKind:
	var ok: OverlayKind = OverlayKind.new()
	ok.id = id
	ok.display_name = display
	ok.mesh = MeshLoader.load_glb(mesh_path)
	ok.tint = tint
	ok.hardness = hardness
	ok.drops = PackedStringArray(drops)
	ok.blocks_movement = false
	return ok


static func _overlay_rocks_mine() -> OverlayKind:
	var ok: OverlayKind = OverlayKind.new()
	ok.id = &"rocks_mine"
	ok.display_name = "Loose Rocks"
	ok.mesh = MeshLoader.load_glb(HEX + "stone-rocks.glb")
	ok.tint = Color(0.7, 0.7, 0.75)
	ok.hardness = 0.8
	ok.drops = PackedStringArray(["stone"])
	return ok


static func _overlay_ladder_up() -> OverlayKind:
	# Visually reuse the mine-building as the "exit ladder" hex overlay
	# (the actual ladder model is placed as a decoration prop).
	var ok: OverlayKind = OverlayKind.new()
	ok.id = &"ladder_up"
	ok.display_name = "Ladder Up"
	ok.mesh = MeshLoader.load_glb(HEX + "building-mine.glb")
	ok.hardness = 999.0
	ok.blocks_movement = true
	ok.marker = &"ladder_up"
	return ok
