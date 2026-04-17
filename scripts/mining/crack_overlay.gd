class_name CrackOverlay
extends MeshInstance3D

## Shader-based crack overlay shown on the targeted hex cell while
## mining. Sized to a hex-cell footprint (radius ≈ `HexGrid.HEX_SIZE`,
## tall ≈ `HexWorldChunk.LAYER_HEIGHT`).

const CRACK_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_front, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crack_color : source_color = vec4(0.1, 0.05, 0.0, 0.9);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float crack_pattern(vec2 uv) {
	float n = 0.0;
	n += noise(uv * 4.0) * 0.5;
	n += noise(uv * 8.0) * 0.25;
	n += noise(uv * 16.0) * 0.125;
	n += noise(uv * 32.0) * 0.0625;
	return n;
}

void fragment() {
	float pattern = crack_pattern(UV * 3.0);
	float threshold = 1.0 - progress * 1.2;
	float crack = smoothstep(threshold, threshold + 0.05, pattern);
	float deep_crack = smoothstep(threshold + 0.1, threshold + 0.12, pattern) * progress;
	float total = clamp(crack + deep_crack * 0.5, 0.0, 1.0);
	ALBEDO = crack_color.rgb;
	ALPHA = total * crack_color.a * progress;
}
""";

var _shader_material: ShaderMaterial


func _init() -> void:
	var box: BoxMesh = BoxMesh.new()
	var radius: float = HexGrid.HEX_SIZE * 2.0 * 1.05  # hex fits in this box
	var tall: float = HexWorldChunk.LAYER_HEIGHT * 1.15
	box.size = Vector3(radius, tall, radius)
	mesh = box

	var shader: Shader = Shader.new()
	shader.code = CRACK_SHADER_CODE

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("crack_color", Color(0.1, 0.05, 0.0, 0.9))
	material_override = _shader_material

	visible = false


func set_progress(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	_shader_material.set_shader_parameter("progress", clamped)
	visible = clamped > 0.001


func reset() -> void:
	_shader_material.set_shader_parameter("progress", 0.0)
	visible = false
