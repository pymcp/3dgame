class_name MiningProgressUI
extends Control

@export var player_id: int = 1

var _progress_bar: ProgressBar = null
var _interaction: PlayerInteraction = null
var _mine_entry_progress_getter: Callable
var _ladder_exit_progress_getter: Callable


func _ready() -> void:
	# Fill parent so anchor presets work
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	# Container anchored to bottom-center
	var container: MarginContainer = MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.set_anchor_and_offset(SIDE_LEFT, 0.5, -100.0)
	container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 100.0)
	container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -40.0)
	container.set_anchor_and_offset(SIDE_TOP, 1.0, -60.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(200, 20)
	_progress_bar.show_percentage = false
	_progress_bar.visible = false
	container.add_child(_progress_bar)


func set_interaction(interaction: PlayerInteraction) -> void:
	_interaction = interaction


func set_mine_entry_progress_getter(getter: Callable) -> void:
	_mine_entry_progress_getter = getter


func set_ladder_exit_progress_getter(getter: Callable) -> void:
	_ladder_exit_progress_getter = getter


func _process(_delta: float) -> void:
	# Check mine entry progress first (overworld)
	if _mine_entry_progress_getter.is_valid():
		var entry_progress: float = _mine_entry_progress_getter.call()
		if entry_progress > 0.0:
			_progress_bar.visible = true
			_progress_bar.value = entry_progress
			return

	# Check ladder exit progress (underground)
	if _ladder_exit_progress_getter.is_valid():
		var exit_progress: float = _ladder_exit_progress_getter.call()
		if exit_progress > 0.0:
			_progress_bar.visible = true
			_progress_bar.value = exit_progress
			return

	if _interaction == null:
		_progress_bar.visible = false
		return

	var progress: float = _interaction.get_mine_progress()
	if progress > 0.0:
		_progress_bar.visible = true
		_progress_bar.value = progress
	else:
		_progress_bar.visible = false
