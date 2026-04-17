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

	var eq: PlayerEquipment = PlayerEquipment.new()
	eq.name = "Equipment"
	eq.set_inventory(inv)
	player.add_child(eq)
	player.equipment = eq
	# Mirror weapon-slot equip/unequip to the visible held-tool, so an
	# equipped sword shows up in the character's hand (and is restored
	# after mining). Mining always shows the implicit pickaxe — see
	# `PlayerController.play_mine_anim`.
	eq.equipped.connect(func(slot: StringName, item_id: StringName) -> void:
		if slot == &"weapon" and not player._mining_active:
			player.set_held_tool(item_id)
	)
	eq.unequipped.connect(func(slot: StringName, _item_id: StringName) -> void:
		if slot == &"weapon" and not player._mining_active:
			player.set_held_tool(&"")
	)

	var interact: PlayerInteraction = PlayerInteraction.new()
	interact.name = "Interaction"
	interact.player_id = id
	player.add_child(interact)

	return player
