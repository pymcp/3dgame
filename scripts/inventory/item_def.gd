class_name ItemDef
extends Resource

## Data-driven definition of an inventory item. Registered at startup
## inside `ItemRegistry`. Ids are `StringName` for cheap lookup.
##
## NOTE: the pickaxe is intentionally NOT an ItemDef — it is always
## implicitly held by the player (see `PlayerController.pickaxe_tier`).
## Don't add entries with category &"pickaxe".

## Category constants — single source of truth.
const CAT_WEAPON: StringName = &"weapon"
const CAT_ARMOR_HEAD: StringName = &"armor_head"
const CAT_ARMOR_CHEST: StringName = &"armor_chest"
const CAT_ARMOR_LEGS: StringName = &"armor_legs"
const CAT_ARMOR_BOOTS: StringName = &"armor_boots"
const CAT_RING: StringName = &"ring"
const CAT_AMULET: StringName = &"amulet"
const CAT_MATERIAL: StringName = &"material"
const CAT_CONSUMABLE: StringName = &"consumable"
const CAT_QUEST: StringName = &"quest"

## Slot id on `PlayerEquipment` that a category equips into. Non-gear
## categories return &"" (not equippable).
const CATEGORY_TO_SLOT: Dictionary = {
	CAT_WEAPON: &"weapon",
	CAT_ARMOR_HEAD: &"head",
	CAT_ARMOR_CHEST: &"chest",
	CAT_ARMOR_LEGS: &"legs",
	CAT_ARMOR_BOOTS: &"boots",
	CAT_RING: &"ring",
	CAT_AMULET: &"amulet",
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: StringName = CAT_MATERIAL
@export var stack_size: int = 99
## Path to a `.glb` scene used to render the 3D icon via
## `ItemIconRenderer`. May also double as the held model for weapons.
@export var icon_mesh_path: String = ""
## Optional separate path when the paper-doll model differs from the
## icon model. Empty = fall back to `icon_mesh_path`.
@export var model_scene_path: String = ""
## Weapon stat (reserved for combat, not currently used).
@export var attack_damage: float = 0.0
## Consumable hook identifier (Phase 5 — unused in v1).
@export var on_use: StringName = &""


func is_equippable() -> bool:
	return CATEGORY_TO_SLOT.has(category)


func equipment_slot() -> StringName:
	return CATEGORY_TO_SLOT.get(category, &"")
