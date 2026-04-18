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
signal player_entered_portal(player: PlayerController)
signal player_exited_portal(player: PlayerController)

const MINE_ENTRY_TIME: float = 1.0
const LADDER_EXIT_TIME: float = 1.0
const PORTAL_ENTRY_TIME: float = 1.0
const PORTAL_EXIT_TIME: float = 1.0
## Mine spawn cell is (0,0,0); its world center. Offset to the empty
## spawn chamber one layer above the floor.
const MINE_SPAWN_COORD: Vector3i = Vector3i(0, 0, 0)
const OVERWORLD_SPAWN_P1: Vector3 = Vector3(0, 1, 0)
const OVERWORLD_SPAWN_P2: Vector3 = Vector3(3, 1, 0)
## Compression factor: overworld (q,r) → portal-realm (q÷COMPRESS,
## r÷COMPRESS). Use `floori(x / float(COMPRESS))` for negative-safe
## division.
const PORTAL_COMPRESS: int = 10

const MARKER_MINE_ENTRANCE: StringName = &"mine_entrance"
const MARKER_LADDER_UP: StringName = &"ladder_up"
const MARKER_PORTAL: StringName = &"portal"
const MARKER_PORTAL_RETURN: StringName = &"portal_return"

var _player1: PlayerController
var _player2: PlayerController
var _camera1: IsometricCamera
var _camera2: IsometricCamera
var _overworld: HexWorld
var _mine: HexWorld
var _portal_world: HexWorld = null
var _underground_env: Environment = null
var _portal_env: Environment = null

# Per-player state indexed by player_id (1 or 2). Index 0 unused.
var _mine_entry_progress: Array[float] = [0.0, 0.0, 0.0]
var _ladder_exit_progress: Array[float] = [0.0, 0.0, 0.0]
var _portal_entry_progress: Array[float] = [0.0, 0.0, 0.0]
var _portal_exit_progress: Array[float] = [0.0, 0.0, 0.0]
## After any transition, require the mine key to be released before
## another transition can start. Prevents "bounce loop": entering the
## mine with F held would land the player on the ladder-up overlay and
## immediately trigger exit, back onto a mine-entrance, and so on.
var _transition_lock: Array[bool] = [false, false, false]
## Per-player overworld coord the player entered a portal from. Used
## by the portal-realm exit to teleport back to that location instead
## of a fixed spawn.
var _portal_origin_coord: Array[Vector3i] = [
	Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO
]


func setup(p1: PlayerController, p2: PlayerController, c1: IsometricCamera, c2: IsometricCamera,
		overworld: HexWorld, mine: HexWorld, ug_env: Environment) -> void:
	_player1 = p1
	_player2 = p2
	_camera1 = c1
	_camera2 = c2
	_overworld = overworld
	_mine = mine
	_underground_env = ug_env


## Optional: register the portal-realm world + environment. Without
## this call, portal markers are inert (no transition fires).
func setup_portal(portal_world: HexWorld, portal_env: Environment) -> void:
	_portal_world = portal_world
	_portal_env = portal_env


func tick(delta: float) -> void:
	for player: PlayerController in [_player1, _player2]:
		if player == null:
			continue
		match player.world_state:
			PlayerController.WorldState.OVERWORLD:
				_tick_transition(player, delta, _overworld, MARKER_MINE_ENTRANCE,
						_mine_entry_progress, MINE_ENTRY_TIME, enter_underground)
				if _portal_world != null:
					_tick_transition(player, delta, _overworld, MARKER_PORTAL,
							_portal_entry_progress, PORTAL_ENTRY_TIME, enter_portal)
			PlayerController.WorldState.MINE:
				_tick_transition(player, delta, _mine, MARKER_LADDER_UP,
						_ladder_exit_progress, LADDER_EXIT_TIME, exit_underground)
			PlayerController.WorldState.PORTAL:
				if _portal_world != null:
					_tick_transition(player, delta, _portal_world, MARKER_PORTAL_RETURN,
							_portal_exit_progress, PORTAL_EXIT_TIME, exit_portal)


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
	player.set_world_state(PlayerController.WorldState.MINE)
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
	player.set_world_state(PlayerController.WorldState.OVERWORLD)
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


func get_portal_entry_progress(player_id: int) -> float:
	return clampf(_portal_entry_progress[player_id], 0.0, 1.0)


func get_portal_exit_progress(player_id: int) -> float:
	return clampf(_portal_exit_progress[player_id], 0.0, 1.0)


## Compress an overworld coord to its portal-realm counterpart. Uses
## `floori(x / float(N))` for negative-safe behavior:
##   floori(-1 / 10.0) == -1   (vs `-1 / 10 == 0`)
##   floori( 60 / 10.0) ==  6
##   floori(-45 / 10.0) == -5
static func compress_to_portal_coord(c: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(c.x) / float(PORTAL_COMPRESS)),
		floori(float(c.y) / float(PORTAL_COMPRESS)),
		0
	)


func enter_portal(player: PlayerController) -> void:
	if _portal_world == null:
		return
	var is_p1: bool = player == _player1
	# Remember the overworld coord the player came from so the return
	# portal teleports back to the same hex.
	var origin_coord: Vector3i = _overworld.world_to_coord(player.global_position)
	# Snap to the actual nearby portal marker so off-by-one cell drift
	# doesn't strand the return portal far from the entrance.
	var marker_coord: Vector3i = _overworld.find_nearby_marker(origin_coord, MARKER_PORTAL)
	if marker_coord != HexWorld.NO_COORD:
		origin_coord = marker_coord
	_portal_origin_coord[player.player_id] = origin_coord

	player.set_world_state(PlayerController.WorldState.PORTAL)
	player.collision_mask = 9   # players + portal-realm physics
	player.apply_render_layers(8)   # render layer 4 (portal realm)

	var cam: IsometricCamera = _camera1 if is_p1 else _camera2
	cam.cull_mask = 9
	cam.environment = _portal_env

	# Compute compressed destination + ensure a return portal exists
	# there. The platform extrusion + portal placement happens via
	# `_ensure_return_portal` so the player has solid ground to land
	# on even if the noise generator left that cell void.
	var dest_coord: Vector3i = compress_to_portal_coord(origin_coord)
	dest_coord = _ensure_return_portal(dest_coord, origin_coord)

	# Force-load chunks around the destination, then snap to a safe
	# spawn ADJACENT to the portal — the portal's blocking overlay
	# extends 3 layers tall, so spawning on top of the column would
	# trap the player inside the cylinder. Search starts 1 hex away.
	var preferred: Vector3 = _portal_world.coord_to_world(dest_coord)
	_portal_world.prime_around(preferred, 1, 1)
	var adj_search: Vector3i = Vector3i(
		dest_coord.x + 1, dest_coord.y, dest_coord.z
	)
	var spawn: Vector3 = _portal_world.find_safe_spawn(adj_search)
	player.position = spawn
	player.velocity = Vector3.ZERO
	player._last_safe_position = spawn
	cam.size = cam.camera_size
	cam.snap_to_target()

	player_entered_portal.emit(player)


func exit_portal(player: PlayerController) -> void:
	if _portal_world == null:
		return
	var is_p1: bool = player == _player1
	player.set_world_state(PlayerController.WorldState.OVERWORLD)
	player.collision_mask = 3
	player.apply_render_layers(2)

	var cam: IsometricCamera = _camera1 if is_p1 else _camera2
	cam.cull_mask = 3
	cam.environment = null

	# Teleport back to the overworld coord the player entered from.
	# Fall back to the spawn point if no origin was recorded.
	var origin_coord: Vector3i = _portal_origin_coord[player.player_id]
	var preferred: Vector3
	if origin_coord == Vector3i.ZERO and not _is_origin_recorded(player.player_id):
		preferred = OVERWORLD_SPAWN_P1 if is_p1 else OVERWORLD_SPAWN_P2
	else:
		preferred = _overworld.coord_to_world(origin_coord)

	_overworld.prime_around(preferred, 2, 0)
	var lookup_coord: Vector3i = _overworld.world_to_coord(preferred)
	var spawn: Vector3 = _overworld.find_safe_spawn(
		Vector3i(lookup_coord.x, lookup_coord.y, OverworldHexGenerator.SURFACE_MAX_LAYER + 1)
	)
	player.position = spawn
	player.velocity = Vector3.ZERO
	cam.size = cam.camera_size
	cam.snap_to_target()

	player_exited_portal.emit(player)


## Make sure a return-portal cell exists at `dest_coord` in the portal
## realm. If the noise generator left that column void, extrude a
## small platform of `portal_stone` so the player has somewhere to
## stand. Returns the actual coord where the return portal was placed
## (may be one layer above `dest_coord` if a floor needed extruding).
func _ensure_return_portal(dest_coord: Vector3i, _origin_coord: Vector3i) -> Vector3i:
	# Force-load the destination chunk so place_base / place_overlay
	# can hit a real (non-streamed) chunk.
	_portal_world.prime_around(_portal_world.coord_to_world(dest_coord))

	var stone_idx: int = _portal_world.palette.base_index(&"portal_stone")
	var return_idx: int = _portal_world.palette.overlay_index_by_marker(MARKER_PORTAL_RETURN)
	if return_idx < 0 or stone_idx < 0:
		return dest_coord

	# Pick a "ground" layer at or just below dest. Walk down up to a
	# few layers looking for an existing solid cell; if none, extrude
	# a single platform tile at dest_coord.z - 1.
	var ground_coord: Vector3i = Vector3i(dest_coord.x, dest_coord.y, dest_coord.z - 1)
	var found_ground: bool = false
	for dz: int in range(0, 4):
		var probe: Vector3i = Vector3i(dest_coord.x, dest_coord.y, dest_coord.z - dz)
		if _portal_world.has_cell(probe):
			ground_coord = probe
			found_ground = true
			break
	if not found_ground:
		_portal_world.place_base(ground_coord, stone_idx)

	# Place the return-portal overlay one layer above the ground.
	var portal_coord: Vector3i = Vector3i(ground_coord.x, ground_coord.y, ground_coord.z + 1)
	# Need a base cell under the overlay.
	if not _portal_world.has_cell(portal_coord):
		_portal_world.place_base(portal_coord, stone_idx)
	# Strip any existing overlay on that cell so place_overlay succeeds.
	var existing: HexCell = _portal_world.get_cell(portal_coord)
	if existing != null and existing.has_overlay() and existing.overlay_id != return_idx:
		existing.overlay_id = -1
		_portal_world.set_cell(portal_coord, existing)
	# Finally drop the return portal.
	if existing == null or existing.overlay_id != return_idx:
		_portal_world.place_overlay(portal_coord, return_idx)

	# Extrude a small landing pad of `portal_stone` around the ground
	# coord so adjacent hexes are walkable (caller spawns the player
	# 1 hex away from the portal to avoid the blocking cylinder).
	for n_dir: Vector2i in HexGrid.AXIAL_DIRECTIONS:
		var pad_coord: Vector3i = Vector3i(
			ground_coord.x + n_dir.x, ground_coord.y + n_dir.y, ground_coord.z
		)
		if not _portal_world.has_cell(pad_coord):
			_portal_world.place_base(pad_coord, stone_idx)

	# Return the coord ABOVE the portal so the player spawns standing
	# next to it (find_safe_spawn will snap them away from the marker).
	return Vector3i(portal_coord.x, portal_coord.y, portal_coord.z + 1)


func _is_origin_recorded(pid: int) -> bool:
	# Treat (0,0,0) origin as "unrecorded" only if the player never
	# passed through enter_portal; we can't distinguish a real (0,0,0)
	# entry from an uninitialized slot. Acceptable for v1 — players
	# who portal in from exactly (0,0,0) just respawn at the default.
	return _portal_origin_coord[pid] != Vector3i.ZERO
