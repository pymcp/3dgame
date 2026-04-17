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

# Per-player state indexed by player_id (1 or 2). Index 0 unused.
var _mine_entry_progress: Array[float] = [0.0, 0.0, 0.0]
var _ladder_exit_progress: Array[float] = [0.0, 0.0, 0.0]
## After any transition, require the mine key to be released before
## another transition can start. Prevents "bounce loop": entering the
## mine with F held would land the player on the ladder-up overlay and
## immediately trigger exit, back onto a mine-entrance, and so on.
var _transition_lock: Array[bool] = [false, false, false]


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
	for player: PlayerController in [_player1, _player2]:
		if player == null:
			continue
		if not player.is_underground:
			_tick_transition(player, delta, _overworld, MARKER_MINE_ENTRANCE,
					_mine_entry_progress, MINE_ENTRY_TIME, enter_underground)
		else:
			_tick_transition(player, delta, _mine, MARKER_LADDER_UP,
					_ladder_exit_progress, LADDER_EXIT_TIME, exit_underground)


func get_mine_entry_progress(player_id: int) -> float:
	return clampf(_mine_entry_progress[player_id], 0.0, 1.0)


func get_ladder_exit_progress(player_id: int) -> float:
	return clampf(_ladder_exit_progress[player_id], 0.0, 1.0)


func _standing_on_marker(world: HexWorld, player: PlayerController, marker: StringName) -> bool:
	if world == null:
		return false
	var coord: Vector3i = world.world_to_coord(player.global_position)
	return world.find_nearby_marker(coord, marker) != HexWorld.NO_COORD


## Shared tick for entry OR exit. `progress` is the 3-element array
## indexed by player_id; `on_complete` is called with the player once
## progress reaches 1.0.
func _tick_transition(player: PlayerController, delta: float, world: HexWorld,
		marker: StringName, progress: Array[float], duration: float,
		on_complete: Callable) -> void:
	var pid: int = player.player_id
	var key_down: bool = InputManager.is_action_pressed(pid, "mine")
	# Clear the post-transition lock once the player lets go.
	if _transition_lock[pid] and not key_down:
		_transition_lock[pid] = false

	var near_marker: bool = _standing_on_marker(world, player, marker)
	var holding: bool = near_marker and key_down and not _transition_lock[pid]

	if holding:
		progress[pid] += delta / duration
		if progress[pid] >= 1.0:
			progress[pid] = 0.0
			_transition_lock[pid] = true
			on_complete.call(player)
	else:
		progress[pid] = 0.0


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
