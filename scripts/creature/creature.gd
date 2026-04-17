class_name Creature
extends CharacterBody3D

## Generic AI-driven NPC. All type-specific behavior lives in
## `creature_def.behavior` (a behavior tree), so the same `Creature`
## script handles wildlife, monsters, and townspeople.
##
## Spawned via `CreatureFactory.build(def, world, pathfinder, home_coord)`.

const GRAVITY: float = 20.0
const ROTATION_SPEED: float = 8.0
## How quickly to interpolate the smoothed look-ahead direction.
const FACING_SMOOTH: float = 6.0

@export var creature_def: CreatureDef

var hex_world: HexWorld
var pathfinder: HexPathfinder
## Spawn point in hex coords — the wander leaf samples random walkable
## cells around this point so creatures don't drift forever.
var home_coord: Vector3i = Vector3i.ZERO

var model: Node3D = null
var anim_player: AnimationPlayer = null

var _bb: BTBlackboard = BTBlackboard.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_anim: StringName = &""
## Mapped name (`idle`/`walk`/`run`/`attack`) -> actual embedded
## animation name in this creature's anim player.
var _anim_lookup: Dictionary = {}
## Players the creature is allowed to consider for awareness — set by
## the spawner based on which world this creature lives in.
var _known_players: Array[PlayerController] = []
## Lateral velocity requested by the BT this frame (consumed in
## `_physics_process`). Reset each tick.
var _requested_lateral: Vector3 = Vector3.ZERO
var _wants_to_move: bool = false


func _ready() -> void:
	_rng.randomize()


## Called by `CreatureFactory.build()` after `add_child` so all node
## refs / globals are valid.
func setup(world: HexWorld, pf: HexPathfinder, home: Vector3i) -> void:
	hex_world = world
	pathfinder = pf
	home_coord = home


# --- main loop -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	_requested_lateral = Vector3.ZERO
	_wants_to_move = false

	if creature_def != null and creature_def.behavior != null:
		creature_def.behavior.tick(self, _bb, delta)

	# Apply BT-requested lateral velocity (zero if no movement leaf ran).
	velocity.x = _requested_lateral.x
	velocity.z = _requested_lateral.z

	# Gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Rotate model toward facing target.
	if model != null and _wants_to_move:
		var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if horiz.length_squared() > 0.0001:
			var target_yaw: float = atan2(horiz.x, horiz.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, delta * FACING_SMOOTH)

	move_and_slide()


# --- movement helpers (called by BT leaves) ------------------------------

func move_toward_world_pos(target: Vector3, speed: float, _delta: float) -> void:
	var dir: Vector3 = target - global_position
	dir.y = 0.0
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()
	_requested_lateral = dir * speed
	_wants_to_move = true


func stop_moving() -> void:
	_requested_lateral = Vector3.ZERO
	_wants_to_move = false


func rotate_toward_yaw(target_yaw: float, delta: float) -> void:
	if model == null:
		return
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, delta * ROTATION_SPEED)


func get_facing_yaw() -> float:
	if model == null:
		return 0.0
	return model.rotation.y


func get_current_coord() -> Vector3i:
	if hex_world == null:
		return Vector3i.ZERO
	return hex_world.world_to_coord(global_position)


func world_pos_for_coord(coord: Vector3i) -> Vector3:
	if hex_world == null:
		return Vector3.ZERO
	return hex_world.coord_to_world(coord)


func get_known_players() -> Array[PlayerController]:
	return _known_players


func set_known_players(players: Array[PlayerController]) -> void:
	_known_players = players


# --- animation -----------------------------------------------------------

## Set the simple-name -> embedded-name lookup. Called by the factory
## after the model is instantiated.
func set_anim_lookup(lookup: Dictionary) -> void:
	_anim_lookup = lookup


func play_anim(simple_name: StringName) -> void:
	if anim_player == null:
		return
	if _current_anim == simple_name and anim_player.is_playing():
		return
	var actual: String = _resolve_anim(simple_name)
	if actual == "":
		return
	if anim_player.has_animation(actual):
		anim_player.play(actual)
		_current_anim = simple_name


func _resolve_anim(simple_name: StringName) -> String:
	var key: String = String(simple_name)
	if _anim_lookup.has(key):
		return _anim_lookup[key]
	# Fallback: exact name in the player.
	if anim_player != null and anim_player.has_animation(key):
		return key
	# Walk fallback for run.
	if simple_name == &"run" and _anim_lookup.has("walk"):
		return _anim_lookup["walk"]
	return ""


## Resize model + collision at runtime. Called by the debug key.
func set_model_scale(new_scale: float) -> void:
	if creature_def != null:
		creature_def.model_scale = new_scale
	if model != null:
		model.scale = Vector3(new_scale, new_scale, new_scale)
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		var capsule: CapsuleShape3D = col.shape as CapsuleShape3D
		if capsule != null and creature_def != null:
			capsule.radius = new_scale * creature_def.collision_radius_scale
			capsule.height = new_scale * creature_def.collision_height_scale
		var t: Transform3D = col.transform
		t.origin = Vector3(0.0, new_scale, 0.0)
		col.transform = t


func apply_render_layers(layers_bitmask: int) -> void:
	_apply_layers_recursive(self, layers_bitmask)


func _apply_layers_recursive(node: Node, layers_bitmask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers_bitmask
	for child: Node in node.get_children():
		_apply_layers_recursive(child, layers_bitmask)
