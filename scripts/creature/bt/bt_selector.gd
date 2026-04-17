class_name BTSelector
extends BTNode

## Composite node: ticks children left-to-right and returns the first
## SUCCESS or RUNNING. Returns FAILURE only if every child fails.

@export var children: Array[BTNode] = []


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	for child: BTNode in children:
		if child == null:
			continue
		var status: int = child.tick(creature, bb, delta)
		if status == Status.SUCCESS or status == Status.RUNNING:
			return status
	return Status.FAILURE
