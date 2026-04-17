class_name BTCanSeePlayer
extends BTNode

## Condition: succeeds if any active player is within
## `creature.creature_def.detection_range` axial hexes (any layer). On
## SUCCESS stores the nearest player + their coord on the blackboard.

func tick(creature: Creature, bb: BTBlackboard, _delta: float) -> int:
	if creature.creature_def.detection_range <= 0:
		bb.clear(BTBlackboard.BB_DETECTED_PLAYER)
		return Status.FAILURE
	var nearest: PlayerController = null
	var nearest_dist: int = creature.creature_def.detection_range + 1
	var nearest_coord: Vector3i = Vector3i.ZERO
	var here: Vector3i = creature.get_current_coord()
	for p: PlayerController in creature.get_known_players():
		if not is_instance_valid(p):
			continue
		var p_coord: Vector3i = creature.hex_world.world_to_coord(p.global_position)
		var d: int = HexGrid.axial_distance(
			Vector2i(here.x, here.y), Vector2i(p_coord.x, p_coord.y)
		)
		if d <= creature.creature_def.detection_range and d < nearest_dist:
			nearest = p
			nearest_dist = d
			nearest_coord = p_coord
	if nearest != null:
		bb.set_var(BTBlackboard.BB_DETECTED_PLAYER, nearest)
		bb.set_var(BTBlackboard.BB_LAST_TARGET_COORD, nearest_coord)
		return Status.SUCCESS
	bb.clear(BTBlackboard.BB_DETECTED_PLAYER)
	return Status.FAILURE
