## Headless smoke tests for pure-function world math.
## Run: godot --headless --path . --script res://tests/test_runner.gd --quit
extends SceneTree


var _failures: int = 0
var _passed: int = 0


func _initialize() -> void:
	print("=== Hexfall smoke tests ===")
	_test_chunk_math_floor_div()
	_test_chunk_math_cell_to_chunk()
	_test_chunk_math_cell_to_local_roundtrip()
	_test_hex_grid_axial_roundtrip()
	_test_palette_lookup()
	_test_hex_cell_defaults()
	_test_landmass_shape()
	_test_overworld_generator_helpers()

	print("")
	print("Passed: %d   Failed: %d" % [_passed, _failures])
	if _failures > 0:
		quit(1)
	else:
		quit(0)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s   expected=%s got=%s" % [label, str(expected), str(actual)])


func _test_chunk_math_floor_div() -> void:
	print("-- ChunkMath.floor_div")
	_assert_eq(ChunkMath.floor_div(10, 16), 0, "10 / 16 = 0")
	_assert_eq(ChunkMath.floor_div(15, 16), 0, "15 / 16 = 0")
	_assert_eq(ChunkMath.floor_div(16, 16), 1, "16 / 16 = 1")
	_assert_eq(ChunkMath.floor_div(-1, 16), -1, "-1 / 16 = -1")
	_assert_eq(ChunkMath.floor_div(-16, 16), -1, "-16 / 16 = -1")
	_assert_eq(ChunkMath.floor_div(-17, 16), -2, "-17 / 16 = -2")


func _test_chunk_math_cell_to_chunk() -> void:
	print("-- ChunkMath.cell_to_chunk")
	_assert_eq(ChunkMath.cell_to_chunk(Vector3i(0, 0, 0), 16, 4), Vector3i(0, 0, 0), "origin")
	_assert_eq(ChunkMath.cell_to_chunk(Vector3i(15, 15, 3), 16, 4), Vector3i(0, 0, 0), "max of chunk 0")
	_assert_eq(ChunkMath.cell_to_chunk(Vector3i(16, 0, 0), 16, 4), Vector3i(1, 0, 0), "q boundary")
	_assert_eq(ChunkMath.cell_to_chunk(Vector3i(0, 0, -1), 16, 4), Vector3i(0, 0, -1), "negative layer chunk")
	_assert_eq(ChunkMath.cell_to_chunk(Vector3i(0, 0, -5), 16, 4), Vector3i(0, 0, -2), "deep layer")


func _test_chunk_math_cell_to_local_roundtrip() -> void:
	print("-- ChunkMath cell_to_local/local_to_cell roundtrip")
	for q: int in [-20, -5, 0, 15, 17, 32]:
		for l: int in [-5, -1, 0, 3, 7]:
			var coord: Vector3i = Vector3i(q, 2, l)
			var cp: Vector3i = ChunkMath.cell_to_chunk(coord, 16, 4)
			var local: Vector3i = ChunkMath.cell_to_local(coord, cp, 16, 4)
			var back: Vector3i = ChunkMath.local_to_cell(local, cp, 16, 4)
			_assert_eq(back, coord, "roundtrip(q=%d,l=%d)" % [q, l])


func _test_hex_grid_axial_roundtrip() -> void:
	print("-- HexGrid axial<->world roundtrip")
	for q: int in range(-5, 6):
		for r: int in range(-5, 6):
			var world: Vector3 = HexGrid.axial_to_world(q, r)
			var back: Vector2i = HexGrid.world_to_axial(world)
			_assert_eq(back, Vector2i(q, r), "(%d,%d)" % [q, r])


func _test_palette_lookup() -> void:
	print("-- TilePalette lookup")
	var pal: TilePalette = TilePalette.new()
	var a: TileKind = TileKind.new()
	a.id = &"grass"
	var b: TileKind = TileKind.new()
	b.id = &"dirt"
	pal.bases = [a, b]
	var o1: OverlayKind = OverlayKind.new()
	o1.id = &"forest"
	o1.marker = &"forest_marker"
	var o2: OverlayKind = OverlayKind.new()
	o2.id = &"mine_entrance"
	o2.marker = &"mine_entrance"
	pal.overlays = [o1, o2]

	_assert_eq(pal.base_index(&"grass"), 0, "grass at 0")
	_assert_eq(pal.base_index(&"dirt"), 1, "dirt at 1")
	_assert_eq(pal.base_index(&"missing"), -1, "missing returns -1")
	_assert_eq(pal.overlay_index(&"forest"), 0, "forest at 0")
	_assert_eq(pal.overlay_index(&"mine_entrance"), 1, "mine_entrance at 1")
	_assert_eq(pal.overlay_index_by_marker(&"mine_entrance"), 1, "marker lookup")


func _test_hex_cell_defaults() -> void:
	print("-- HexCell basics")
	var c: HexCell = HexCell.new(3, -2, -4, 0, -1)
	_assert_eq(c.q, 3, "q")
	_assert_eq(c.r, -2, "r")
	_assert_eq(c.layer, -4, "layer")
	_assert_eq(c.has_overlay(), false, "no overlay by default")
	_assert_eq(c.coord(), Vector3i(3, -2, -4), "coord")
	c.overlay_id = 2
	_assert_eq(c.has_overlay(), true, "overlay set")


func _test_landmass_shape() -> void:
	print("-- LandmassShape")
	var lm: LandmassShape = LandmassShape.new(Vector2.ZERO, 10.0, 10.0, null, 0.0)
	_assert_eq(lm.is_land(0.0, 0.0), true, "center is land")
	_assert_eq(lm.is_land(20.0, 0.0), false, "far away is ocean")
	_assert_eq(lm.land_factor(0.0, 0.0) > 0.9, true, "center factor ~1")
	_assert_eq(lm.land_factor(10.0, 0.0) <= 0.001, true, "edge factor ~0")
	_assert_eq(lm.land_factor(20.0, 0.0) < 0.0, true, "outside is negative")
	# Determinism: same inputs give same outputs.
	_assert_eq(lm.land_factor(3.0, 4.0), lm.land_factor(3.0, 4.0), "deterministic")
	_assert_eq(lm.coast_blend(0.0, 0.0), 1.0, "inland blend saturated")
	_assert_eq(lm.coast_blend(20.0, 0.0), 0.0, "ocean blend = 0")


func _test_overworld_generator_helpers() -> void:
	print("-- OverworldHexGenerator helpers")
	var gen: OverworldHexGenerator = OverworldHexGenerator.new(42)
	# Seed it with a landmass so land_factor has somewhere to be positive.
	gen._ensure_landmasses(16)
	_assert_eq(gen.is_land(0, 0), true, "origin is land")
	# Far outside any landmass radius.
	_assert_eq(gen.is_land(10000, 10000), false, "far coord is ocean")
	# Determinism: two generators with the same seed agree.
	var gen2: OverworldHexGenerator = OverworldHexGenerator.new(42)
	gen2._ensure_landmasses(16)
	_assert_eq(gen.land_factor(5, 5), gen2.land_factor(5, 5), "seed-determinism land_factor")
	_assert_eq(gen.surface_layer_at(5, 5), gen2.surface_layer_at(5, 5), "seed-determinism surface_layer")
	# Surface layer is always within documented bounds.
	var s: int = gen.surface_layer_at(0, 0)
	_assert_eq(s >= OverworldHexGenerator.SURFACE_MIN_LAYER, true, "surface >= SURFACE_MIN_LAYER")
	_assert_eq(s <= OverworldHexGenerator.SURFACE_MAX_LAYER, true, "surface <= SURFACE_MAX_LAYER")
	# Cliff step is one of 1/2/3.
	var step: int = gen.cliff_step_at(7, 3)
	_assert_eq(step >= 1 and step <= 3, true, "cliff_step in [1,3]")
	# Rivers only carve on land.
	_assert_eq(gen.is_river_at(10000, 10000), false, "no river in ocean")
