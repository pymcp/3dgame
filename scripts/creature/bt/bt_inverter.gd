class_name BTInverter
extends BTNode

## Decorator: flips SUCCESS↔FAILURE. RUNNING passes through unchanged.

@export var child: BTNode


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	if child == null:
		return Status.FAILURE
	var status: int = child.tick(creature, bb, delta)
	if status == Status.SUCCESS:
		return Status.FAILURE
	if status == Status.FAILURE:
		return Status.SUCCESS
	return status
