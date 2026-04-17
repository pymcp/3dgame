extends Node

## Main scene: wires up the split-screen viewports, world, players,
## UI, and transitions. The world is now two `HexWorld` instances
## (overworld + mine) sharing the same `World3D`, both driven by the
## same class but with different palettes + generators + render
## layers.

@onready var viewport_p1: SubViewport = $HBoxContainer/SubViewportContainer_P1/SubViewport_P1
@onready var viewport_p2: SubViewport = $HBoxContainer/SubViewportContainer_P2/SubViewport_P2
@onready var viewport_container_p1: SubViewportContainer = $HBoxContainer/SubViewportContainer_P1
@onready var viewport_container_p2: SubViewportContainer = $HBoxContainer/SubViewportContainer_P2

const OVERWORLD_RENDER_BIT: int = 2   # bit 1 → layer 2
const MINE_RENDER_BIT: int = 4        # bit 2 → layer 3
const OVERWORLD_COLLISION_LAYER: int = 2  # bitmask: bit 1 → physics layer 2
const MINE_COLLISION_LAYER: int = 4       # bitmask: bit 2 → physics layer 3
const OVERWORLD_CAM_MASK: int = 3     # layers 1 + 2
const MINE_CAM_MASK: int = 5          # layers 1 + 3

var world: Node3D
var overworld: HexWorld
var mine: HexWorld

var player1: PlayerController
var player2: PlayerController
var camera1: IsometricCamera
var camera2: IsometricCamera

var inventory_ui_p1: InventoryUI
var inventory_ui_p2: InventoryUI
var mining_ui_p1: MiningProgressUI
var mining_ui_p2: MiningProgressUI

var tile_placer: TilePlacer
var pause_menu: PauseMenu
var transitions: MineTransitionController

var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _underground_env: Environment

var _p1_enabled: bool = true
var _p2_enabled: bool = true


func _ready() -> void:
	_setup_world()
	_setup_worlds()
	_setup_players()
	_setup_viewports()
	_setup_ui()
	_wire_interactions()
	_setup_transitions()
	_setup_decorations()
	_setup_tile_placer()
	_setup_pause_menu()


func _setup_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.6, 0.8)
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.4
	env.tonemap_mode = 3  # ACES
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	world.add_child(_world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-45, 45, 0)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.light_cull_mask = OVERWORLD_CAM_MASK
	world.add_child(_sun)

	# Safety net so players don't fall forever past the streamed area.
	# Placed at the same depth as the mine's bedrock layer so a player
	# who mines a surface tile falls through it and lands at a
	# consistent "deep ground" height — matching the mine's feel of
	# hex tiles having real depth.
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "GroundPlane"
	ground.collision_layer = OVERWORLD_COLLISION_LAYER
	var ground_collision: CollisionShape3D = CollisionShape3D.new()
	var shape: WorldBoundaryShape3D = WorldBoundaryShape3D.new()
	ground_collision.shape = shape
	ground_collision.position = Vector3(0, (OverworldHexGenerator.BEDROCK_LAYER - 1) * HexWorldChunk.LAYER_HEIGHT, 0)
	ground.add_child(ground_collision)
	world.add_child(ground)

	# Underground environment (assigned as camera override per-player).
	_underground_env = Environment.new()
	_underground_env.background_mode = Environment.BG_COLOR
	_underground_env.background_color = Color(0.02, 0.02, 0.05)
	_underground_env.ambient_light_color = Color.WHITE
	_underground_env.ambient_light_energy = 0.1
	_underground_env.tonemap_mode = 3  # ACES


func _setup_worlds() -> void:
	# Overworld HexWorld.
	overworld = HexWorld.new()
	overworld.name = "Overworld"
	overworld.render_layer_bit = OVERWORLD_RENDER_BIT
	overworld.collision_layer = OVERWORLD_COLLISION_LAYER
	# Overworld surface ranges from layer -3 (seabed) to +9 (mountains),
	# with bedrock at -20. Bump vertical stream radius so the surface is
	# fully covered whenever the player is near it.
	overworld.load_radius_layer = 3
	overworld.unload_radius_layer = 4
	world.add_child(overworld)
	var ow_palette: TilePalette = DefaultPalettes.build_overworld()
	var ow_gen: OverworldHexGenerator = OverworldHexGenerator.new(GameManager.world_seed)
	overworld.setup(ow_palette, ow_gen)

	# Mine HexWorld.
	mine = HexWorld.new()
	mine.name = "Mine"
	mine.render_layer_bit = MINE_RENDER_BIT
	mine.collision_layer = MINE_COLLISION_LAYER
	mine.load_radius_qr = 2
	mine.load_radius_layer = 2
	mine.chunk_size_layer = 4
	world.add_child(mine)
	var mine_palette: TilePalette = DefaultPalettes.build_mine()
	var mine_gen: MineHexGenerator = MineHexGenerator.new(GameManager.world_seed + 7919)
	mine.setup(mine_palette, mine_gen)


func _setup_players() -> void:
	var skins: Array[String] = InputManager.get_random_skins()
	# Prime a generous area around the spawn zone BEFORE placing the
	# players. This guarantees floor + collision is ready (no falling
	# through) and reduces visible pop-in while they look around for
	# the first time.
	overworld.prime_around(Vector3.ZERO, 2, 0)   # load_radius_qr + 2 rings
	# Resolve initial spawn positions through the same safe-spawn API
	# used for transitions, so launch-time spawn points don't land
	# inside water / blocking overlays / unstreamed air. Start the
	# search well above the tallest possible surface so the down-scan
	# lands on the real surface layer.
	var top: int = OverworldHexGenerator.SURFACE_MAX_LAYER + 1
	var p1_spawn: Vector3 = overworld.find_safe_spawn(Vector3i(0, 0, top))
	var p2_spawn: Vector3 = overworld.find_safe_spawn(Vector3i(3, 0, top))
	player1 = PlayerFactory.build(1, skins[0], p1_spawn)
	player2 = PlayerFactory.build(2, skins[1], p2_spawn)
	world.add_child(player1)
	world.add_child(player2)
	# Start both players on the overworld render layer so each player's
	# camera only renders players in the same world (mine cam has cull
	# mask 5 = layers 1+3; overworld cam has 3 = layers 1+2).
	player1.apply_render_layers.call_deferred(2)
	player2.apply_render_layers.call_deferred(2)


func _setup_viewports() -> void:
	var shared_world_3d: World3D = world.get_world_3d()
	viewport_p1.world_3d = shared_world_3d
	viewport_p2.world_3d = shared_world_3d

	camera1 = IsometricCamera.new()
	camera1.name = "Camera_P1"
	camera1.cull_mask = OVERWORLD_CAM_MASK
	viewport_p1.add_child(camera1)
	camera1.set_target_node(player1)
	camera1.current = true

	camera2 = IsometricCamera.new()
	camera2.name = "Camera_P2"
	camera2.cull_mask = OVERWORLD_CAM_MASK
	viewport_p2.add_child(camera2)
	camera2.set_target_node(player2)
	camera2.current = true


func _setup_ui() -> void:
	var inv1: Inventory = player1.get_node("Inventory") as Inventory
	var inv2: Inventory = player2.get_node("Inventory") as Inventory
	var int1: PlayerInteraction = player1.get_node("Interaction") as PlayerInteraction
	var int2: PlayerInteraction = player2.get_node("Interaction") as PlayerInteraction
	_setup_player_ui(viewport_p1, 1, inv1, int1)
	_setup_player_ui(viewport_p2, 2, inv2, int2)


func _setup_player_ui(vp: SubViewport, id: int, inv: Inventory, interact: PlayerInteraction) -> void:
	var ui_root: Control = Control.new()
	ui_root.name = "UI_P%d" % id
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(ui_root)

	var label: Label = Label.new()
	label.text = "P%d" % id
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(10, 10)
	ui_root.add_child(label)

	var controls: Label = Label.new()
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	controls.position = Vector2(10, 38)
	var move_hint: String = _movement_hint(id)
	var mine_hint: String = InputManager.get_action_hint(id, "mine")
	var inv_hint: String = InputManager.get_action_hint(id, "inventory")
	controls.text = "%s  Move\n%s  Mine\n%s  Inventory" % [move_hint, mine_hint, inv_hint]
	ui_root.add_child(controls)

	var inv_ui: InventoryUI = InventoryUI.new()
	inv_ui.player_id = id
	inv_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(inv_ui)
	inv_ui.set_inventory.call_deferred(inv)
	if id == 1:
		inventory_ui_p1 = inv_ui
	else:
		inventory_ui_p2 = inv_ui

	var mine_ui: MiningProgressUI = MiningProgressUI.new()
	mine_ui.player_id = id
	mine_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(mine_ui)
	mine_ui.set_interaction.call_deferred(interact)
	if id == 1:
		mining_ui_p1 = mine_ui
	else:
		mining_ui_p2 = mine_ui


## Compact label for the 4 movement actions. Collapses "W A S D" →
## "WASD", "Up Down Left Right" → "Arrows", and adds a "/ L-Stick"
## suffix if any of the move actions is also bound to a gamepad stick.
func _movement_hint(id: int) -> String:
	var keys: Array[String] = []
	var has_stick: bool = false
	for action: String in ["move_up", "move_left", "move_down", "move_right"]:
		var full: String = "p%d_%s" % [id, action]
		if not InputMap.has_action(full):
			continue
		for ev: InputEvent in InputMap.action_get_events(full):
			if ev is InputEventKey:
				var key: InputEventKey = ev as InputEventKey
				var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
				if code != 0:
					keys.append(OS.get_keycode_string(code))
			elif ev is InputEventJoypadMotion:
				has_stick = true
	var label: String = ""
	if keys.size() == 4:
		var joined: String = "".join(keys)
		if joined == "WASD":
			label = "WASD"
		elif keys[0] == "Up" and keys[1] == "Left" and keys[2] == "Down" and keys[3] == "Right":
			label = "Arrows"
		else:
			label = "/".join(keys)
	elif keys.size() > 0:
		label = "/".join(keys)
	if has_stick:
		label = (label + " / L-Stick") if label != "" else "L-Stick"
	return label


func _wire_interactions() -> void:
	var int1: PlayerInteraction = player1.get_node("Interaction") as PlayerInteraction
	var int2: PlayerInteraction = player2.get_node("Interaction") as PlayerInteraction
	int1.set_camera(camera1)
	int1.set_viewport(viewport_p1)
	int1.set_worlds(overworld, mine)
	int2.set_camera(camera2)
	int2.set_viewport(viewport_p2)
	int2.set_worlds(overworld, mine)
	int1.mine_completed.connect(_on_mine_completed.bind(1))
	int2.mine_completed.connect(_on_mine_completed.bind(2))


func _setup_transitions() -> void:
	transitions = MineTransitionController.new()
	transitions.name = "MineTransitionController"
	add_child(transitions)
	transitions.setup(player1, player2, camera1, camera2, overworld, mine, _underground_env)
	if mining_ui_p1:
		mining_ui_p1.set_mine_entry_progress_getter(get_mine_entry_progress_p1)
		mining_ui_p1.set_ladder_exit_progress_getter(get_ladder_exit_progress_p1)
	if mining_ui_p2:
		mining_ui_p2.set_mine_entry_progress_getter(get_mine_entry_progress_p2)
		mining_ui_p2.set_ladder_exit_progress_getter(get_ladder_exit_progress_p2)


func _setup_decorations() -> void:
	# Place the underground spawn-chamber decorator (ladder, campfire,
	# chest, lanterns). Overworld entrances can be decorated on
	# demand when the generator places one — for now, just the mine.
	var mine_deco: HexDecorator = DefaultDecorators.build_mine_spawn_chamber()
	HexDecoratorNode.apply(mine, Vector3i(0, 0, 0), mine_deco)


func _setup_tile_placer() -> void:
	tile_placer = TilePlacer.new()
	tile_placer.name = "TilePlacer"
	add_child(tile_placer)


func _setup_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.player_toggled.connect(_on_player_toggled)


## Hide the player's viewport container and suspend their node so
## the other player expands to fill the screen.
func _set_player_enabled(player_id: int, enabled: bool) -> void:
	var container: SubViewportContainer = viewport_container_p1 if player_id == 1 else viewport_container_p2
	var vp: SubViewport = viewport_p1 if player_id == 1 else viewport_p2
	var player: PlayerController = player1 if player_id == 1 else player2
	if container != null:
		container.visible = enabled
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled \
			else SubViewport.UPDATE_DISABLED
	if player != null:
		player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		player.visible = enabled
	if player_id == 1:
		_p1_enabled = enabled
	else:
		_p2_enabled = enabled


func _on_player_toggled(player_id: int, enabled: bool) -> void:
	_set_player_enabled(player_id, enabled)


func _process(delta: float) -> void:
	# Stream each world only for the players currently in it (and enabled).
	var ow_players: Array[Node3D] = []
	var mine_players: Array[Node3D] = []
	if _p1_enabled:
		if not player1.is_underground:
			ow_players.append(player1)
		else:
			mine_players.append(player1)
	if _p2_enabled:
		if not player2.is_underground:
			ow_players.append(player2)
		else:
			mine_players.append(player2)
	overworld.set_active_players(ow_players)
	mine.set_active_players(mine_players)

	# Drive the tile occlusion cutout around each player. When a player
	# is disabled, mark their slot inactive so the shader skips them.
	TileOcclusion.update_players(
		player1.global_position, _p1_enabled,
		player2.global_position, _p2_enabled,
	)

	transitions.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_ESCAPE and not pause_menu.visible:
			pause_menu.set_player_states(_p1_enabled, _p2_enabled)
			pause_menu.show_menu()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F9:
			_magic_drop_mine_entrance()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEUP:
			_change_player_size(0.005)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEDOWN:
			_change_player_size(-0.005)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_HOME:
			_change_overlay_scale(0.1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_END:
			_change_overlay_scale(-0.1)
			get_viewport().set_input_as_handled()


## Debug: adjust both players' size (and camera zoom) by `delta`, then
## toast the new value. Bound to PgUp / PgDn.
func _change_player_size(delta: float) -> void:
	if player1 == null:
		return
	var new_size: float = clampf(player1.player_size + delta, 0.005, 1.0)
	player1.set_player_size(new_size)
	player2.set_player_size(new_size)
	camera1.set_zoom_from_player_size(new_size)
	camera2.set_zoom_from_player_size(new_size)
	Toast.push("Scale: %.3f" % new_size)


## Debug: adjust the global overlay scale multiplier (trees, rocks,
## ores — base tiles unaffected) by `delta` and rebuild visuals on both
## worlds. Bound to Home / End.
func _change_overlay_scale(delta: float) -> void:
	var new_scale: float = clampf(HexWorldChunk.overlay_scale_multiplier + delta, 0.1, 8.0)
	overworld.set_overlay_scale(new_scale)
	mine.set_overlay_scale(new_scale)
	Toast.push("Overlay scale: %.2f" % new_scale)


## Debug: drop a mine-entrance overlay from the sky onto an overworld
## cell near the active player. Triggered by F9.
func _magic_drop_mine_entrance() -> void:
	# Pick an anchor player who's on the surface (prefer P1).
	var anchor: PlayerController = null
	if _p1_enabled and not player1.is_underground:
		anchor = player1
	elif _p2_enabled and not player2.is_underground:
		anchor = player2
	if anchor == null:
		return

	# Target hex: a few tiles to the east of the anchor, on layer 0.
	var anchor_pos: Vector3 = anchor.global_position + Vector3(2.5, 0.0, 0.0)
	var anchor_coord: Vector3i = overworld.world_to_coord(anchor_pos)
	var target_coord: Vector3i = Vector3i(anchor_coord.x, anchor_coord.y, 0)

	# Force the target chunk to load synchronously — otherwise the
	# place_base/place_overlay calls below silently no-op and the
	# dropped building visibly disappears when the sky-fall node frees.
	var target_world_lookup: Vector3 = overworld.coord_to_world(target_coord)
	overworld.prime_around(target_world_lookup)

	# Make sure the base at the target supports the mine-entrance overlay
	# (mine_entrance requires stone/dirt/grass). Replace the base with
	# stone when it's anything else (water, sand, etc.).
	var stone_idx: int = overworld.palette.base_index(&"stone")
	var existing_base: HexCell = overworld.get_cell(target_coord)
	if existing_base == null:
		if stone_idx >= 0:
			overworld.place_base(target_coord, stone_idx)
	else:
		var base_tk: TileKind = overworld.palette.bases[existing_base.base_id]
		var allows_entrance: bool = base_tk != null and base_tk.id in [&"stone", &"dirt", &"grass"]
		if not allows_entrance and stone_idx >= 0:
			existing_base.base_id = stone_idx
			existing_base.overlay_id = -1
			overworld.set_cell(target_coord, existing_base)

	# Strip any existing overlay so place_overlay can succeed.
	var existing: HexCell = overworld.get_cell(target_coord)
	if existing != null and existing.has_overlay():
		existing.overlay_id = -1
		overworld.set_cell(target_coord, existing)

	var target_world: Vector3 = overworld.coord_to_world(target_coord)
	# Kenney hex-building GLBs are complete hex tiles (their own base +
	# structure on top). The MMI renders them with the mesh bottom at
	# the layer's world-y (no extra offset), so the sky-fall must land
	# at that same y — otherwise the bottom portion of the mesh pops
	# down into the stone base when the sky-fall node frees, making
	# it look like "part of the tile disappeared."

	var mine_scene: PackedScene = load("res://assets/hex_tiles/building-mine.glb") as PackedScene
	if mine_scene == null:
		push_warning("F9: could not load building-mine.glb")
		return

	var overlay_idx: int = overworld.palette.overlay_index_by_marker(&"mine_entrance")
	if overlay_idx < 0:
		push_warning("F9: no mine_entrance overlay in overworld palette")
		return

	tile_placer.place_magic(
		mine_scene,
		target_world,
		null,
		func() -> void: overworld.place_overlay(target_coord, overlay_idx),
	)


func _on_mine_completed(coord: Vector3i, drops: PackedStringArray, dropped_base: bool, player_id: int) -> void:
	# Award drops to the mining player's inventory.
	var player: PlayerController = player1 if player_id == 1 else player2
	var inv: Inventory = player.get_node("Inventory") as Inventory
	if inv != null:
		for item: String in drops:
			inv.add_item(item, 1)
	var cam: IsometricCamera = camera1 if player_id == 1 else camera2
	if cam != null:
		cam.shake(0.08, 0.05)


# Progress-getter adapters for MiningProgressUI (Callable-bound at _ready).
func get_mine_entry_progress_p1() -> float:
	return transitions.get_mine_entry_progress(1)


func get_mine_entry_progress_p2() -> float:
	return transitions.get_mine_entry_progress(2)


func get_ladder_exit_progress_p1() -> float:
	return transitions.get_ladder_exit_progress(1)


func get_ladder_exit_progress_p2() -> float:
	return transitions.get_ladder_exit_progress(2)
