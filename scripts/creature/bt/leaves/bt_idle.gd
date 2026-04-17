class_name BTIdle
extends BTNode

## Action: stand still and play the idle animation for a random duration
## sampled once per "session" (cleared on first SUCCESS / interrupt).
## RUNNING while waiting, SUCCESS when the timer hits zero.

const _TIMER_KEY: StringName = BTBlackboard.BB_IDLE_TIMER


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	var timer: float = bb.get_var(_TIMER_KEY, -1.0)
	if timer < 0.0:
		var lo: float = creature.creature_def.idle_time_min
		var hi: float = creature.creature_def.idle_time_max
		timer = creature._rng.randf_range(lo, hi)
	creature.stop_moving()
	creature.play_anim(&"idle")
	timer -= delta
	if timer <= 0.0:
		bb.clear(_TIMER_KEY)
		return Status.SUCCESS
	bb.set_var(_TIMER_KEY, timer)
	return Status.RUNNING


func interrupt(_creature: Creature, bb: BTBlackboard) -> void:
	bb.clear(_TIMER_KEY)
