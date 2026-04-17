class_name PlayerController
extends CharacterBody3D

@export var player_id: int = 1
## Runtime-overridden by `_apply_player_size()` to `0.6 + player_size * 20.0`.
## Default here matches the default `player_size = 0.15` (= 3.6).
@export var move_speed: float = 3.6
@export var gravity: float = 20.0
@export var skin_name: String = ""
## Character scale. Changing this at runtime via `set_player_size()`
## rescales the model, collision capsule, and `move_speed` together.
@export var player_size: float = 0.15
## Implicit pickaxe tier. The pickaxe is NEVER an inventory item — it
## is always held when mining. Upgraded via crafting later (tier 2/3).
@export var pickaxe_tier: int = 1

## Jump velocity computed so a single jump clears 1 LAYER_HEIGHT + margin,
## and a double jump clears 2 layers.  h = v² / (2g) → v = sqrt(2·g·h).
## Target single-jump height ≈ LAYER_HEIGHT * 1.4 = 0.28.
const JUMP_VELOCITY: float = 3.35
const MAX_JUMPS: int = 2

var model: Node3D = null
var anim_player: AnimationPlayer = null

var is_underground: bool = false
var _current_anim: String = "idle"
var _mining_active: bool = false
var _mine_face_angle: float = 0.0
var _jumps_remaining: int = MAX_JUMPS
## Blocks movement + action input (used by the character sheet modal).
var _input_blocked: bool = false
## Tool currently held in the character's hand (visual). &"" = no tool.
## Swapped to pickaxe automatically during mining.
var _held_tool_id: StringName = &""
var _held_tool_node: Node3D = null
## Back-reference so `stop_mine_anim` can restore the equipped weapon.
var equipment: PlayerEquipment = null

# Isometric direction rotation: 45 degrees to align WASD with isometric axes
const ISO_ROTATION: float = -PI / 4.0

const CHAR_MODEL_PATH: String = "res://assets/characters/characterMedium.fbx"

# Animation FBX files -> simple name mapping
const ANIM_FILES: Dictionary = {
	"idle": "idle.fbx",
	"walk": "walk.fbx",
	"run": "run.fbx",
	"jump": "jump.fbx",
	"attack": "attack.fbx",
	"interactGround": "interactGround.fbx",
	"death": "death.fbx",
	"punch": "punch.fbx",
	"kick": "kick.fbx",
	"crouch": "crouch.fbx",
	"crouchIdle": "crouchIdle.fbx",
	"crouchWalk": "crouchWalk.fbx",
}

# FBX animation name -> our simple name
const ANIM_NAME_MAP: Dictionary = {
	"Root|Idle": "idle",
	"Root|Walk": "walk",
	"Root|Run": "run",
	"Root|Jump": "jump",
	"Root|Attack": "attack",
	"Root|Interact_ground": "interactGround",
	"Root|Death": "death",
	"Root|Punch": "punch",
	"Root|Kick": "kick",
	"Root|Crouch": "crouch",
	"Root|CrouchIdle": "crouchIdle",
	"Root|CrouchWalk": "crouchWalk",
}


func _ready() -> void:
	_setup_model()
	if skin_name != "" and model:
		_apply_skin(skin_name)
	_apply_player_size()


func _setup_model() -> void:
	if ResourceLoader.exists(CHAR_MODEL_PATH):
		var char_scene: PackedScene = load(CHAR_MODEL_PATH)
		model = char_scene.instantiate()
		model.name = "Model"
	else:
		# Fallback: colored capsule at UNIT dimensions so `model.scale`
		# (applied by _apply_player_size) uniformly scales it — same
		# code path as the FBX model.
		model = Node3D.new()
		model.name = "Model"
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
		capsule_mesh.radius = 0.6
		capsule_mesh.height = 2.0
		mesh_inst.mesh = capsule_mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 0.9) if player_id == 1 else Color(0.9, 0.3, 0.2)
		mesh_inst.material_override = mat
		mesh_inst.position.y = 1.0
		model.add_child(mesh_inst)
	add_child(model)

	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		model.add_child(anim_player)
	_load_character_animations(anim_player)


func _load_character_animations(target_ap: AnimationPlayer) -> void:
	var lib: AnimationLibrary = AnimationLibrary.new()

	for simple_name: String in ANIM_FILES:
		var fbx_file: String = ANIM_FILES[simple_name]
		var path: String = "res://assets/characters/animations/%s" % fbx_file
		if not ResourceLoader.exists(path):
			continue
		var anim_scene: PackedScene = load(path)
		if anim_scene == null:
			continue
		var anim_inst: Node3D = anim_scene.instantiate()
		var source_ap: AnimationPlayer = anim_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_ap == null:
			anim_inst.queue_free()
			continue

		for anim_name: String in source_ap.get_animation_list():
			if anim_name.contains("Targeting") or anim_name.contains("targeting"):
				continue
			var anim: Animation = source_ap.get_animation(anim_name)
			if anim == null:
				continue
			var mapped: String = ANIM_NAME_MAP.get(anim_name, simple_name)
			if mapped in ["idle", "walk", "run", "crouchIdle", "crouchWalk"]:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE
			lib.add_animation(mapped, anim.duplicate())

		anim_inst.queue_free()

	if target_ap.has_animation_library(""):
		target_ap.remove_animation_library("")
	target_ap.add_animation_library("", lib)


func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO if _input_blocked else InputManager.get_move_vector(player_id)

	# Rotate input for isometric perspective
	var rotated: Vector2 = input_vec.rotated(ISO_ROTATION)
	var direction: Vector3 = Vector3(rotated.x, 0.0, rotated.y).normalized()

	if direction.length() > 0.1:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		if not _mining_active and is_on_floor():
			# Face movement direction — FBX models face +Z, so rotate with atan2
			var target_angle: float = atan2(direction.x, direction.z)
			model.rotation.y = target_angle
			# Use run animation if input is strong, walk otherwise
			if input_vec.length() > 0.9:
				_play_anim("run")
			else:
				_play_anim("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 10.0)
		if not _mining_active and is_on_floor():
			_play_anim("idle")

	# Keep facing the mining target while actively mining
	if _mining_active and model:
		model.rotation.y = _mine_face_angle

	# Reset jumps on landing
	if is_on_floor():
		_jumps_remaining = MAX_JUMPS

	# Jump / double-jump
	if not _input_blocked and InputManager.is_action_just_pressed(player_id, "jump") and _jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		_jumps_remaining -= 1
		if not _mining_active:
			_play_anim("jump")

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	if anim_player == null:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		_current_anim = anim_name
	elif anim_name == "run" and anim_player.has_animation("walk"):
		# Fallback: run -> walk if run not loaded
		anim_player.play("walk")
		_current_anim = anim_name


func play_mine_anim() -> void:
	_mining_active = true
	_current_anim = ""  # Force replay even if attack was last anim
	_play_anim("attack")
	if anim_player and not anim_player.animation_finished.is_connected(_on_mine_anim_finished):
		anim_player.animation_finished.connect(_on_mine_anim_finished)
	# Show pickaxe in hand regardless of equipped weapon.
	set_held_tool(_pickaxe_glb_for_tier())


func stop_mine_anim() -> void:
	_mining_active = false
	if anim_player and anim_player.animation_finished.is_connected(_on_mine_anim_finished):
		anim_player.animation_finished.disconnect(_on_mine_anim_finished)
	_current_anim = ""  # Force transition back to idle
	_play_anim("idle")
	# Restore the equipped weapon (or empty hands).
	if equipment != null:
		set_held_tool(equipment.get_equipped(&"weapon"))
	else:
		set_held_tool(&"")


func _pickaxe_glb_for_tier() -> String:
	if pickaxe_tier >= 2:
		return "res://assets/survival/tool-pickaxe-upgraded.glb"
	return "res://assets/survival/tool-pickaxe.glb"


func face_target(target_pos: Vector3) -> void:
	var dir: Vector3 = target_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		_mine_face_angle = atan2(dir.x, dir.z)


func _on_mine_anim_finished(_anim_name: StringName) -> void:
	if _mining_active:
		_current_anim = ""  # Reset so _play_anim will replay
		_play_anim("attack")


## Set the render layer bitmask on every `VisualInstance3D` in the
## player subtree. Called by `MineTransitionController` when the
## player crosses into / out of the mine so that the other player's
## camera (which only sees its own world's render layer) doesn't
## render this player.
func apply_render_layers(layers_bitmask: int) -> void:
	_apply_render_layers_recursive(self, layers_bitmask)


func _apply_render_layers_recursive(node: Node, layers_bitmask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers_bitmask
	for child: Node in node.get_children():
		_apply_render_layers_recursive(child, layers_bitmask)


## Update the character scale at runtime. Rescales the model, the
## collision capsule, and `move_speed` consistently.
func set_player_size(new_size: float) -> void:
	player_size = clampf(new_size, 0.005, 1.0)
	_apply_player_size()


## Get the current character scale.
func get_player_size() -> float:
	return player_size


func _apply_player_size() -> void:
	# Visual model: uniform scale.
	if model != null:
		model.scale = Vector3(player_size, player_size, player_size)

	# Movement speed: linear with a floor so tiny characters aren't
	# painfully slow. size=0.0625 → 1.85, size=0.15 → 3.6, size=0.25 → 5.6.
	move_speed = 0.6 + player_size * 20.0

	# Collision capsule: radius 0.6×size, height 2.0×size, centered
	# at Y=size (capsule origin is at its center).
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		var capsule: CapsuleShape3D = col.shape as CapsuleShape3D
		if capsule != null:
			capsule.radius = player_size * 0.6
			capsule.height = player_size * 2.0
		var t: Transform3D = col.transform
		t.origin = Vector3(0.0, player_size, 0.0)
		col.transform = t


func _apply_skin(skin: String) -> void:
	var texture_path: String = "res://assets/characters/skins/%s.png" % skin
	if not ResourceLoader.exists(texture_path):
		return
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return
	# Apply skin texture to all mesh instances in the model
	var meshes: Array[MeshInstance3D] = _find_all_mesh_instances(model)
	for mesh_inst: MeshInstance3D in meshes:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		mesh_inst.material_override = mat


func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result


## Block / unblock gameplay input (movement, jump). Used by the
## character sheet modal so opening it freezes the player.
func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	if blocked:
		# Zero lateral motion so the character stops in place when the
		# sheet opens mid-stride.
		velocity.x = 0.0
		velocity.z = 0.0


func is_input_blocked() -> bool:
	return _input_blocked


## Tier-based mining speed multiplier. Pickaxe is always implicit —
## this value scales the damage-per-second accumulation in
## `PlayerInteraction._update_mining`.
func get_mine_speed_multiplier() -> float:
	match pickaxe_tier:
		1: return 1.0
		2: return 1.5
		3: return 2.25
	return 1.0


## Swap the visible tool held in the character's hand. Pass &"" to
## clear. Called from `play_mine_anim` to show the pickaxe and from
## `PlayerEquipment.equipped` on the weapon slot to show the weapon.
##
## v1: the tool is attached as a child of the character model with no
## bone attachment — Kenney's animated characters don't ship a skeleton
## socket. This is a visible-held-tool placeholder that will be
## improved when bone attachment lands.
func set_held_tool(tool_id_or_path: Variant) -> void:
	var key: StringName = _to_string_name(tool_id_or_path)
	if key == _held_tool_id:
		return
	_held_tool_id = key
	if _held_tool_node != null:
		_held_tool_node.queue_free()
		_held_tool_node = null
	if key == &"":
		return
	var mesh: Mesh = null
	# If it's a path to a .glb, load it directly; otherwise treat as
	# an ItemDef id.
	var path: String = String(key)
	if path.ends_with(".glb"):
		mesh = MeshLoader.load_glb(path)
	else:
		var def: ItemDef = ItemRegistry.get_def(key)
		if def != null and def.model_scene_path != "":
			mesh = MeshLoader.load_glb(def.model_scene_path)
	if mesh == null or model == null:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	# Offset roughly where the hand would be. Model is scaled via
	# `player_size` — this is in model-local units so it rides along.
	mi.position = Vector3(0.6, 1.1, 0.0)
	mi.rotation_degrees = Vector3(0.0, 0.0, -45.0)
	mi.scale = Vector3(1.3, 1.3, 1.3)
	# Ensure the tool renders on the same layers the rest of the
	# character model uses (set by apply_render_layers).
	mi.layers = 2 if not is_underground else 4
	model.add_child(mi)
	_held_tool_node = mi


func get_held_tool_id() -> StringName:
	return _held_tool_id


static func _to_string_name(v: Variant) -> StringName:
	if v is StringName:
		return v
	return StringName(v)
