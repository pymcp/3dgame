extends CanvasLayer

## Global rising-and-fading toast notification system. Autoloaded as
## `Toast`. Call `Toast.push("Your message")` from anywhere to show a
## short-lived message at the top of the screen.
##
## Toasts stack vertically in a top-center VBoxContainer. Each toast
## rises ~80 pixels over 1.2 seconds while fading out, then frees
## itself.

const RISE_DISTANCE: float = 80.0
const DURATION: float = 1.2
const FADE_DELAY: float = 0.4
const FONT_SIZE: int = 28
const OUTLINE_SIZE: int = 4

var _container: VBoxContainer


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_container = VBoxContainer.new()
	_container.name = "ToastContainer"
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_container.offset_top = 32.0
	_container.offset_left = 0.0
	_container.offset_right = 0.0
	add_child(_container)


## Show a toast message that rises and fades out.
func push(text: String, color: Color = Color.WHITE) -> void:
	if _container == null:
		return
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_container.add_child(label)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - RISE_DISTANCE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION - FADE_DELAY).set_delay(FADE_DELAY)
	tween.chain().tween_callback(label.queue_free)
