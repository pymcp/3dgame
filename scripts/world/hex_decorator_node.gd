class_name HexDecoratorNode
extends Node

## Applies a `HexDecorator` resource to a world around an anchor cell.

## Instantiate all props in `decorator` around `anchor_coord` in `world`.
## Returns the container `Node3D` that holds the prop instances (added
## as a child of `world`). Call `queue_free()` on the returned node to
## remove the entire decoration cluster.
static func apply(world: HexWorld, anchor_coord: Vector3i, decorator: HexDecorator) -> Node3D:
	var container: Node3D = Node3D.new()
	container.name = "Decoration_" + decorator.display_name.replace(" ", "_")
	var anchor_pos: Vector3 = world.coord_to_world(anchor_coord)
	container.position = anchor_pos
	world.add_child(container)

	for prop: HexDecorationProp in decorator.props:
		_spawn_prop(container, prop)
	return container


static func _spawn_prop(container: Node3D, prop: HexDecorationProp) -> void:
	if prop.scene_path.is_empty():
		return
	var packed: PackedScene = load(prop.scene_path) as PackedScene
	if packed == null:
		push_warning("HexDecoratorNode: could not load %s" % prop.scene_path)
		return
	var instance: Node = packed.instantiate()
	if instance is Node3D:
		var n3: Node3D = instance as Node3D
		n3.position = prop.offset
		n3.rotation.y = deg_to_rad(prop.rotation_y_deg)
		n3.scale = Vector3(prop.scale, prop.scale, prop.scale)
		_apply_render_layers(n3, prop.render_layers)
		if prop.collision_radius > 0.0:
			_attach_collision(n3, prop)
	container.add_child(instance)

	if prop.light_range > 0.0:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = prop.offset + Vector3(0, 0.5, 0)
		light.light_color = prop.light_color
		light.light_energy = prop.light_energy
		light.omni_range = prop.light_range
		light.light_cull_mask = prop.light_cull_mask
		container.add_child(light)


static func _apply_render_layers(node: Node, layers_bitmask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers_bitmask
	for child: Node in node.get_children():
		_apply_render_layers(child, layers_bitmask)


## Attach a static cylinder collider to a prop so players walk around
## it. The prop's own scene is kept purely visual — we inject a fresh
## `StaticBody3D` child sized by `prop.collision_radius / height`.
static func _attach_collision(prop_node: Node3D, prop: HexDecorationProp) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PropCollision"
	body.collision_layer = prop.collision_layer
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = prop.collision_radius
	cyl.height = prop.collision_height
	cs.shape = cyl
	# Center the cylinder so its base sits at the prop's local origin.
	cs.position = Vector3(0.0, prop.collision_height * 0.5, 0.0)
	body.add_child(cs)
	prop_node.add_child(body)
