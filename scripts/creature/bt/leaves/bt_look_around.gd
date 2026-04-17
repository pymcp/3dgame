class_name BTLookAround
extends BTNode

## Action: rotate the model toward a random nearby direction over ~0.5s.
## Used for natural idle variation. SUCCESS once the rotation completes.

const _TIMER_KEY: StringName = &"look_around_timer"
const _TARGET_KEY: StringName = &"look_around_target_yaw"

const DURATION: float = 0.6


func tick(creature: Creature, bb: BTBlackboard, delta: float) -> int:
	var timer: float = bb.get_var(_TIMER_KEY, -1.0)
	if timer < 0.0:
		# Pick a random new yaw within ±150° of current.
		var jitter: float = creature._rng.randf_range(-2.6, 2.6)
		var target: float = creature.get_facing_yaw() + jitter
		bb.set_var(_TARGET_KEY, target)
		timer = DURATION
	creature.stop_moving()
	creature.play_anim(&"idle")
	var target_yaw: float = bb.get_var(_TARGET_KEY, creature.get_facing_yaw())
	creature.rotate_toward_yaw(target_yaw, delta)
	timer -= delta
	if timer <= 0.0:
		bb.clear(_TIMER_KEY)
		bb.clear(_TARGET_KEY)
		return Status.SUCCESS
	bb.set_var(_TIMER_KEY, timer)
	return Status.RUNNING


func interrupt(_creature: Creature, bb: BTBlackboard) -> void:
	bb.clear(_TIMER_KEY)
	bb.clear(_TARGET_KEY)
