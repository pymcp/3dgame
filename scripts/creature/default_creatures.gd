class_name DefaultCreatures
extends RefCounted

## Factory functions that build the canonical `CreatureDef` resources
## used by the spawner. Mirrors `DefaultPalettes` and `DefaultDecorators`.
##
## All defs share the same `Creature` script; behavior + visual differ
## via the assigned `behavior` tree and `model_scene_path`.

const ORC_MODEL: String = "res://assets/creatures/mini_dungeon/character-orc.glb"
const SKELETON_MODEL: String = "res://assets/creatures/graveyard/character-skeleton.glb"
const ZOMBIE_MODEL: String = "res://assets/creatures/graveyard/character-zombie.glb"


## Hostile orc — patrols around its home and chases nearby players.
static func build_orc() -> CreatureDef:
	var def: CreatureDef = CreatureDef.new()
	def.id = &"orc"
	def.display_name = "Orc"
	def.model_scene_path = ORC_MODEL
	def.model_scale = 0.5
	def.move_speed = 0.6
	def.run_speed = 1.3
	def.detection_range = 6
	def.wander_radius = 7
	def.idle_time_min = 1.5
	def.idle_time_max = 4.5
	def.faction = &"hostile"
	def.world_kind = &"overworld"
	def.behavior = _build_aggressive_tree()
	return def


## Slower hostile skeleton — same chase tree but at a wander pace.
static func build_skeleton() -> CreatureDef:
	var def: CreatureDef = CreatureDef.new()
	def.id = &"skeleton"
	def.display_name = "Skeleton"
	def.model_scene_path = SKELETON_MODEL
	def.model_scale = 0.5
	def.move_speed = 0.5
	def.run_speed = 1.0
	def.detection_range = 5
	def.wander_radius = 6
	def.idle_time_min = 2.0
	def.idle_time_max = 5.0
	def.faction = &"hostile"
	def.world_kind = &"overworld"
	def.behavior = _build_aggressive_tree()
	return def


## Passive zombie — wanders aimlessly and shuffles away from players
## (placeholder "wildlife" behavior so we exercise the flee branch).
static func build_zombie() -> CreatureDef:
	var def: CreatureDef = CreatureDef.new()
	def.id = &"zombie"
	def.display_name = "Zombie"
	def.model_scene_path = ZOMBIE_MODEL
	def.model_scale = 0.5
	def.move_speed = 0.4
	def.run_speed = 0.8
	def.detection_range = 4
	def.wander_radius = 5
	def.idle_time_min = 2.5
	def.idle_time_max = 6.0
	def.faction = &"wildlife"
	def.world_kind = &"overworld"
	def.behavior = _build_skittish_tree()
	return def


# --- behavior tree presets ----------------------------------------------

## Selector:
##   Sequence(CanSeePlayer -> Chase -> FollowPath[run])    # priority
##   Sequence(Wander -> FollowPath[walk])                  # idle roam
##   Idle                                                  # fallback
static func _build_aggressive_tree() -> BTNode:
	var chase_seq: BTSequence = BTSequence.new()
	chase_seq.children = [BTCanSeePlayer.new(), BTChase.new(), _follow_run()]

	# Wander branch: BTWander short-circuits to FAILURE while the rest
	# cooldown (BB_IDLE_TIMER) is positive, so the selector falls through
	# to the BTIdle fallback below until the rest period expires.
	# BTFollowPath sets the cooldown when the path completes.
	var wander_seq: BTSequence = BTSequence.new()
	wander_seq.children = [BTWander.new(), _follow_walk()]

	var root: BTSelector = BTSelector.new()
	root.children = [chase_seq, wander_seq, BTIdle.new()]
	return root


## Selector:
##   Sequence(CanSeePlayer -> Flee -> FollowPath[run])     # avoid
##   Sequence(Wander -> FollowPath[walk])                  # roam
##   Selector(LookAround, Idle)                            # idle variation
static func _build_skittish_tree() -> BTNode:
	var flee_seq: BTSequence = BTSequence.new()
	flee_seq.children = [BTCanSeePlayer.new(), BTFlee.new(), _follow_run()]

	var wander_seq: BTSequence = BTSequence.new()
	wander_seq.children = [BTWander.new(), _follow_walk()]

	# Skittish fallback: occasionally look around between idle pauses.
	var idle_sel: BTSelector = BTSelector.new()
	idle_sel.children = [BTLookAround.new(), BTIdle.new()]

	var root: BTSelector = BTSelector.new()
	root.children = [flee_seq, wander_seq, idle_sel]
	return root


static func _follow_walk() -> BTFollowPath:
	var n: BTFollowPath = BTFollowPath.new()
	n.use_run_speed = false
	return n


static func _follow_run() -> BTFollowPath:
	var n: BTFollowPath = BTFollowPath.new()
	n.use_run_speed = true
	return n
