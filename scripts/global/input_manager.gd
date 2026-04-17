class_name InputManagerClass
extends Node

const PLAYER_COUNT: int = 2

# Fantasy-appropriate character skins
const SKIN_POOL: Array[String] = [
	"fantasyFemaleA", "fantasyFemaleB", "fantasyMaleA", "fantasyMaleB",
	"farmerA", "farmerB",
	"survivorFemaleA", "survivorFemaleB", "survivorMaleA", "survivorMaleB",
]


func get_action(player_id: int, action: String) -> String:
	return "p%d_%s" % [player_id, action]


func get_move_vector(player_id: int) -> Vector2:
	var prefix: String = "p%d_" % player_id
	return Input.get_vector(
		prefix + "move_left", prefix + "move_right",
		prefix + "move_up", prefix + "move_down"
	)


func is_action_pressed(player_id: int, action: String) -> bool:
	return Input.is_action_pressed(get_action(player_id, action))


func is_action_just_pressed(player_id: int, action: String) -> bool:
	return Input.is_action_just_pressed(get_action(player_id, action))


## Human-readable list of bindings for a per-player action. Returns a
## string like "F2 / A" (keyboard event + gamepad event). Used by the
## HUD so it always reflects the actual project.godot InputMap.
func get_action_hint(player_id: int, action: String) -> String:
	var action_name: String = get_action(player_id, action)
	if not InputMap.has_action(action_name):
		return ""
	var parts: Array[String] = []
	for ev: InputEvent in InputMap.action_get_events(action_name):
		var label: String = _format_event(ev)
		if label != "" and not parts.has(label):
			parts.append(label)
	return " / ".join(parts)


func _format_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key: InputEventKey = ev as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == 0:
			return ""
		return OS.get_keycode_string(code)
	if ev is InputEventJoypadButton:
		var btn: InputEventJoypadButton = ev as InputEventJoypadButton
		return _joy_button_name(btn.button_index)
	if ev is InputEventJoypadMotion:
		var mot: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return _joy_axis_name(mot.axis, mot.axis_value)
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
		return "Mouse%d" % mb.button_index
	return ""


func _joy_button_name(index: int) -> String:
	match index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
	return "Btn%d" % index


func _joy_axis_name(axis: int, value: float) -> String:
	var suffix: String = "+" if value > 0.0 else "-"
	match axis:
		JOY_AXIS_LEFT_X: return "L-Stick X%s" % suffix
		JOY_AXIS_LEFT_Y: return "L-Stick Y%s" % suffix
		JOY_AXIS_RIGHT_X: return "R-Stick X%s" % suffix
		JOY_AXIS_RIGHT_Y: return "R-Stick Y%s" % suffix
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "Axis%d%s" % [axis, suffix]


func get_random_skins() -> Array[String]:
	var pool: Array[String] = SKIN_POOL.duplicate()
	pool.shuffle()
	return [pool[0], pool[1]]
