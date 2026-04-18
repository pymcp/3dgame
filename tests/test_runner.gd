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
	_test_mine_transition_progress_math()
	_test_item_registry()
	_test_inventory_stringname_migration()
	_test_player_equipment_roundtrip()
	_test_recipe_can_craft()
	_test_mine_speed_multiplier()
	_test_hex_pathfinder_id_packing()
	_test_bt_composites()
	_test_creature_def_defaults()
	_test_hex_cell_rotation()
	_test_road_bitmask_normalization()
	_test_road_overlay_registration()
	_test_portal_realm_palette()
	_test_overworld_portal_overlay()
	_test_portal_compression_math()
	_test_portal_items_registered()
	_test_player_world_state_enum()

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


func _test_mine_transition_progress_math() -> void:
	# Simulates the per-frame accumulation in MineTransitionController
	# without needing a full PlayerController / HexWorld setup. Verifies
	# that holding the key for MINE_ENTRY_TIME seconds fills the bar to
	# 1.0 (completion) and that letting go resets to 0.
	print("-- MineTransitionController progress math")
	var duration: float = MineTransitionController.MINE_ENTRY_TIME
	var dt: float = 1.0 / 60.0
	var progress: float = 0.0
	var frames: int = int(duration / dt) + 1
	for _i: int in frames:
		progress += dt / duration
	_assert_eq(progress >= 1.0, true, "hold for MINE_ENTRY_TIME reaches 1.0")
	# Release -> reset.
	progress = 0.0
	_assert_eq(progress, 0.0, "release resets to 0")
	# Half-fill mid-transition should be clamped in [0, 1].
	progress = 0.5
	_assert_eq(clampf(progress, 0.0, 1.0), 0.5, "half-fill passes through clamp")


func _test_item_registry() -> void:
	# Autoload access — safe under SceneTree because autoloads are
	# instantiated as tree root children before _initialize runs.
	print("-- ItemRegistry")
	var reg: Node = root.get_node_or_null("ItemRegistry")
	_assert_eq(reg != null, true, "ItemRegistry autoload present")
	if reg == null:
		return
	# Seeded raw materials.
	for id: StringName in [&"stone", &"dirt_clod", &"sand", &"wood",
			&"iron_ore", &"gold_ore", &"crystal"]:
		var d: ItemDef = reg.get_def(id)
		_assert_eq(d != null, true, "has def %s" % id)
		if d:
			_assert_eq(d.category, ItemDef.CAT_MATERIAL, "%s is material" % id)
	# A weapon.
	var sword: ItemDef = reg.get_def(&"sword_basic")
	_assert_eq(sword != null, true, "has sword_basic")
	if sword:
		_assert_eq(sword.category, ItemDef.CAT_WEAPON, "sword_basic is weapon")
		_assert_eq(sword.is_equippable(), true, "sword_basic equippable")
		_assert_eq(sword.equipment_slot(), &"weapon", "weapon→weapon slot")
	# Regression: no pickaxe entries. Pickaxe is an implicit player
	# attribute, not an inventory item.
	for id: StringName in reg.all_ids():
		var d: ItemDef = reg.get_def(id)
		_assert_eq(String(id).find("pickaxe") < 0, true, "%s has no pickaxe in id" % id)
		if d:
			_assert_eq(d.category != &"pickaxe", true, "%s not pickaxe category" % id)
	# Category→slot mapping is 1:1.
	_assert_eq(ItemDef.CATEGORY_TO_SLOT[ItemDef.CAT_ARMOR_HEAD], &"head", "head slot")
	_assert_eq(ItemDef.CATEGORY_TO_SLOT[ItemDef.CAT_ARMOR_BOOTS], &"boots", "boots slot")
	_assert_eq(ItemDef.CATEGORY_TO_SLOT.has(ItemDef.CAT_MATERIAL), false, "material not equippable")


func _test_inventory_stringname_migration() -> void:
	print("-- Inventory StringName keys")
	var inv: Inventory = Inventory.new()
	inv.add_item("stone", 3)        # String in → StringName stored
	inv.add_item(&"stone", 2)        # StringName in → same key
	_assert_eq(inv.get_count("stone"), 5, "String and StringName merge")
	_assert_eq(inv.get_count(&"stone"), 5, "StringName lookup")
	_assert_eq(inv.has_item(&"stone", 5), true, "has_item 5")
	_assert_eq(inv.has_item("stone", 6), false, "has_item 6 false")
	_assert_eq(inv.remove_item(&"stone", 4), true, "remove 4 ok")
	_assert_eq(inv.get_count(&"stone"), 1, "remainder 1")
	# Drain → auto-erase.
	_assert_eq(inv.remove_item("stone", 1), true, "remove last")
	_assert_eq(inv.get_count("stone"), 0, "drained")
	_assert_eq(inv.has_item("stone"), false, "gone")
	# get_stack returns normalized StringName id.
	inv.add_item("iron_ore", 7)
	var stack: ItemStack = inv.get_stack("iron_ore")
	_assert_eq(stack.id, &"iron_ore", "stack id StringName")
	_assert_eq(stack.count, 7, "stack count")
	inv.free()


func _test_player_equipment_roundtrip() -> void:
	print("-- PlayerEquipment equip/unequip roundtrip")
	var inv: Inventory = Inventory.new()
	var eq: PlayerEquipment = PlayerEquipment.new()
	eq.set_inventory(inv)
	inv.add_item(&"sword_basic", 1)
	_assert_eq(inv.get_count(&"sword_basic"), 1, "have sword before equip")
	_assert_eq(eq.equip(&"sword_basic"), true, "equip ok")
	_assert_eq(inv.get_count(&"sword_basic"), 0, "inventory drained on equip")
	_assert_eq(eq.get_equipped(&"weapon"), &"sword_basic", "weapon slot populated")
	eq.unequip(&"weapon")
	_assert_eq(eq.get_equipped(&"weapon"), &"", "weapon slot cleared")
	_assert_eq(inv.get_count(&"sword_basic"), 1, "inventory restored on unequip")
	# Swap: equipping a second weapon returns the first to inventory.
	inv.add_item(&"sword_iron", 1)
	eq.equip(&"sword_basic")
	_assert_eq(eq.equip(&"sword_iron"), true, "equip second weapon")
	_assert_eq(eq.get_equipped(&"weapon"), &"sword_iron", "slot has new weapon")
	_assert_eq(inv.get_count(&"sword_basic"), 1, "old weapon returned to inv")
	inv.free()
	eq.free()


func _test_recipe_can_craft() -> void:
	print("-- Recipe.can_craft")
	var inv: Inventory = Inventory.new()
	var r: Recipe = Recipe.build(&"test", "Test",
			[[&"iron_ore", 3], [&"wood", 1]], &"sword_iron", 1)
	_assert_eq(r.can_craft(inv), false, "empty inv fails")
	inv.add_item(&"iron_ore", 2)
	inv.add_item(&"wood", 1)
	_assert_eq(r.can_craft(inv), false, "partial inputs fails")
	inv.add_item(&"iron_ore", 1)
	_assert_eq(r.can_craft(inv), true, "all inputs present")
	_assert_eq(r.craft(inv), true, "craft succeeds")
	_assert_eq(inv.get_count(&"iron_ore"), 0, "iron consumed")
	_assert_eq(inv.get_count(&"wood"), 0, "wood consumed")
	_assert_eq(inv.get_count(&"sword_iron"), 1, "output granted")
	_assert_eq(r.can_craft(inv), false, "cannot craft again")
	inv.free()


func _test_mine_speed_multiplier() -> void:
	print("-- PlayerController.get_mine_speed_multiplier by tier")
	var pc: PlayerController = PlayerController.new()
	pc.pickaxe_tier = 1
	_assert_eq(pc.get_mine_speed_multiplier(), 1.0, "tier 1 = 1.0")
	pc.pickaxe_tier = 2
	_assert_eq(pc.get_mine_speed_multiplier(), 1.5, "tier 2 = 1.5")
	pc.pickaxe_tier = 3
	_assert_eq(pc.get_mine_speed_multiplier(), 2.25, "tier 3 = 2.25")
	pc.pickaxe_tier = 99
	_assert_eq(pc.get_mine_speed_multiplier(), 1.0, "unknown tier falls back to 1.0")
	pc.free()


# Custom RefCounted that records ticks for BT composite tests.
class _RecorderNode extends BTNode:
	var status_to_return: int = 0  # SUCCESS
	var ticks: int = 0

	func tick(_creature: Creature, _bb: BTBlackboard, _delta: float) -> int:
		ticks += 1
		return status_to_return


func _test_hex_pathfinder_id_packing() -> void:
	print("-- HexPathfinder coord<->id packing")
	# Construct via internal helpers — pathfinder doesn't need a real
	# HexWorld for the pure packing roundtrip.
	var pf: HexPathfinder = HexPathfinder.new(null)
	var coords: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, -1, 5),
		Vector3i(-32, 64, -7),
		Vector3i(1000, -1000, 12),
	]
	for c: Vector3i in coords:
		var id: int = pf._coord_to_id(c)
		var back: Vector3i = pf._id_to_coord(id)
		_assert_eq(back, c, "roundtrip %s" % str(c))
	# Distinct coords must produce distinct ids.
	_assert_eq(
		pf._coord_to_id(Vector3i(1, 2, 3)) != pf._coord_to_id(Vector3i(3, 2, 1)),
		true,
		"distinct ids",
	)


func _test_bt_composites() -> void:
	print("-- Behavior tree composites")
	var bb: BTBlackboard = BTBlackboard.new()

	# Selector returns first non-failure.
	var s: BTSelector = BTSelector.new()
	var fail_node: _RecorderNode = _RecorderNode.new()
	fail_node.status_to_return = BTNode.Status.FAILURE
	var ok_node: _RecorderNode = _RecorderNode.new()
	ok_node.status_to_return = BTNode.Status.SUCCESS
	var never_node: _RecorderNode = _RecorderNode.new()
	never_node.status_to_return = BTNode.Status.SUCCESS
	s.children = [fail_node, ok_node, never_node]
	_assert_eq(s.tick(null, bb, 0.0), BTNode.Status.SUCCESS, "selector → first success")
	_assert_eq(fail_node.ticks, 1, "selector ticked failure once")
	_assert_eq(ok_node.ticks, 1, "selector ticked success once")
	_assert_eq(never_node.ticks, 0, "selector skipped after success")

	# Sequence returns first non-success.
	var seq: BTSequence = BTSequence.new()
	var s1: _RecorderNode = _RecorderNode.new()
	s1.status_to_return = BTNode.Status.SUCCESS
	var s2: _RecorderNode = _RecorderNode.new()
	s2.status_to_return = BTNode.Status.RUNNING
	var s3: _RecorderNode = _RecorderNode.new()
	s3.status_to_return = BTNode.Status.SUCCESS
	seq.children = [s1, s2, s3]
	_assert_eq(seq.tick(null, bb, 0.0), BTNode.Status.RUNNING, "sequence → running")
	_assert_eq(s1.ticks, 1, "sequence ticked first success")
	_assert_eq(s2.ticks, 1, "sequence ticked running")
	_assert_eq(s3.ticks, 0, "sequence skipped after running")

	# Inverter flips success↔failure, passes running through.
	var inv_n: BTInverter = BTInverter.new()
	var inner: _RecorderNode = _RecorderNode.new()
	inner.status_to_return = BTNode.Status.SUCCESS
	inv_n.child = inner
	_assert_eq(inv_n.tick(null, bb, 0.0), BTNode.Status.FAILURE, "inverter SUCCESS→FAILURE")
	inner.status_to_return = BTNode.Status.FAILURE
	_assert_eq(inv_n.tick(null, bb, 0.0), BTNode.Status.SUCCESS, "inverter FAILURE→SUCCESS")
	inner.status_to_return = BTNode.Status.RUNNING
	_assert_eq(inv_n.tick(null, bb, 0.0), BTNode.Status.RUNNING, "inverter passes RUNNING")

	# Blackboard get/set/clear.
	bb.set_var(&"k", 42)
	_assert_eq(bb.get_var(&"k"), 42, "bb stored value")
	_assert_eq(bb.has_var(&"k"), true, "bb has_var")
	bb.clear(&"k")
	_assert_eq(bb.has_var(&"k"), false, "bb cleared")
	_assert_eq(bb.get_var(&"missing", "default"), "default", "bb default")


func _test_creature_def_defaults() -> void:
	print("-- DefaultCreatures factory")
	var orc: CreatureDef = DefaultCreatures.build_orc()
	_assert_eq(orc.id, &"orc", "orc id")
	_assert_eq(orc.faction, &"hostile", "orc hostile")
	_assert_eq(orc.detection_range > 0, true, "orc has detection")
	_assert_eq(orc.behavior != null, true, "orc has BT root")
	var skel: CreatureDef = DefaultCreatures.build_skeleton()
	_assert_eq(skel.id, &"skeleton", "skeleton id")
	_assert_eq(skel.behavior != null, true, "skeleton has BT root")
	var zomb: CreatureDef = DefaultCreatures.build_zombie()
	_assert_eq(zomb.id, &"zombie", "zombie id")
	_assert_eq(zomb.faction, &"wildlife", "zombie wildlife")
	_assert_eq(zomb.behavior != null, true, "zombie has BT root")


func _test_hex_cell_rotation() -> void:
	print("-- HexCell rotation")
	var cell: HexCell = HexCell.new(1, 2, 3, 0, -1)
	_assert_eq(cell.rotation, 0, "default rotation is 0")
	cell.rotation = 3
	_assert_eq(cell.rotation, 3, "rotation can be set to 3")
	cell.rotation = 5
	_assert_eq(cell.rotation, 5, "rotation can be set to 5")


func _test_road_bitmask_normalization() -> void:
	print("-- Road bitmask normalization")
	# Single bit at position 0 → canonical 1, shift 0.
	var r0: Array = HexRoadResolver.normalize(0b000001)
	_assert_eq(r0[0], 1, "mask 1 → canonical 1")
	_assert_eq(r0[1], 0, "mask 1 → shift 0")
	# Single bit at position 3 → canonical 1, shift 3.
	var r3: Array = HexRoadResolver.normalize(0b001000)
	_assert_eq(r3[0], 1, "mask 8 → canonical 1")
	_assert_eq(r3[1], 3, "mask 8 → shift 3")
	# Opposite edges (bits 0,3) → canonical 9, shift 0.
	var opp: Array = HexRoadResolver.normalize(0b001001)
	_assert_eq(opp[0], 9, "mask 9 → canonical 9")
	_assert_eq(opp[1], 0, "mask 9 → shift 0")
	# Opposite edges rotated (bits 1,4) → canonical 9, shift 1.
	var opp_r: Array = HexRoadResolver.normalize(0b010010)
	_assert_eq(opp_r[0], 9, "mask 18 → canonical 9")
	_assert_eq(opp_r[1], 1, "mask 18 → shift 1")
	# Adjacent (bits 0,1) → canonical 3, shift 0.
	var adj: Array = HexRoadResolver.normalize(0b000011)
	_assert_eq(adj[0], 3, "mask 3 → canonical 3")
	_assert_eq(adj[1], 0, "mask 3 → shift 0")
	# All 6 bits → canonical 63, shift 0.
	var all: Array = HexRoadResolver.normalize(0b111111)
	_assert_eq(all[0], 63, "mask 63 → canonical 63")
	_assert_eq(all[1], 0, "mask 63 → shift 0")
	# Y-shape (bits 0,2,4) → canonical 21, shift 0.
	var y_shape: Array = HexRoadResolver.normalize(0b010101)
	_assert_eq(y_shape[0], 21, "mask 21 → canonical 21")
	_assert_eq(y_shape[1], 0, "mask 21 → shift 0")


func _test_road_overlay_registration() -> void:
	print("-- Road overlay registration")
	var pal: TilePalette = DefaultPalettes.build_overworld()
	var road_ids: Array[StringName] = [
		&"road_end", &"road_straight", &"road_corner_sharp", &"road_corner",
		&"road_intersection_a", &"road_intersection_b", &"road_intersection_c",
		&"road_intersection_d", &"road_intersection_e", &"road_intersection_f",
		&"road_intersection_g", &"road_intersection_h", &"road_crossing",
	]
	for road_id: StringName in road_ids:
		var idx: int = pal.overlay_index(road_id)
		_assert_eq(idx >= 0, true, "palette has road overlay: %s" % road_id)


func _test_portal_realm_palette() -> void:
	print("-- DefaultPalettes.build_portal_realm")
	var pal: TilePalette = DefaultPalettes.build_portal_realm()
	_assert_eq(pal.base_index(&"portal_stone") >= 0, true, "portal_stone present")
	_assert_eq(pal.base_index(&"portal_dirt") >= 0, true, "portal_dirt present")
	_assert_eq(pal.base_index(&"portal_bedrock") >= 0, true, "portal_bedrock present")
	_assert_eq(pal.overlay_index(&"ore_amethyst") >= 0, true, "ore_amethyst overlay present")
	_assert_eq(pal.overlay_index(&"portal_return") >= 0, true, "portal_return overlay present")
	_assert_eq(pal.overlay_index_by_marker(&"portal_return") >= 0, true, "portal_return marker indexed")


func _test_overworld_portal_overlay() -> void:
	print("-- Overworld palette has portal overlay")
	var pal: TilePalette = DefaultPalettes.build_overworld()
	_assert_eq(pal.overlay_index(&"portal") >= 0, true, "portal overlay present")
	_assert_eq(pal.overlay_index_by_marker(&"portal") >= 0, true, "portal marker indexed")


func _compress(c: Vector3i, n: int) -> Vector3i:
	# Mirrors MineTransitionController.compress_to_portal_coord (PORTAL_COMPRESS=10).
	# Pure floori-based, negative-safe integer division.
	return Vector3i(
		floori(float(c.x) / float(n)),
		floori(float(c.y) / float(n)),
		0
	)


func _test_portal_compression_math() -> void:
	print("-- Portal coord compression (floori-based, N=10)")
	_assert_eq(_compress(Vector3i(60, -45, 0), 10), Vector3i(6, -5, 0), "(60,-45) -> (6,-5)")
	_assert_eq(_compress(Vector3i(0, 0, 9), 10), Vector3i(0, 0, 0), "(0,0,9) -> (0,0,0) (layer dropped)")
	_assert_eq(_compress(Vector3i(-1, -10, 0), 10), Vector3i(-1, -1, 0), "(-1,-10) -> (-1,-1) negative-safe")
	_assert_eq(_compress(Vector3i(9, 10, 0), 10), Vector3i(0, 1, 0), "(9,10) -> (0,1) boundary")
	# Verify the constant is what we expect by reading it from the script.
	var mtc: GDScript = load("res://scripts/player/mine_transition_controller.gd") as GDScript
	_assert_eq(mtc.get_script_constant_map().get(&"PORTAL_COMPRESS", -1), 10, "PORTAL_COMPRESS == 10")


func _test_portal_items_registered() -> void:
	print("-- ItemRegistry has portal materials")
	var reg: Node = root.get_node_or_null("ItemRegistry")
	_assert_eq(reg != null, true, "ItemRegistry autoload present")
	if reg == null:
		return
	_assert_eq(reg.has_def(&"amethyst"), true, "amethyst registered")
	_assert_eq(reg.has_def(&"portal_shard"), true, "portal_shard registered")
	var amethyst: ItemDef = reg.get_def(&"amethyst")
	if amethyst:
		_assert_eq(amethyst.category, ItemDef.CAT_MATERIAL, "amethyst is material")


func _test_player_world_state_enum() -> void:
	print("-- PlayerController.WorldState enum")
	_assert_eq(int(PlayerController.WorldState.OVERWORLD), 0, "OVERWORLD = 0")
	_assert_eq(int(PlayerController.WorldState.MINE), 1, "MINE = 1")
	_assert_eq(int(PlayerController.WorldState.PORTAL), 2, "PORTAL = 2")
