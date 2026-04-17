class_name MeshLoader
extends RefCounted

## Helper to extract the `Mesh` resource from a Kenney `.glb` file.
## Godot imports GLBs as `PackedScene`, so we instance the scene,
## walk to the first `MeshInstance3D`, grab its `mesh`, and free the
## scene instance.
##
## Results are cached by path.

static var _cache: Dictionary = {}


static func load_glb(path: String) -> Mesh:
	if _cache.has(path):
		return _cache[path] as Mesh
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("MeshLoader: could not load %s" % path)
		return null
	var root: Node = packed.instantiate()
	var mi: MeshInstance3D = _find_mesh_instance(root)
	var mesh: Mesh = null
	if mi != null:
		mesh = mi.mesh
	root.queue_free()
	if mesh != null:
		_cache[path] = mesh
	return mesh


static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null
