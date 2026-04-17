class_name BTBlackboard
extends RefCounted

## Per-creature key/value scratch store used by behavior tree nodes.
## Keys should be `StringName` constants defined as ` BB_*` below.

## Latest path planned for the creature (Array[Vector3i]).
const BB_PATH: StringName = &"path"
## Index into BB_PATH the creature is currently walking toward.
const BB_PATH_INDEX: StringName = &"path_index"
## How long (seconds) the current Idle action should still wait.
const BB_IDLE_TIMER: StringName = &"idle_timer"
## Latest player detected within `detection_range` (PlayerController or null).
const BB_DETECTED_PLAYER: StringName = &"detected_player"
## Last known coord of detected player — used to decide when to re-plan.
const BB_LAST_TARGET_COORD: StringName = &"last_target_coord"
## Cooldown (seconds) until BTChase / BTFlee re-plans its path.
const BB_REPLAN_COOLDOWN: StringName = &"replan_cooldown"

var _data: Dictionary = {}


func get_var(key: StringName, default: Variant = null) -> Variant:
	return _data.get(key, default)


func set_var(key: StringName, value: Variant) -> void:
	_data[key] = value


func has_var(key: StringName) -> bool:
	return _data.has(key)


func clear(key: StringName) -> void:
	_data.erase(key)
