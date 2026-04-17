class_name PlayerFactory
extends RefCounted

## Builds a PlayerController from the player.tscn prefab with attached
## Inventory and Interaction children. Model and animations are loaded
## by PlayerController itself.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


static func build(id: int, skin: String, pos: Vector3) -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player%d" % id
	player.player_id = id
	player.skin_name = skin
	player.position = pos

	var inv: Inventory = Inventory.new()
	inv.name = "Inventory"
	player.add_child(inv)

	var interact: PlayerInteraction = PlayerInteraction.new()
	interact.name = "Interaction"
	interact.player_id = id
	player.add_child(interact)

	return player
