class_name GameManagerClass
extends Node

enum GameState { OVERWORLD, UNDERGROUND, TRANSITION }

signal state_changed(new_state: GameState)
signal world_seed_changed(seed_value: int)

var current_state: GameState = GameState.OVERWORLD
var world_seed: int = 0
var world: Node3D = null

func _ready() -> void:
	randomize()
	world_seed = randi()


func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func get_world_seed() -> int:
	return world_seed


func set_world_seed(seed_value: int) -> void:
	world_seed = seed_value
	world_seed_changed.emit(seed_value)
