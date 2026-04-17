class_name SkyFallTile
extends Node3D

signal landed(target_position: Vector3)

@export var drop_height: float = 15.0
@export var gravity: float = 25.0
@export var trail_color: Color = Color(0.4, 0.6, 1.0)

var _tile_instance: Node3D = null
var _target_position: Vector3 = Vector3.ZERO
var _velocity: float = 0.0
var _falling: bool = false
var _landed: bool = false

var _trail_particles: GPUParticles3D
var _glow_particles: GPUParticles3D
var _star_burst: GPUParticles3D
var _dust_ring: GPUParticles3D

var _magic_texture: Texture2D
var _star_texture: Texture2D
var _circle_texture: Texture2D
var _smoke_texture: Texture2D

var _reparent_target: Node = null
var _on_landed_callback: Callable


func _ready() -> void:
	_magic_texture = _load_texture("res://assets/particles/magic_04.png")
	_star_texture = _load_texture("res://assets/particles/star_06.png")
	_circle_texture = _load_texture("res://assets/particles/circle_05.png")
	_smoke_texture = _load_texture("res://assets/particles/smoke_04.png")

	_trail_particles = _create_trail_emitter()
	add_child(_trail_particles)

	_glow_particles = _create_glow_emitter()
	add_child(_glow_particles)

	_star_burst = _create_star_burst()
	add_child(_star_burst)

	_dust_ring = _create_dust_ring()
	add_child(_dust_ring)


func start_drop(tile_scene: PackedScene, target_pos: Vector3, reparent_to: Node, on_landed: Callable = Callable()) -> void:
	_target_position = target_pos
	_reparent_target = reparent_to
	_on_landed_callback = on_landed

	_tile_instance = tile_scene.instantiate()
	add_child(_tile_instance)

	position = target_pos + Vector3(0.0, drop_height, 0.0)
	_velocity = 0.0
	_falling = true

	_trail_particles.emitting = true
	_glow_particles.emitting = true


func _process(delta: float) -> void:
	if not _falling:
		return

	_velocity += gravity * delta
	position.y -= _velocity * delta

	if position.y <= _target_position.y:
		position = _target_position
		_falling = false
		_on_impact()


func _on_impact() -> void:
	_landed = true
	_trail_particles.emitting = false
	_glow_particles.emitting = false

	# Impact burst effects
	_star_burst.position = Vector3.ZERO
	_star_burst.restart()
	_star_burst.emitting = true

	_dust_ring.position = Vector3.ZERO
	_dust_ring.restart()
	_dust_ring.emitting = true

	# Squash-stretch bounce on the tile
	if _tile_instance:
		_tile_instance.scale = Vector3(1.2, 0.7, 1.2)
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(_tile_instance, "scale", Vector3(1.0, 1.0, 1.0), 0.4)
		tween.tween_callback(_on_settle)
	else:
		_on_settle()


func _on_settle() -> void:
	if not is_inside_tree():
		return

	# Reparent the tile instance to the persistent parent
	if _tile_instance and _reparent_target and _tile_instance.is_inside_tree():
		var saved_pos: Vector3 = _tile_instance.global_position
		var saved_rot: Vector3 = _tile_instance.global_rotation
		_tile_instance.reparent(_reparent_target)
		_tile_instance.global_position = saved_pos
		_tile_instance.global_rotation = saved_rot
		_tile_instance.scale = Vector3.ONE

	landed.emit(_target_position)
	if _on_landed_callback.is_valid():
		_on_landed_callback.call()

	# Wait for particles to finish, then clean up
	var timer: SceneTreeTimer = get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _create_trail_emitter() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Trail"
	particles.amount = 15
	particles.lifetime = 0.6
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0.0, 1.0, 0.0)
	mat.scale_min = 0.06
	mat.scale_max = 0.12
	mat.color = trail_color
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.5, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	particles.process_material = mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.12, 0.12)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _magic_texture:
		draw_mat.albedo_texture = _magic_texture
	else:
		draw_mat.albedo_color = trail_color
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles


func _create_glow_emitter() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Glow"
	particles.amount = 3
	particles.lifetime = 0.4
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 0.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.3
	mat.scale_max = 0.5
	mat.color = Color(trail_color, 0.3)
	particles.process_material = mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.5, 0.5)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _circle_texture:
		draw_mat.albedo_texture = _circle_texture
	else:
		draw_mat.albedo_color = Color(trail_color, 0.3)
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles


func _create_star_burst() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "StarBurst"
	particles.amount = 25
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = Color(1.0, 0.9, 0.4)
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	particles.process_material = mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.1, 0.1)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _star_texture:
		draw_mat.albedo_texture = _star_texture
	else:
		draw_mat.albedo_color = Color(1.0, 0.9, 0.4)
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles


func _create_dust_ring() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "DustRing"
	particles.amount = 12
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.2, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0.0, -2.0, 0.0)
	mat.scale_min = 0.08
	mat.scale_max = 0.2
	mat.color = Color(0.7, 0.6, 0.5, 0.7)
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.4, 0.6))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	particles.process_material = mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.15, 0.15)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _smoke_texture:
		draw_mat.albedo_texture = _smoke_texture
	else:
		draw_mat.albedo_color = Color(0.7, 0.6, 0.5, 0.5)
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles
