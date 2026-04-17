class_name BTFollowPath
extends BTNode

## Action: walk the creature along the path stored on the blackboard.
## RUNNING while moving, SUCCESS at end of path, FAILURE if path is
## missing/invalidated.
##
## When `use_run_speed` is true the creature uses `run_speed` instead
## of `move_speed` (chase / flee branches set this).

@export var use_run_speed: bool = false

const ARRIVAL_THRESHOLD: float = 0.15  # world units (~ 1/4 hex radius)


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	var path_v: Variant = bb.get_var(BTBlackboard.BB_PATH)
	if path_v == null:
		return Status.FAILURE
	var path: Array = path_v
	if path.is_empty():
		bb.clear(BTBlackboard.BB_PATH)
		return Status.FAILURE
	var idx: int = bb.get_var(BTBlackboard.BB_PATH_INDEX, 0)
	if idx >= path.size():
		bb.clear(BTBlackboard.BB_PATH)
		bb.clear(BTBlackboard.BB_PATH_INDEX)
		return Status.SUCCESS

	var next_coord: Vector3i = path[idx]
	# Validate the next step is still walkable (terrain may have changed).
	if not creature.pathfinder.is_walkable(next_coord):
		bb.clear(BTBlackboard.BB_PATH)
		bb.clear(BTBlackboard.BB_PATH_INDEX)
		return Status.FAILURE

	var target_pos: Vector3 = creature.world_pos_for_coord(next_coord)
	var here: Vector3 = creature.global_position
	var to_target: Vector3 = target_pos - here
	to_target.y = 0.0
	if to_target.length() < ARRIVAL_THRESHOLD:
		idx += 1
		bb.set_var(BTBlackboard.BB_PATH_INDEX, idx)
		if idx >= path.size():
			creature.stop_moving()
			bb.clear(BTBlackboard.BB_PATH)
			bb.clear(BTBlackboard.BB_PATH_INDEX)
			# After a relaxed walk, queue a rest so BTWander short-circuits
			# and the BTIdle fallback gets airtime. Chase/flee paths skip
			# the rest so creatures keep pursuing.
			if not use_run_speed:
				var lo: float = creature.creature_def.idle_time_min
				var hi: float = creature.creature_def.idle_time_max
				bb.set_var(BTBlackboard.BB_IDLE_TIMER, creature._rng.randf_range(lo, hi))
			return Status.SUCCESS
		return Status.RUNNING

	var speed: float = creature.creature_def.run_speed if use_run_speed else creature.creature_def.move_speed
	creature.move_toward_world_pos(target_pos, speed, delta)
	creature.play_anim(&"run" if use_run_speed else &"walk")
	return Status.RUNNING


func interrupt(creature: Creature, bb: BTBlackboard) -> void:
	bb.clear(BTBlackboard.BB_PATH)
	bb.clear(BTBlackboard.BB_PATH_INDEX)
	creature.stop_moving()
