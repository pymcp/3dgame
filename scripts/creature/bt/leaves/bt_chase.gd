class_name BTChase
extends BTNode

## Action: plan a path to the detected player's coord, then store it on
## the blackboard. Runs on a short re-plan cooldown so we don't recompute
## every physics frame. SUCCESS once a path is stored, FAILURE if no path.

const REPLAN_INTERVAL: float = 0.5


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	var player_v: Variant = bb.get_var(BTBlackboard.BB_DETECTED_PLAYER)
	if player_v == null or not is_instance_valid(player_v as PlayerController):
		return Status.FAILURE
	var player: PlayerController = player_v
	var here: Vector3i = creature.get_current_coord()
	var goal: Vector3i = creature.hex_world.world_to_coord(player.global_position)
	bb.set_var(BTBlackboard.BB_LAST_TARGET_COORD, goal)

	# Throttle re-planning.
	var cd: float = bb.get_var(BTBlackboard.BB_REPLAN_COOLDOWN, 0.0)
	cd -= delta
	var has_path: bool = bb.has_var(BTBlackboard.BB_PATH)
	if cd > 0.0 and has_path:
		bb.set_var(BTBlackboard.BB_REPLAN_COOLDOWN, cd)
		return Status.SUCCESS

	var path: Array[Vector3i] = creature.pathfinder.find_path(here, goal)
	if path.size() < 2:
		return Status.FAILURE
	bb.set_var(BTBlackboard.BB_PATH, path)
	bb.set_var(BTBlackboard.BB_PATH_INDEX, 1)
	bb.set_var(BTBlackboard.BB_REPLAN_COOLDOWN, REPLAN_INTERVAL)
	return Status.SUCCESS
