class_name TileOcclusion
extends RefCounted

## Shared ShaderMaterial used by every chunk MMI (base + overlay) to
## fade tiles that block the camera's view of its target player. A
## horizontal circle (world-space xz disc) above each player with
## radius `occlusion_radius` is dimmed toward `occlusion_min_alpha`.
## Because the iso camera views it at a 45/-35 angle, that circle
## projects to an ellipse on screen.
##
## Both players' positions are kept in the material; the shader uses
## `CAMERA_POSITION_WORLD` to pick whichever player is closer (within
## `occlusion_camera_attach_dist`) so each viewport only fades tiles
## near that camera's own player.

const SHADER_PATH: String = "res://assets/shaders/tile_occlusion.gdshader"
const COLORMAP_PATH: String = "res://assets/hex_tiles/colormap.png"

static var _material: ShaderMaterial = null


## Return the single shared ShaderMaterial. Safe to call many times;
## the first call loads the shader + colormap and caches.
static func get_material() -> ShaderMaterial:
	if _material != null and is_instance_valid(_material):
		return _material
	_material = ShaderMaterial.new()
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader == null:
		push_warning("TileOcclusion: missing shader %s" % SHADER_PATH)
		return _material
	_material.shader = shader
	var colormap: Texture2D = load(COLORMAP_PATH) as Texture2D
	if colormap != null:
		_material.set_shader_parameter("colormap", colormap)
	_material.set_shader_parameter("player_p1", Vector4.ZERO)
	_material.set_shader_parameter("player_p2", Vector4.ZERO)
	return _material


## Push per-frame player positions into the shared material.
static func update_players(p1_pos: Vector3, p1_active: bool, p2_pos: Vector3, p2_active: bool) -> void:
	var m: ShaderMaterial = get_material()
	if m == null:
		return
	m.set_shader_parameter("player_p1",
		Vector4(p1_pos.x, p1_pos.y, p1_pos.z, 1.0 if p1_active else 0.0))
	m.set_shader_parameter("player_p2",
		Vector4(p2_pos.x, p2_pos.y, p2_pos.z, 1.0 if p2_active else 0.0))
