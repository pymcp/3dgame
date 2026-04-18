class_name RotatingProp
extends Node3D

## Spins this node around the Y axis. Used by the portal-ring
## decoration so the portal mesh rotates continuously.

@export var rotation_speed_deg: float = 60.0


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed_deg) * delta)
