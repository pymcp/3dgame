class_name BTFlee
extends BTNode

## Action: plan a path AWAY from the detected player. Picks a walkable
## coord roughly opposite the player at distance ≈ detection_range,
## stores path on blackboard. SUCCESS if a path was found, else FAILURE.

const REPLAN_INTERVAL: float = 0.6


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	var player_v: Variant = bb.get_var(BTBlackboard.BB_DETECTED_PLAYER)
	if player_v == null or not is_instance_valid(player_v as PlayerController):
		return Status.FAILURE
	var player: PlayerController = player_v
	var here: Vector3i = creature.get_current_coord()
	var p_coord: Vector3i = creature.hex_world.world_to_coord(player.global_position)

	# Cooldown re-plans so we don't thrash per-frame.
	var cd: float = bb.get_var(BTBlackboard.BB_REPLAN_COOLDOWN, 0.0)
	cd -= delta
	var has_path: bool = bb.has_var(BTBlackboard.BB_PATH)
	if cd > 0.0 and has_path:
		bb.set_var(BTBlackboard.BB_REPLAN_COOLDOWN, cd)
		return Status.SUCCESS

	# Compute axial direction away from the player and pick a coord at
	# `detection_range` along that direction, then snap to the nearest
	# walkable hex.
	var dq: int = here.x - p_coord.x
	var dr: int = here.y - p_coord.y
	var dist: int = HexGrid.axial_distance(Vector2i.ZERO, Vector2i(dq, dr))
	if dist == 0:
		# Standing on the player — pick a random direction.
		var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[creature._rng.randi_range(0, 5)]
		dq = dir.x
		dr = dir.y
		dist = 1
	var range: int = creature.creature_def.detection_range
	var scale: float = float(range) / float(dist)
	var goal: Vector3i = Vector3i(
		here.x + roundi(dq * scale),
		here.y + roundi(dr * scale),
		here.z,
	)
	# Snap to the nearest known walkable cell within a small radius of goal.
	var snapped: Vector3i = creature.pathfinder.get_random_walkable_near(goal, 2, creature._rng)
	var path: Array[Vector3i] = creature.pathfinder.find_path(here, snapped)
	if path.size() < 2:
		return Status.FAILURE
	bb.set_var(BTBlackboard.BB_PATH, path)
	bb.set_var(BTBlackboard.BB_PATH_INDEX, 1)
	bb.set_var(BTBlackboard.BB_REPLAN_COOLDOWN, REPLAN_INTERVAL)
	return Status.SUCCESS
