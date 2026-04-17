class_name BTNode
extends Resource

## Behavior Tree node base. All nodes are stateless `Resource`s — per-tick
## state lives on the `BTBlackboard` so the same tree can drive many
## creatures in parallel.
##
## Subclasses override `tick()` and return one of `Status`.

enum Status { SUCCESS, FAILURE, RUNNING }


## Tick this node. `creature` is the owning entity, `bb` is the
## per-creature blackboard, `delta` is the physics step.
## Default implementation succeeds — subclasses override.
func tick(_creature: Creature, _bb: BTBlackboard, _delta: float) -> int:
	return Status.SUCCESS


## Called by composites when this node has been preempted by a higher-
## priority branch — gives action nodes a chance to clean up
## (cancel paths, reset timers, etc.). Default is a no-op.
func interrupt(_creature: Creature, _bb: BTBlackboard) -> void:
	pass
