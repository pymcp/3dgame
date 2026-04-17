class_name MineTransitionController
extends Node

## Tracks per-player mine entry / exit hold-to-interact progress and
## performs the actual enter/exit transitions (teleport + camera swap).
##
## Works with two `HexWorld` instances (overworld + mine). Entry is
## detected by the player standing on an overworld cell whose overlay
## carries the `&"mine_entrance"` marker. Exit is detected by the
## player standing on a mine cell whose overlay carries the
## `&"ladder_up"` marker.

signal player_entered_mine(player: PlayerController)
signal player_exited_mine(player: PlayerController)

const MINE_ENTRY_TIME: float = 1.0
const LADDER_EXIT_TIME: float = 1.0
## Mine spawn cell is (0,0,0); its world center. Offset to the empty
## spawn chamber one layer above the floor.
const MINE_SPAWN_COORD: Vector3i = Vector3i(0, 0, 0)
const OVERWORLD_SPAWN_P1: Vector3 = Vector3(0, 1, 0)
const OVERWORLD_SPAWN_P2: Vector3 = Vector3(3, 1, 0)

const MARKER_MINE_ENTRANCE: StringName = &"mine_entrance"
const MARKER_LADDER_UP: StringName = &"ladder_up"

var _player1: PlayerController
var _player2: PlayerController
var _camera1: IsometricCamera
var _camera2: IsometricCamera
var _overworld: HexWorld
var _mine: HexWorld
var _underground_env: Environment = null

var _mine_entry_progress_p1: float = 0.0
var _mine_entry_progress_p2: float = 0.0
var _ladder_exit_progress_p1: float = 0.0
var _ladder_exit_progress_p2: float = 0.0
## After any transition, require the mine key to be released before
## another transition can start. Prevents "bounce loop": entering the
## mine with F held would land the player on the ladder-up overlay and
## immediately trigger exit, back onto a mine-entrance, and so on.
var _transition_lock_p1: bool = false
var _transition_lock_p2: bool = false


func setup(p1: PlayerController, p2: PlayerController, c1: IsometricCamera, c2: IsometricCamera,
		overworld: HexWorld, mine: HexWorld, ug_env: Environment) -> void:
	_player1 = p1
	_player2 = p2
	_camera1 = c1
	_camera2 = c2
	_overworld = overworld
	_mine = mine
	_underground_env = ug_env


func tick(delta: float) -> void:
	if not _player1.is_underground:
		_check_mine_entrance(_player1, delta)
	else:
		_check_ladder_exit(_player1, delta)

	if not _player2.is_underground:
		_check_mine_entrance(_player2, delta)
	else:
		_check_ladder_exit(_player2, delta)


func get_mine_entry_progress(player_id: int) -> float:
	return clampf(_mine_entry_progress_p1 if player_id == 1 else _mine_entry_progress_p2, 0.0, 1.0)


func get_ladder_exit_progress(player_id: int) -> float:
	return clampf(_ladder_exit_progress_p1 if player_id == 1 else _ladder_exit_progress_p2, 0.0, 1.0)


func _standing_on_marker(world: HexWorld, player: PlayerController, marker: StringName) -> bool:
	if world == null or world.palette == null:
		return false
	var coord: Vector3i = world.world_to_coord(player.global_position)
	# Marker overlays now block movement, so the player can't stand on
	# them. Count any cell within 1 hex of the player (same layer, ±1
	# layer) as "activating" the marker.
	for dy: int in [0, -1, 1]:
		for dq: int in range(-1, 2):
			for dr: int in range(-1, 2):
				var c: Vector3i = Vector3i(coord.x + dq, coord.y + dr, coord.z + dy)
				if HexGrid.axial_distance(Vector2i(coord.x, coord.y), Vector2i(c.x, c.y)) > 1:
					continue
				var cell: HexCell = world.get_cell(c)
				if cell == null or not cell.has_overlay():
					continue
				var ok: OverlayKind = world.palette.overlays[cell.overlay_id]
				if ok != null and ok.marker == marker:
					return true
	return false


func _check_mine_entrance(player: PlayerController, delta: float) -> void:
	var is_p1: bool = player.player_id == 1
	var key_down: bool = InputManager.is_action_pressed(player.player_id, "mine")
	# Clear the post-transition lock once the player lets go.
	if is_p1:
		if _transition_lock_p1 and not key_down:
			_transition_lock_p1 = false
	else:
		if _transition_lock_p2 and not key_down:
			_transition_lock_p2 = false

	var locked: bool = _transition_lock_p1 if is_p1 else _transition_lock_p2
	var on_mine: bool = _standing_on_marker(_overworld, player, MARKER_MINE_ENTRANCE)
	var holding: bool = on_mine and key_down and not locked

	if is_p1:
		if holding:
			_mine_entry_progress_p1 += delta / MINE_ENTRY_TIME
			if _mine_entry_progress_p1 >= 1.0:
				_mine_entry_progress_p1 = 0.0
				_transition_lock_p1 = true
				enter_underground(player)
		else:
			_mine_entry_progress_p1 = 0.0
	else:
		if holding:
			_mine_entry_progress_p2 += delta / MINE_ENTRY_TIME
			if _mine_entry_progress_p2 >= 1.0:
				_mine_entry_progress_p2 = 0.0
				_transition_lock_p2 = true
				enter_underground(player)
		else:
			_mine_entry_progress_p2 = 0.0


func _check_ladder_exit(player: PlayerController, delta: float) -> void:
	var is_p1: bool = player.player_id == 1
	var key_down: bool = InputManager.is_action_pressed(player.player_id, "mine")
	if is_p1:
		if _transition_lock_p1 and not key_down:
			_transition_lock_p1 = false
	else:
		if _transition_lock_p2 and not key_down:
			_transition_lock_p2 = false

	var locked: bool = _transition_lock_p1 if is_p1 else _transition_lock_p2
	var near_ladder: bool = _standing_on_marker(_mine, player, MARKER_LADDER_UP)
	var holding: bool = near_ladder and key_down and not locked

	if is_p1:
		if holding:
			_ladder_exit_progress_p1 += delta / LADDER_EXIT_TIME
			if _ladder_exit_progress_p1 >= 1.0:
				_ladder_exit_progress_p1 = 0.0
				_transition_lock_p1 = true
				exit_underground(player)
		else:
			_ladder_exit_progress_p1 = 0.0
	else:
		if holding:
			_ladder_exit_progress_p2 += delta / LADDER_EXIT_TIME
			if _ladder_exit_progress_p2 >= 1.0:
				_ladder_exit_progress_p2 = 0.0
				_transition_lock_p2 = true
				exit_underground(player)
		else:
			_ladder_exit_progress_p2 = 0.0


func enter_underground(player: PlayerController) -> void:
	var is_p1: bool = player == _player1
	player.is_underground = true
	player.collision_mask = 5
	player.apply_render_layers(4)   # render layer 3 (mine)

	var cam: IsometricCamera = _camera1 if is_p1 else _camera2
	cam.cull_mask = 5
	cam.environment = _underground_env

	# Force-load the spawn chunks first (so the safe-spawn search sees
	# real cells, not unstreamed air), then pick the nearest hex column
	# clear of blocking overlays (the ladder-up marker at the origin
	# now blocks movement). Extra radius hides streaming pop-in as the
	# player looks around.
	var preferred: Vector3 = _mine.coord_to_world(MINE_SPAWN_COORD)
	_mine.prime_around(preferred, 1, 1)
	var spawn: Vector3 = _mine.find_safe_spawn(MINE_SPAWN_COORD)
	player.position = spawn
	player.velocity = Vector3.ZERO
	cam.size = cam.camera_size
	cam.snap_to_target()

	player_entered_mine.emit(player)


func exit_underground(player: PlayerController) -> void:
	var is_p1: bool = player == _player1
	player.is_underground = false
	player.collision_mask = 3
	player.apply_render_layers(2)   # render layer 2 (overworld)

	var cam: IsometricCamera = _camera1 if is_p1 else _camera2
	cam.cull_mask = 3
	cam.environment = null

	var preferred: Vector3 = OVERWORLD_SPAWN_P1 if is_p1 else OVERWORLD_SPAWN_P2
	_overworld.prime_around(preferred, 2, 0)
	# Snap to the nearest hex column clear of blocking overlays (the
	# spawn anchor might sit right on a mine-entrance marker). Search
	# from layer 1 (above the surface) so the "standing cell" candidate
	# is actually the cell the player's feet would occupy.
	var preferred_coord: Vector3i = _overworld.world_to_coord(preferred)
	var spawn: Vector3 = _overworld.find_safe_spawn(
		Vector3i(preferred_coord.x, preferred_coord.y, OverworldHexGenerator.SURFACE_MAX_LAYER + 1)
	)
	player.position = spawn
	player.velocity = Vector3.ZERO
	cam.size = cam.camera_size
	cam.snap_to_target()

	player_exited_mine.emit(player)
