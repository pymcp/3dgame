class_name IsometricCamera
extends Camera3D

@export var target: NodePath
@export var follow_speed: float = 5.0
@export var camera_size: float = 4.8
@export var offset: Vector3 = Vector3(10, 10, 10)

## Multiplier applied to player_size to get camera orthographic size.
## With default player_size 0.15 and this factor 32, size = 4.8.
const CAMERA_SIZE_PER_PLAYER_SIZE: float = 32.0

var _target_node: Node3D = null
var _shake_remaining: float = 0.0
var _shake_amplitude: float = 0.0

# True isometric angles
const ISO_X_ROTATION: float = -35.264  # arctan(1/√2) in degrees
const ISO_Y_ROTATION: float = 45.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = camera_size
	rotation_degrees = Vector3(ISO_X_ROTATION, ISO_Y_ROTATION, 0.0)

	if not target.is_empty():
		_target_node = get_node_or_null(target)


func _process(delta: float) -> void:
	if _target_node == null:
		if not target.is_empty():
			_target_node = get_node_or_null(target)
		if _target_node == null:
			return

	var target_pos: Vector3 = _target_node.global_position + offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	if _shake_remaining > 0.0:
		_shake_remaining -= delta
		var strength: float = _shake_amplitude * (_shake_remaining / max(_shake_remaining + delta, 0.001))
		var shake_offset: Vector3 = Vector3(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
			0.0
		)
		global_position += shake_offset


func shake(duration: float, amplitude: float) -> void:
	_shake_remaining = duration
	_shake_amplitude = amplitude


func set_target_node(node: Node3D) -> void:
	_target_node = node


func snap_to_target() -> void:
	if _target_node:
		global_position = _target_node.global_position + offset


## Recompute orthographic size from a player_size value so the
## character maintains a consistent on-screen footprint as it grows
## or shrinks.
func set_zoom_from_player_size(player_size: float) -> void:
	camera_size = player_size * CAMERA_SIZE_PER_PLAYER_SIZE
	size = camera_size
