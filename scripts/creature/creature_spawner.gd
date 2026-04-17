class_name CreatureSpawner
extends Node

## Spawns creatures around active players in a single `HexWorld` and
## periodically despawns ones that have wandered too far. Owns its
## `HexPathfinder` so creatures share one A* graph per world.
##
## Add one of these as a child of each `HexWorld` (or as a sibling and
## call `setup()`).

## Pool of creature defs to spawn from. Picked uniformly at random for
## now — switch to weighted later if needed.
@export var creature_defs: Array[CreatureDef] = []
## Maximum live creatures at any time across all spawn anchors.
@export var max_alive: int = 8
## How often (seconds) the spawner ticks.
@export var spawn_interval: float = 4.0
## Axial range around an active player to consider for spawning. Won't
## spawn within `min_player_distance` to avoid popping in the player's
## face.
@export var spawn_radius: int = 14
@export var min_player_distance: int = 6
## A creature whose distance to the nearest active player exceeds this
## (axial hexes) is despawned.
@export var despawn_distance: int = 24
## Render layer bitmask applied to spawned creatures (matches the
## host world's `render_layer_bit`).
@export var render_layer_bit: int = 2

var hex_world: HexWorld
var pathfinder: HexPathfinder
var _active_players: Array[PlayerController] = []
var _alive: Array[Creature] = []
var _timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _enabled: bool = true


func _ready() -> void:
	_rng.randomize()


func setup(world: HexWorld, pf: HexPathfinder) -> void:
	hex_world = world
	pathfinder = pf
	render_layer_bit = world.render_layer_bit


func set_active_players(players: Array[PlayerController]) -> void:
	_active_players = players.duplicate()
	for c: Creature in _alive:
		if is_instance_valid(c):
			c.set_known_players(_active_players)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func _process(delta: float) -> void:
	if not _enabled or hex_world == null or pathfinder == null:
		return
	_cull_invalid()
	_despawn_far_creatures()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	if _alive.size() >= max_alive:
		return
	if _active_players.is_empty():
		return
	if creature_defs.is_empty():
		return
	_try_spawn()


func _try_spawn() -> void:
	# Anchor on a random active player.
	var anchor: PlayerController = _active_players[_rng.randi_range(0, _active_players.size() - 1)]
	if not is_instance_valid(anchor):
		return
	var anchor_coord: Vector3i = hex_world.world_to_coord(anchor.global_position)

	# Pick a candidate cell.
	var candidate: Vector3i = pathfinder.get_random_walkable_near(anchor_coord, spawn_radius, _rng)
	if candidate == anchor_coord:
		return
	var d: int = HexGrid.axial_distance(
		Vector2i(candidate.x, candidate.y), Vector2i(anchor_coord.x, anchor_coord.y)
	)
	if d < min_player_distance:
		return

	var def: CreatureDef = creature_defs[_rng.randi_range(0, creature_defs.size() - 1)]
	if def == null:
		return

	var spawn_world: Vector3 = hex_world.coord_to_world(candidate)
	# Lift slightly so we land on the surface instead of clipping.
	spawn_world.y += 0.05
	var creature: Creature = CreatureFactory.build(
		def, hex_world, pathfinder, candidate, spawn_world
	)
	if creature == null:
		return
	add_child(creature)
	# Now that the creature is in the tree, set the global position so
	# it's correct regardless of any parent transforms.
	creature.global_position = spawn_world
	creature.set_known_players(_active_players)
	creature.apply_render_layers(render_layer_bit)
	_alive.append(creature)


func _despawn_far_creatures() -> void:
	for i: int in range(_alive.size() - 1, -1, -1):
		var c: Creature = _alive[i]
		if not is_instance_valid(c):
			_alive.remove_at(i)
			continue
		var c_coord: Vector3i = hex_world.world_to_coord(c.global_position)
		var nearest: int = 1_000_000
		for p: PlayerController in _active_players:
			if not is_instance_valid(p):
				continue
			var p_coord: Vector3i = hex_world.world_to_coord(p.global_position)
			var d: int = HexGrid.axial_distance(
				Vector2i(c_coord.x, c_coord.y), Vector2i(p_coord.x, p_coord.y)
			)
			nearest = min(nearest, d)
		if nearest > despawn_distance:
			c.queue_free()
			_alive.remove_at(i)


func _cull_invalid() -> void:
	for i: int in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]):
			_alive.remove_at(i)


func live_count() -> int:
	_cull_invalid()
	return _alive.size()


## Resize all live creatures and update the defs so future spawns match.
func set_creature_scale(new_scale: float) -> void:
	for def: CreatureDef in creature_defs:
		def.model_scale = new_scale
	_cull_invalid()
	for c: Creature in _alive:
		if is_instance_valid(c):
			c.set_model_scale(new_scale)
