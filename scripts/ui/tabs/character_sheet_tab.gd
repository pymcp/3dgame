class_name CharacterSheetTab
extends Control

## Base class for all character sheet tabs. Concrete tabs override the
## virtual hooks. Tabs live inside `CharacterSheet` and only receive
## input when focused.

var player_id: int = 1
var inventory: Inventory = null
var equipment: PlayerEquipment = null
var character_sheet: Node = null  # CharacterSheet parent (untyped to avoid circular)


func configure(p_player_id: int, inv: Inventory, eq: PlayerEquipment, sheet: Node) -> void:
	player_id = p_player_id
	inventory = inv
	equipment = eq
	character_sheet = sheet
	_on_configured()


# --- virtual hooks -------------------------------------------------------

func tab_title() -> String:
	return "Tab"


func _on_configured() -> void:
	pass


func on_focus() -> void:
	pass


func on_blur() -> void:
	pass


func handle_nav(_dir: Vector2i) -> void:
	pass


func handle_interact() -> void:
	pass


func handle_drop() -> void:
	pass


func refresh() -> void:
	pass
