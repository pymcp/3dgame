class_name MiningVFX
extends Node3D

var _sparks: GPUParticles3D
var _dust: GPUParticles3D
var _burst_particles: GPUParticles3D

var _spark_texture: Texture2D
var _smoke_texture: Texture2D


func _ready() -> void:
	_spark_texture = _load_texture("res://assets/particles/spark_05.png")
	_smoke_texture = _load_texture("res://assets/particles/smoke_04.png")

	_sparks = _create_spark_emitter()
	add_child(_sparks)

	_dust = _create_dust_emitter()
	add_child(_dust)

	_burst_particles = _create_burst_emitter()
	add_child(_burst_particles)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func start(pos: Vector3, tint: Color) -> void:
	global_position = pos
	_set_emitter_color(_sparks, tint)
	_set_emitter_color(_dust, Color(tint, 0.5))
	_sparks.emitting = true
	_dust.emitting = true


func stop() -> void:
	_sparks.emitting = false
	_dust.emitting = false


func burst(pos: Vector3, tint: Color) -> void:
	global_position = pos
	_set_emitter_color(_burst_particles, tint)
	_burst_particles.restart()
	_burst_particles.emitting = true


func _set_emitter_color(emitter: GPUParticles3D, color: Color) -> void:
	var mat: ParticleProcessMaterial = emitter.process_material as ParticleProcessMaterial
	if mat:
		mat.color = color


func _create_spark_emitter() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Sparks"
	particles.amount = 10
	particles.lifetime = 0.3
	particles.one_shot = false
	particles.explosiveness = 0.8
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0.0, -9.8, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.1
	mat.color = Color.WHITE
	particles.process_material = mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.1, 0.1)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _spark_texture:
		draw_mat.albedo_texture = _spark_texture
	else:
		draw_mat.albedo_color = Color(1.0, 0.9, 0.5)
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles


func _create_dust_emitter() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Dust"
	particles.amount = 5
	particles.lifetime = 0.5
	particles.one_shot = false
	particles.explosiveness = 0.6
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0.0, -1.0, 0.0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = Color(0.8, 0.7, 0.6, 0.6)
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
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


func _create_burst_emitter() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Burst"
	particles.amount = 25
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0.0, -9.8, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color.WHITE
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
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
	if _spark_texture:
		draw_mat.albedo_texture = _spark_texture
	else:
		draw_mat.albedo_color = Color(1.0, 0.9, 0.5)
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	return particles
