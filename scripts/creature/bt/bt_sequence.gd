class_name BTSequence
extends BTNode

## Composite node: ticks children left-to-right and returns the first
## FAILURE or RUNNING. Returns SUCCESS only if every child succeeds.

@export var children: Array[BTNode] = []


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	for child: BTNode in children:
		if child == null:
			continue
		var status: int = child.tick(creature, bb, delta)
		if status == Status.FAILURE or status == Status.RUNNING:
			return status
	return Status.SUCCESS
