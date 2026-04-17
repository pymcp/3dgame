class_name HexDecorationProp
extends Resource

## One prop placed by a `HexDecorator`.

## Path to the `.glb`/`.tscn` scene for the prop.
@export_file("*.glb", "*.tscn") var scene_path: String = ""
## Offset from the anchor cell's world-center (before rotation).
@export var offset: Vector3 = Vector3.ZERO
## Rotation around Y (degrees).
@export var rotation_y_deg: float = 0.0
## Uniform scale.
@export var scale: float = 1.0
## Optional OmniLight3D: if `light_range > 0`, a point light is
## attached next to the prop with these parameters.
@export var light_color: Color = Color(1, 1, 1)
@export var light_energy: float = 1.0
@export var light_range: float = 0.0
## VisualInstance3D / OmniLight3D cull_mask applied to the prop + light.
@export var render_layers: int = 1
@export var light_cull_mask: int = 1
## Optional static collision cylinder attached to the prop. If
## `collision_radius <= 0`, no collision body is created.
@export var collision_radius: float = 0.0
@export var collision_height: float = 0.5
## Physics layer bitmask for the prop's StaticBody3D (e.g. 2 for
## overworld, 4 for mine).
@export var collision_layer: int = 0
