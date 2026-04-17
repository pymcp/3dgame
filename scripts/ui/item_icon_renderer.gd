class_name ItemIconRenderer
extends RefCounted

## Caches a small `SubViewport` per unique item id that renders the
## item's GLB as a 3D scene and exposes the result as a `Texture2D`.
## Used by `ItemSlotControl` + the paper-doll.
##
## The viewports live as children of a singleton "holder" node added
## under the scene tree root so their `World3D` is persistent.

const ICON_SIZE: Vector2i = Vector2i(64, 64)
const HOLDER_NAME: StringName = &"ItemIconRendererHolder"

static var _cache: Dictionary = {}  # StringName id -> ViewportTexture
static var _holder: Node = null


static func get_icon(tree: SceneTree, item_id: StringName) -> Texture2D:
	if item_id == &"":
		return null
	if _cache.has(item_id):
		return _cache[item_id]
	var def: ItemDef = ItemRegistry.get_def(item_id)
	if def == null or def.icon_mesh_path == "":
		return null
	_ensure_holder(tree)
	var tex: ViewportTexture = _build_viewport(def)
	if tex != null:
		_cache[item_id] = tex
	return tex


static func _ensure_holder(tree: SceneTree) -> void:
	if _holder != null and _holder.is_inside_tree():
		return
	_holder = Node.new()
	_holder.name = HOLDER_NAME
	tree.root.add_child.call_deferred(_holder)


static func _build_viewport(def: ItemDef) -> ViewportTexture:
	var vp: SubViewport = SubViewport.new()
	vp.size = ICON_SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = false
	_holder.add_child(vp)

	# Scene root with model.
	var mesh: Mesh = MeshLoader.load_glb(def.icon_mesh_path)
	if mesh == null:
		vp.queue_free()
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	vp.add_child(mi)

	# Tight bounding box → auto-frame.
	var aabb: AABB = mi.get_aabb()
	var extent: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if extent <= 0.001:
		extent = 1.0
	mi.position = -aabb.get_center()

	# Orthogonal camera at 30° pitch, 45° yaw — gives a pleasing isometric-ish feel.
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = extent * 1.4
	cam.position = Vector3(extent, extent, extent)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	vp.add_child(cam)
	cam.current = true

	# Simple directional light so the model doesn't look flat.
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 40.0, 0.0)
	light.light_energy = 1.2
	vp.add_child(light)

	return vp.get_texture()


static func clear_cache() -> void:
	_cache.clear()
	if _holder and _holder.is_inside_tree():
		_holder.queue_free()
	_holder = null
