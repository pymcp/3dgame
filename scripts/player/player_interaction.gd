class_name PlayerInteraction
extends Node3D

## Player's mining + placement interaction. Queries the active
## `HexWorld` (overworld or mine, depending on `player.is_underground`)
## via raycast-from-camera, accumulates damage on the hit cell, and
## calls `HexWorld.mine_cell` once the damage meets hardness.

signal mine_completed(coord: Vector3i, drops: PackedStringArray, dropped_base: bool)

@export var player_id: int = 1
@export var reach_distance: float = 5.0

const HIGHLIGHT_COLOR_P1: Color = Color(1.0, 0.95, 0.2, 0.85)   # yellow
const HIGHLIGHT_COLOR_P2: Color = Color(0.3, 0.7, 1.0, 0.85)    # blue
const HIGHLIGHT_DAMAGED_P1: Color = Color(1.0, 0.25, 0.0, 0.95) # orange
const HIGHLIGHT_DAMAGED_P2: Color = Color(0.9, 0.2, 0.5, 0.95)  # pink
const HIGHLIGHT_COLOR_INTERACT: Color = Color(0.2, 1.0, 0.4, 0.9)
const NO_COORD: Vector3i = Vector3i(-99999, -99999, -99999)

const _HIGHLIGHT_SHADER_PATH: String = "res://assets/shaders/hex_highlight.gdshader"
const _WALL_HIGHLIGHT_SHADER_PATH: String = "res://assets/shaders/wall_highlight.gdshader"
const _MAX_WALL_OFFSET: int = 4  # upper bound for layer cycle

var camera: Camera3D = null
var viewport: SubViewport = null
var overworld: HexWorld = null
var mine: HexWorld = null

var _targeted_coord: Vector3i = NO_COORD
var _is_mining: bool = false
var _mine_progress: float = 0.0
var _mine_target: Vector3i = NO_COORD
var _mine_hardness: float = 1.0
var _highlight_time: float = 0.0
var _highlight_base_color: Color = HIGHLIGHT_COLOR_P1

var _highlight: MeshInstance3D = null
var _highlight_shader_mat: ShaderMaterial = null
var _wall_highlight: MeshInstance3D = null
var _wall_highlight_shader_mat: ShaderMaterial = null
var _crack_overlay: CrackOverlay = null
var _mining_vfx: MiningVFX = null

# Layer cycle offset for mine wall targeting (Q/Z keys).
var _wall_layer_offset: int = 0
var _layer_cycle_active: bool = false  # true after any Q/Z press
var _last_wall_qr: Vector2i = Vector2i(-99999, -99999)
var _wall_targeting_active: bool = false
var _is_wall_target: bool = false


func _default_color() -> Color:
	return HIGHLIGHT_COLOR_P1 if player_id == 1 else HIGHLIGHT_COLOR_P2


func _damaged_color() -> Color:
	return HIGHLIGHT_DAMAGED_P1 if player_id == 1 else HIGHLIGHT_DAMAGED_P2


func set_camera(cam: Camera3D) -> void:
	camera = cam


func set_viewport(vp: SubViewport) -> void:
	viewport = vp


func set_worlds(overworld_world: HexWorld, mine_world: HexWorld) -> void:
	overworld = overworld_world
	mine = mine_world


func _active_world() -> HexWorld:
	var player: PlayerController = get_parent() as PlayerController
	if player != null and player.is_underground:
		return mine
	return overworld


func _ensure_widgets() -> void:
	if _highlight != null:
		return
	_create_highlight()
	_create_wall_highlight()
	_crack_overlay = CrackOverlay.new()
	_crack_overlay.name = "CrackOverlay"
	_crack_overlay.top_level = true
	add_child(_crack_overlay)
	_mining_vfx = MiningVFX.new()
	_mining_vfx.name = "MiningVFX"
	add_child(_mining_vfx)
	_sync_widget_render_layers()


func _create_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	var diameter: float = HexGrid.HEX_SIZE * 2.5
	plane.size = Vector2(diameter, diameter)
	_highlight.mesh = plane
	var shader: Shader = load(_HIGHLIGHT_SHADER_PATH) as Shader
	_highlight_shader_mat = ShaderMaterial.new()
	_highlight_shader_mat.shader = shader
	_highlight_shader_mat.set_shader_parameter("highlight_color", _default_color())
	_highlight_shader_mat.set_shader_parameter("pulse_time", 0.0)
	# Exact hex_radius so the ring matches the tile circumradius.
	var hex_r: float = HexGrid.HEX_SIZE / (diameter * 0.5)
	_highlight_shader_mat.set_shader_parameter("hex_radius", hex_r)
	_highlight_shader_mat.render_priority = 1
	_highlight.material_override = _highlight_shader_mat
	_highlight.visible = false
	_highlight.top_level = true
	add_child(_highlight)


func _create_wall_highlight() -> void:
	_wall_highlight = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	# Slightly oversized so the border/glow covers the wall face edges.
	plane.size = Vector2(HexGrid.HEX_SIZE * 1.15, HexWorldChunk.LAYER_HEIGHT * 1.4)
	_wall_highlight.mesh = plane
	var shader: Shader = load(_WALL_HIGHLIGHT_SHADER_PATH) as Shader
	_wall_highlight_shader_mat = ShaderMaterial.new()
	_wall_highlight_shader_mat.shader = shader
	_wall_highlight_shader_mat.set_shader_parameter("highlight_color", _default_color())
	_wall_highlight_shader_mat.set_shader_parameter("pulse_time", 0.0)
	_wall_highlight_shader_mat.render_priority = 1
	_wall_highlight.material_override = _wall_highlight_shader_mat
	_wall_highlight.visible = false
	_wall_highlight.top_level = true
	add_child(_wall_highlight)


func _process(delta: float) -> void:
	var world: HexWorld = _active_world()
	if world == null or camera == null:
		if _highlight:
			_highlight.visible = false
		if _crack_overlay:
			_crack_overlay.reset()
		return
	_ensure_widgets()
	_sync_widget_render_layers()
	_handle_layer_cycle_input()
	_update_target(world)
	_update_mining(world, delta)
	_update_highlight_pulse(delta)


func _update_target(world: HexWorld) -> void:
	var player: PlayerController = get_parent() as PlayerController
	if player == null:
		_clear_target()
		return

	var player_coord: Vector3i = world.world_to_coord(player.global_position)

	# Priority 1: Nearby interactable marker (mine entrance, ladder).
	var marker_coord: Vector3i = _find_nearby_marker(world, player_coord)
	if marker_coord != NO_COORD:
		_set_target_coord(world, marker_coord, true)
		return

	# Priority 2: Screen-center raycast (overlays, terrain).
	var raycast_coord: Vector3i = _do_raycast(world)

	# Priority 3: Prefer the adjacent cell the player faces over the tile
	# directly below. Works in both worlds — lets the player target
	# overlays / walls in front of them instead of the floor.
	var facing_coord: Vector3i = _find_facing_cell(world, player_coord, player)
	if facing_coord != NO_COORD:
		# Use facing cell when: user explicitly cycled (Q/Z pressed),
		# raycast found nothing, or raycast only found the floor.
		if _layer_cycle_active or raycast_coord == NO_COORD or raycast_coord.z < player_coord.z:
			_wall_targeting_active = true
			_set_target_coord(world, facing_coord, false)
			return

	# Facing-cell targeting not used this frame.
	if _wall_targeting_active:
		_wall_targeting_active = false
		# Don't reset _wall_layer_offset here — it persists until
		# the player moves to a new hex column or leaves the mine.

	if raycast_coord != NO_COORD:
		_set_target_coord(world, raycast_coord, false)
	else:
		_clear_target()


func _find_nearby_marker(world: HexWorld, player_coord: Vector3i) -> Vector3i:
	if world.palette == null:
		return NO_COORD
	for dy: int in [0, -1, 1]:
		for dq: int in range(-1, 2):
			for dr: int in range(-1, 2):
				if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) > 1:
					continue
				var c: Vector3i = Vector3i(player_coord.x + dq, player_coord.y + dr, player_coord.z + dy)
				var cell: HexCell = world.get_cell(c)
				if cell == null or not cell.has_overlay():
					continue
				if cell.overlay_id < 0 or cell.overlay_id >= world.palette.overlays.size():
					continue
				var ok: OverlayKind = world.palette.overlays[cell.overlay_id]
				if ok != null and ok.marker != &"":
					return c
	return NO_COORD


func _find_facing_cell(world: HexWorld, player_coord: Vector3i, player: PlayerController) -> Vector3i:
	## Pick the adjacent solid cell the player is facing. Works in both
	## worlds so the player naturally targets tiles in front of them
	## rather than the floor beneath.
	var facing_dir: Vector2 = Vector2(
		sin(player.model.rotation.y), cos(player.model.rotation.y)
	)
	var best: Vector3i = NO_COORD
	var best_dot: float = 0.3  # ~70° arc threshold
	# In the mine, allow layer-cycle offset; on the overworld scan only
	# the player's own layer and one below (terrain + overlays).
	var layers_to_check: Array[int] = []
	if player.is_underground:
		layers_to_check.append(player_coord.z + _wall_layer_offset)
	else:
		layers_to_check.append(player_coord.z)
		layers_to_check.append(player_coord.z - 1)

	# Offset -1 = "floor mode": return ONLY the tile directly beneath
	# the player, skip all adjacent walls.
	if _wall_layer_offset < 0:
		for target_layer: int in layers_to_check:
			var c: Vector3i = Vector3i(player_coord.x, player_coord.y, target_layer)
			if world.has_cell(c):
				return c
		return NO_COORD

	for target_layer: int in layers_to_check:
		for dq: int in range(-1, 2):
			for dr: int in range(-1, 2):
				if dq == 0 and dr == 0:
					continue
				if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) > 1:
					continue
				var c: Vector3i = Vector3i(player_coord.x + dq, player_coord.y + dr, target_layer)
				if not world.has_cell(c):
					continue
				var xz: Vector3 = HexGrid.axial_to_world(dq, dr)
				var cell_dir: Vector2 = Vector2(xz.x, xz.z).normalized()
				var dot: float = facing_dir.dot(cell_dir)
				if dot > best_dot:
					best_dot = dot
					best = c
	return best


func _do_raycast(world: HexWorld) -> Vector3i:
	var screen_pos: Vector2
	if viewport:
		screen_pos = Vector2(viewport.size) / 2.0
	else:
		screen_pos = get_viewport().get_visible_rect().size / 2.0

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return NO_COORD

	var mask: int = 2 if world == overworld else 4
	var ray_length: float = reach_distance * 6.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * ray_length, mask
	)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return NO_COORD

	var hit_pos: Vector3 = result["position"] as Vector3
	var normal: Vector3 = result["normal"] as Vector3
	var inside: Vector3 = hit_pos - normal * (HexWorldChunk.LAYER_HEIGHT * 0.25)
	var coord: Vector3i = world.world_to_coord(inside)

	if not world.has_cell(coord):
		for dz: int in range(1, 5):
			var lower: Vector3i = Vector3i(coord.x, coord.y, coord.z - dz)
			if world.has_cell(lower):
				return lower
		return NO_COORD

	return coord


func _set_target_coord(world: HexWorld, coord: Vector3i, is_interactable: bool) -> void:
	# Determine whether this is a wall face or a floor/top target.
	# Same-column targets (floor beneath player) use the flat hex ring.
	var player: PlayerController = get_parent() as PlayerController
	var is_same_column: bool = false
	if player:
		var pc: Vector3i = world.world_to_coord(player.global_position)
		is_same_column = (coord.x == pc.x and coord.y == pc.y)
	var wall_mode: bool = _wall_targeting_active and not is_interactable and not is_same_column
	if coord != _targeted_coord or wall_mode != _is_wall_target:
		_targeted_coord = coord
		_is_wall_target = wall_mode
		var cell_origin: Vector3 = world.coord_to_world(coord)

		if wall_mode and _wall_highlight != null:
			# Position the wall highlight on the face between player and target,
			# nudged slightly toward the player to avoid z-fighting.
			if player:
				var player_coord: Vector3i = world.world_to_coord(player.global_position)
				var target_xz: Vector3 = HexGrid.axial_to_world(coord.x, coord.y)
				var player_xz: Vector3 = HexGrid.axial_to_world(player_coord.x, player_coord.y)
				var mid_xz: Vector3 = (target_xz + player_xz) * 0.5
				var wall_y: float = cell_origin.y + HexWorldChunk.LAYER_HEIGHT * 0.5
				# Orient the PlaneMesh vertically: local X → wall-right,
				# local Y → toward player (normal), local Z → world UP.
				var to_player: Vector3 = player_xz - target_xz
				to_player.y = 0.0
				if to_player.length_squared() > 0.001:
					to_player = to_player.normalized()
					# Nudge 2 cm toward player to avoid z-fighting with wall geometry.
					mid_xz += to_player * 0.02
					var wall_right: Vector3 = to_player.cross(Vector3.UP).normalized()
					_wall_highlight.global_basis = Basis(wall_right, to_player, Vector3.UP)
				_wall_highlight.global_position = Vector3(mid_xz.x, wall_y, mid_xz.z)
			_wall_highlight.visible = true
			_highlight.visible = false
		else:
			# Flat ring just above the top surface of the tile.
			_highlight.global_position = cell_origin + Vector3(0.0, HexWorldChunk.LAYER_HEIGHT + 0.005, 0.0)
			_highlight.visible = true
			if _wall_highlight:
				_wall_highlight.visible = false

		_crack_overlay.global_position = cell_origin + Vector3(0.0, HexWorldChunk.LAYER_HEIGHT * 0.5, 0.0)
		if is_interactable:
			_highlight_base_color = HIGHLIGHT_COLOR_INTERACT
			_crack_overlay.reset()
		else:
			var existing: float = world.get_damage(coord)
			var hardness: float = world.cell_hardness(coord)
			_apply_damage_visual(existing, hardness)


func _clear_target() -> void:
	if _targeted_coord == NO_COORD:
		return
	_targeted_coord = NO_COORD
	_is_wall_target = false
	if _highlight:
		_highlight.visible = false
	if _wall_highlight:
		_wall_highlight.visible = false
	if _crack_overlay:
		_crack_overlay.reset()
	_highlight_base_color = _default_color()


func _apply_damage_visual(damage: float, hardness: float) -> void:
	if hardness <= 0.0 or damage <= 0.0:
		_crack_overlay.reset()
		_highlight_base_color = _default_color()
		return
	var progress: float = clampf(damage / hardness, 0.0, 1.0)
	_crack_overlay.set_progress(progress)
	_highlight_base_color = _default_color().lerp(_damaged_color(), progress)


func _update_mining(world: HexWorld, delta: float) -> void:
	if not InputManager.is_action_pressed(player_id, "mine"):
		if _is_mining:
			_is_mining = false
			_mining_vfx.stop()
			var player: PlayerController = get_parent() as PlayerController
			if player:
				player.stop_mine_anim()
		return

	if _targeted_coord == NO_COORD:
		return

	var hardness: float = world.cell_hardness(_targeted_coord)
	if hardness <= 0.0 or hardness >= 900.0:
		# Unmineable (e.g. bedrock, mine entrance markers).
		return

	if not _is_mining or _mine_target != _targeted_coord:
		_is_mining = true
		_mine_target = _targeted_coord
		_mine_hardness = hardness
		_mine_progress = world.get_damage(_targeted_coord)
		var center: Vector3 = world.coord_to_world(_mine_target) + Vector3(0.0, HexWorldChunk.LAYER_HEIGHT * 0.5, 0.0)
		var player: PlayerController = get_parent() as PlayerController
		if player:
			player.face_target(center)
			player.play_mine_anim()
		_mining_vfx.start(center, Color(1, 1, 1))

	_mine_progress += delta
	world.set_damage(_mine_target, _mine_progress)
	_apply_damage_visual(_mine_progress, _mine_hardness)

	if _mine_progress >= _mine_hardness:
		var center: Vector3 = world.coord_to_world(_mine_target) + Vector3(0.0, HexWorldChunk.LAYER_HEIGHT * 0.5, 0.0)
		_mining_vfx.stop()
		_mining_vfx.burst(center, Color(1, 1, 1))
		var result: HexWorld.MineResult = world.mine_cell(_mine_target)
		if result.changed:
			mine_completed.emit(_mine_target, result.drops, result.dropped_base)
		_is_mining = false
		_mine_progress = 0.0
		_targeted_coord = NO_COORD
		if _highlight:
			_highlight.visible = false
		_crack_overlay.reset()
		_highlight_base_color = _default_color()
		var player: PlayerController = get_parent() as PlayerController
		if player:
			player.stop_mine_anim()


func get_mine_progress() -> float:
	if not _is_mining or _mine_hardness <= 0.0:
		return 0.0
	return clampf(_mine_progress / _mine_hardness, 0.0, 1.0)


## Expose the currently targeted cell to outside systems (e.g. the
## mine-transition controller uses this to detect pointing at a mine
## entrance).
func get_targeted_coord() -> Vector3i:
	return _targeted_coord


func has_target() -> bool:
	return _targeted_coord != NO_COORD


func _handle_layer_cycle_input() -> void:
	var player: PlayerController = get_parent() as PlayerController
	if player == null or not player.is_underground:
		if _wall_layer_offset != 0:
			_wall_layer_offset = 0
			_layer_cycle_active = false
		return
	# Reset when the player moves to a new hex column (before key
	# processing so a simultaneous key press overrides the reset).
	var world: HexWorld = _active_world()
	if world != null:
		var pc: Vector3i = world.world_to_coord(player.global_position)
		var current_qr: Vector2i = Vector2i(pc.x, pc.y)
		if current_qr != _last_wall_qr:
			_last_wall_qr = current_qr
			_wall_layer_offset = 0
			_layer_cycle_active = false
	var direction: int = 0
	if InputManager.is_action_just_pressed(player_id, "target_up"):
		direction = 1
	elif InputManager.is_action_just_pressed(player_id, "target_down"):
		direction = -1
	if direction != 0 and world != null:
		_layer_cycle_active = true
		var pc: Vector3i = world.world_to_coord(player.global_position)
		# Cycle through offsets, skipping any that have no valid cells.
		var total_steps: int = _MAX_WALL_OFFSET + 2  # -1 through MAX
		for _attempt: int in total_steps:
			_wall_layer_offset = _wrap_offset(_wall_layer_offset + direction)
			if _offset_has_target(world, pc, player):
				break


func _wrap_offset(raw: int) -> int:
	if raw > _MAX_WALL_OFFSET:
		return -1
	if raw < -1:
		return _MAX_WALL_OFFSET
	return raw


func _offset_has_target(world: HexWorld, player_coord: Vector3i, player: PlayerController) -> bool:
	## Quick check: does the current _wall_layer_offset have any valid
	## cell the player could target?
	var target_layer: int = player_coord.z + _wall_layer_offset
	if _wall_layer_offset < 0:
		# Floor mode: check player's own column.
		return world.has_cell(Vector3i(player_coord.x, player_coord.y, target_layer))
	# Wall mode: check any adjacent cell at this layer.
	var facing_dir: Vector2 = Vector2(
		sin(player.model.rotation.y), cos(player.model.rotation.y)
	)
	for dq: int in range(-1, 2):
		for dr: int in range(-1, 2):
			if dq == 0 and dr == 0:
				continue
			if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) > 1:
				continue
			var c: Vector3i = Vector3i(player_coord.x + dq, player_coord.y + dr, target_layer)
			if world.has_cell(c):
				return true
	return false


func _update_highlight_pulse(delta: float) -> void:
	if _highlight_shader_mat == null:
		return
	var any_visible: bool = (_highlight != null and _highlight.visible) or (_wall_highlight != null and _wall_highlight.visible)
	if not any_visible:
		_highlight_time = 0.0
		return
	_highlight_time += delta
	_highlight_shader_mat.set_shader_parameter("highlight_color", _highlight_base_color)
	_highlight_shader_mat.set_shader_parameter("pulse_time", _highlight_time)
	if _wall_highlight_shader_mat:
		_wall_highlight_shader_mat.set_shader_parameter("highlight_color", _highlight_base_color)
		_wall_highlight_shader_mat.set_shader_parameter("pulse_time", _highlight_time)


func _sync_widget_render_layers() -> void:
	var player: PlayerController = get_parent() as PlayerController
	if player == null:
		return
	# Match the player's current render layer bitmask so the highlight,
	# crack overlay, and VFX are visible on the correct camera.
	var bitmask: int = 2 if not player.is_underground else 4
	if _highlight:
		_highlight.layers = bitmask
	if _wall_highlight:
		_wall_highlight.layers = bitmask
	if _crack_overlay:
		_crack_overlay.layers = bitmask
	if _mining_vfx:
		_set_render_layers_recursive(_mining_vfx, bitmask)


func _set_render_layers_recursive(node: Node, bitmask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = bitmask
	for child: Node in node.get_children():
		_set_render_layers_recursive(child, bitmask)
