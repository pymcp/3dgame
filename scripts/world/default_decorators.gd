class_name DefaultDecorators
extends RefCounted

## Factory for the default entrance decorators. These are built in
## code (rather than `.tres`) so prop scene paths and offsets live
## next to the rest of the gameplay code, and so we don't need to
## hand-author resource files yet.

const FT := "res://assets/fantasy_town/"
const SURVIVAL := "res://assets/survival/"
const PLATFORMER := "res://assets/platformer/"
const PORTAL_RING_SCENE := "res://scenes/world/rotating_portal.tscn"


## Decorator placed around an *overworld* mine entrance (topside).
## Small clustered props — lantern, signpost, little stones.
static func build_overworld_mine_entrance() -> HexDecorator:
	var deco: HexDecorator = HexDecorator.new()
	deco.display_name = "OverworldMineEntrance"

	var lantern_l: HexDecorationProp = _prop(FT + "lantern.glb", Vector3(-0.6, 0.0, 0.3), 0.0, 0.5)
	lantern_l.light_color = Color(1.0, 0.85, 0.55)
	lantern_l.light_energy = 1.5
	lantern_l.light_range = 3.0
	lantern_l.light_cull_mask = 3   # layers 1 + 2 (overworld)
	lantern_l.render_layers = 2     # overworld only
	lantern_l.collision_radius = 0.12
	lantern_l.collision_height = 0.6
	lantern_l.collision_layer = 2

	var lantern_r: HexDecorationProp = _prop(FT + "lantern.glb", Vector3(0.6, 0.0, 0.3), 0.0, 0.5)
	lantern_r.light_color = Color(1.0, 0.85, 0.55)
	lantern_r.light_energy = 1.5
	lantern_r.light_range = 3.0
	lantern_r.light_cull_mask = 3
	lantern_r.render_layers = 2
	lantern_r.collision_radius = 0.12
	lantern_r.collision_height = 0.6
	lantern_r.collision_layer = 2

	var signpost: HexDecorationProp = _prop(SURVIVAL + "signpost.glb", Vector3(0.0, 0.0, -0.5), 180.0, 0.5)
	signpost.render_layers = 2
	signpost.collision_radius = 0.12
	signpost.collision_height = 0.8
	signpost.collision_layer = 2

	deco.props = [lantern_l, lantern_r, signpost]
	return deco


## Decorator placed around the *underground* spawn pad. Ladder, more
## lanterns, campfire, barrel, chest.
static func build_mine_spawn_chamber() -> HexDecorator:
	var deco: HexDecorator = HexDecorator.new()
	deco.display_name = "MineSpawnChamber"

	var ladder: HexDecorationProp = _prop(PLATFORMER + "ladder.glb", Vector3(0.0, 0.0, 0.0), 0.0, 0.5)
	ladder.render_layers = 4    # underground render layer (bit 3)

	var campfire: HexDecorationProp = _prop(SURVIVAL + "campfire-pit.glb", Vector3(0.8, 0.0, 0.4), 0.0, 0.5)
	campfire.light_color = Color(1.0, 0.6, 0.25)
	campfire.light_energy = 2.0
	campfire.light_range = 3.5
	campfire.light_cull_mask = 5   # layers 1 + 3 (players + mine)
	campfire.render_layers = 4

	var barrel: HexDecorationProp = _prop(SURVIVAL + "barrel.glb", Vector3(-0.9, 0.0, -0.3), 0.0, 0.5)
	barrel.render_layers = 4
	barrel.collision_radius = 0.2
	barrel.collision_height = 0.5
	barrel.collision_layer = 4

	var chest: HexDecorationProp = _prop(SURVIVAL + "chest.glb", Vector3(-0.5, 0.0, 0.7), 30.0, 0.5)
	chest.render_layers = 4
	chest.collision_radius = 0.22
	chest.collision_height = 0.4
	chest.collision_layer = 4

	var lantern_l: HexDecorationProp = _prop(FT + "lantern.glb", Vector3(-1.0, 0.0, 0.6), 0.0, 0.5)
	lantern_l.light_color = Color(1.0, 0.85, 0.55)
	lantern_l.light_energy = 1.8
	lantern_l.light_range = 3.0
	lantern_l.light_cull_mask = 5
	lantern_l.render_layers = 4
	lantern_l.collision_radius = 0.12
	lantern_l.collision_height = 0.6
	lantern_l.collision_layer = 4

	var lantern_r: HexDecorationProp = _prop(FT + "lantern.glb", Vector3(1.0, 0.0, -0.5), 0.0, 0.5)
	lantern_r.light_color = Color(1.0, 0.85, 0.55)
	lantern_r.light_energy = 1.8
	lantern_r.light_range = 3.0
	lantern_r.light_cull_mask = 5
	lantern_r.render_layers = 4
	lantern_r.collision_radius = 0.12
	lantern_r.collision_height = 0.6
	lantern_r.collision_layer = 4

	deco.props = [ladder, campfire, barrel, chest, lantern_l, lantern_r]
	return deco


## Spinning portal ring decoration. `render_layers` controls which
## camera sees it (overworld portals = bit 1=2, portal-realm return
## portals = bit 3=8). The mesh hovers slightly above the cell so the
## ring sits visibly on top of the base hex.
static func build_portal_ring(render_layers: int, light_cull_mask: int) -> HexDecorator:
	var deco: HexDecorator = HexDecorator.new()
	deco.display_name = "Portal"
	var ring: HexDecorationProp = _prop(PORTAL_RING_SCENE, Vector3(0.0, 0.25, 0.0), 0.0, 0.6)
	ring.render_layers = render_layers
	ring.light_color = Color(0.7, 0.45, 1.0)
	ring.light_energy = 2.0
	ring.light_range = 4.0
	ring.light_cull_mask = light_cull_mask
	deco.props = [ring]
	return deco


static func _prop(scene_path: String, offset: Vector3, rotation_y_deg: float, scale: float) -> HexDecorationProp:
	var p: HexDecorationProp = HexDecorationProp.new()
	p.scene_path = scene_path
	p.offset = offset
	p.rotation_y_deg = rotation_y_deg
	p.scale = scale
	p.render_layers = 1
	p.light_cull_mask = 1
	return p
