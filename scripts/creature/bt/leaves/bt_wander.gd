class_name BTWander
extends BTNode

## Action: pick a random walkable hex within `wander_radius` of the
## creature's home and store a path to it on the blackboard.
## SUCCESS if a target was chosen and a path was found, FAILURE otherwise.

func tick(creature: Creature, bb: BTBlackboard, _delta: float) -> int:
	if creature.pathfinder == null:
		return Status.FAILURE
	# Resting between trips — let the BTIdle fallback take the tick.
	if bb.get_var(BTBlackboard.BB_IDLE_TIMER, -1.0) > 0.0:
		return Status.FAILURE
	# A path is already in flight — don't overwrite it (BTFollowPath
	# clears BB_PATH on completion, so we'll re-plan on the next cycle).
	if bb.has_var(BTBlackboard.BB_PATH):
		return Status.SUCCESS
	var here: Vector3i = creature.get_current_coord()
	var radius: int = creature.creature_def.wander_radius
	var target: Vector3i = creature.pathfinder.get_random_walkable_near(
		creature.home_coord, radius, creature._rng
	)
	if target == here:
		return Status.FAILURE
	var path: Array[Vector3i] = creature.pathfinder.find_path(here, target)
	if path.size() < 2:
		return Status.FAILURE
	bb.set_var(BTBlackboard.BB_PATH, path)
	bb.set_var(BTBlackboard.BB_PATH_INDEX, 1)  # skip start coord
	return Status.SUCCESS
