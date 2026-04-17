class_name CreatureFactory
extends RefCounted

## Builds a `Creature` instance for a `CreatureDef`. Mirrors
## `PlayerFactory.build()`. The caller is responsible for `add_child()`-ing
## the returned creature into the scene tree.

const _CREATURE_SCENE_PATH: String = "res://scenes/creature/creature.tscn"


static func build(
	def: CreatureDef,
	world: HexWorld,
	pathfinder: HexPathfinder,
	home_coord: Vector3i,
	world_position: Vector3,
) -> Creature:
	if def == null or world == null or pathfinder == null:
		push_warning("CreatureFactory.build: missing required argument")
		return null

	var creature: Creature
	if ResourceLoader.exists(_CREATURE_SCENE_PATH):
		var scn: PackedScene = load(_CREATURE_SCENE_PATH)
		creature = scn.instantiate() as Creature
	else:
		# Fallback: build node tree in code.
		creature = Creature.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = CapsuleShape3D.new()
		creature.add_child(col)
		col.name = "CollisionShape3D"

	creature.creature_def = def
	# `position` (not `global_position`) before being parented — global
	# transforms require the node be in the tree.
	creature.position = world_position
	creature.setup(world, pathfinder, home_coord)

	_apply_size(creature)
	_setup_model(creature)

	return creature


static func _apply_size(creature: Creature) -> void:
	var size: float = creature.creature_def.model_scale
	var col: CollisionShape3D = creature.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		var capsule: CapsuleShape3D = col.shape as CapsuleShape3D
		if capsule != null:
			capsule.radius = size * creature.creature_def.collision_radius_scale
			capsule.height = size * creature.creature_def.collision_height_scale
		var t: Transform3D = col.transform
		t.origin = Vector3(0.0, size, 0.0)
		col.transform = t


static func _setup_model(creature: Creature) -> void:
	var def: CreatureDef = creature.creature_def
	var model: Node3D = null
	if def.model_scene_path != "" and ResourceLoader.exists(def.model_scene_path):
		var scn: PackedScene = load(def.model_scene_path)
		model = scn.instantiate() as Node3D

	if model == null:
		# Fallback: red capsule at unit dimensions so model_scale handles
		# sizing the same way as the GLB path.
		model = Node3D.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.6
		capsule.height = 2.0
		mi.mesh = capsule
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.2, 0.2)
		mi.material_override = mat
		mi.position.y = 1.0
		model.add_child(mi)

	model.name = "Model"
	model.scale = Vector3(def.model_scale, def.model_scale, def.model_scale)
	creature.add_child(model)
	creature.model = model

	# Find the embedded AnimationPlayer (Kenney creature GLBs have one
	# with all clips already loaded — no per-anim FBX loading like the
	# player char).
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	creature.anim_player = ap
	if ap != null:
		_resolve_anim_lookup(creature, ap)
		# Set looping on the locomotion clips we'll discover.
		for simple_v: Variant in creature._anim_lookup.keys():
			var simple: String = simple_v
			var actual: String = creature._anim_lookup[simple]
			if simple in ["idle", "walk", "run"]:
				var anim: Animation = ap.get_animation(actual)
				if anim != null:
					anim.loop_mode = Animation.LOOP_LINEAR
		# Auto-start an idle so newly spawned creatures aren't T-posing
		# before their first BT tick.
		creature.play_anim(&"idle")


static func _resolve_anim_lookup(creature: Creature, ap: AnimationPlayer) -> void:
	# Build a `simple_name -> actual_animation_name` map for the four
	# canonical clips we care about. Order of resolution per simple
	# name:
	#   1. Explicit `creature_def.anim_name_map` entry.
	#   2. Direct match (`ap.has_animation(simple)`).
	#   3. Substring search across the player's animation list (case
	#      insensitive). E.g. "skeleton-armature|idle" matches "idle".
	const SIMPLE_NAMES: Array[String] = ["idle", "walk", "run", "attack"]
	var override_map: Dictionary = creature.creature_def.anim_name_map
	var available: PackedStringArray = ap.get_animation_list()
	var lookup: Dictionary = {}
	for simple: String in SIMPLE_NAMES:
		if override_map.has(simple):
			var v: String = String(override_map[simple])
			if ap.has_animation(v):
				lookup[simple] = v
				continue
		if ap.has_animation(simple):
			lookup[simple] = simple
			continue
		# Substring search.
		var lower: String = simple.to_lower()
		for actual: String in available:
			if actual.to_lower().contains(lower):
				lookup[simple] = actual
				break
	# If we found walk but no run, alias run -> walk so chase still
	# animates.
	if not lookup.has("run") and lookup.has("walk"):
		lookup["run"] = lookup["walk"]
	creature.set_anim_lookup(lookup)
