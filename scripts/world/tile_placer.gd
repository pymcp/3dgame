class_name TilePlacer
extends Node

signal tile_landed(position: Vector3)

enum PlaceMode { MAGIC, PLAYER_BUILT }

const SKY_DROP_HEIGHT: float = 15.0
const MAGIC_TRAIL_COLOR: Color = Color(0.4, 0.6, 1.0)


func place_magic(tile_scene: PackedScene, target_pos: Vector3, reparent_to: Node, on_landed: Callable = Callable()) -> SkyFallTile:
	var sky_fall: SkyFallTile = SkyFallTile.new()
	sky_fall.drop_height = SKY_DROP_HEIGHT
	sky_fall.trail_color = MAGIC_TRAIL_COLOR
	add_child(sky_fall)
	sky_fall.landed.connect(func(pos: Vector3) -> void: tile_landed.emit(pos))
	sky_fall.start_drop(tile_scene, target_pos, reparent_to, on_landed)
	return sky_fall


func place_instant(tile_scene: PackedScene, target_pos: Vector3, parent: Node3D) -> Node3D:
	var instance: Node3D = tile_scene.instantiate()
	instance.position = target_pos
	parent.add_child(instance)
	return instance
