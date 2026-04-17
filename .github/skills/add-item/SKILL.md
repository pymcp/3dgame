---
name: add-item
description: "Register a new item (weapon, armor, material, consumable, quest) in the ItemRegistry so it can be held in Inventory, equipped via PlayerEquipment, and rendered as a 3D icon in the CharacterSheet. Use when adding new ItemDef entries."
---
# Add Item

## When to Use
- Adding a new weapon, armor piece, accessory, material, or consumable
- Creating a quest item that should show in the Quest tab
- Adding a drop id referenced by an `OverlayKind.drops` array

## Background
Items are `ItemDef` resources (`scripts/inventory/item_def.gd`) stored in the `ItemRegistry` autoload (`scripts/inventory/item_registry.gd`). Keys are `StringName`. `Inventory` stacks use the same ids. `PlayerEquipment.equip(id)` routes to the slot via `ItemDef.CATEGORY_TO_SLOT`. The `CharacterSheet` renders the GLB referenced by `icon_mesh_path` via `ItemIconRenderer`.

**Pickaxe is never an inventory item.** Mining tool progression lives on `PlayerController.pickaxe_tier`. Do NOT add `ItemDef`s with category `&"pickaxe"` — a regression test enforces this.

## Procedure

### 1. Pick a category
One of (from `item_def.gd`):
- `CAT_WEAPON` → slot `&"weapon"` (swords, axes, hammers, blades)
- `CAT_ARMOR_HEAD / CAT_ARMOR_CHEST / CAT_ARMOR_LEGS / CAT_ARMOR_BOOTS`
- `CAT_RING / CAT_AMULET`
- `CAT_MATERIAL` (stackable crafting inputs — drops from mining)
- `CAT_CONSUMABLE` (food, potions — uses `on_use` hook)
- `CAT_QUEST`

### 2. Pick a Kenney GLB for the icon
Browse `assets/survival/` (weapons, tools), `assets/fantasy_town/` (props), `assets/hex_tiles/` (ores). Good weapons: `sword.glb`, `sword-fancy.glb`, `axe.glb`, `hammer.glb`, `bow.glb`, `blade.glb`. Materials commonly reuse an existing hex-tile mesh with a tint.

### 3. Register in `ItemRegistry._seed_defs()`
Edit `scripts/inventory/item_registry.gd`. Use the `_make` / `_make_weapon` helpers, or build an `ItemDef` directly and call `_add(...)`:
```gdscript
# Simple material / consumable / quest item:
_add(_make(&"potion_heal", "Healing Potion", ItemDef.CAT_CONSUMABLE,
    "Restores some health."))

# Weapon (uses the weapon helper which also sets attack_damage + icon path):
_add(_make_weapon(&"sword_fancy", "Fancy Sword",
    SURVIVAL + "sword-fancy.glb", 6.0,
    "A ceremonial blade with real bite."))

# Anything the helpers don't cover — build manually:
var d: ItemDef = ItemDef.new()
d.id = &"ring_speed"
d.display_name = "Ring of Swiftness"
d.description = "Quickens the wearer's step."
d.category = ItemDef.CAT_RING
d.stack_size = 1
d.icon_mesh_path = "res://assets/survival/ring.glb"
_add(d)
```
Stack-size rule of thumb: equippables `1`, materials `99`, consumables `10` (these are the defaults `_make` applies).

### 4. If the item drops from an overlay
Reference the id from the relevant `OverlayKind.drops` in `scripts/world/default_palettes.gd`:
```gdscript
ore_diamond.drops = [ &"diamond" ]
```
Add the matching `ItemDef` before anything tries to mine it.

### 5. If the item is craftable
Add a `Recipe` via the [add-recipe](../add-recipe/SKILL.md) skill.

### 6. Verify
- `godot --headless --path . --script res://tests/test_runner.gd --quit` — 260 tests must pass.
- Open the game, pick up / grant the item via an existing drop, open the Character Sheet (E / I), confirm it appears in the correct tab with the 3D icon rendered.

## Pitfalls
- `ItemRegistry` seeds in `_init()` (not `_ready()`) so tests see data. If you shift to `_ready()`, the test runner will get an empty registry.
- Do NOT reference `ItemDef` by type name inside the registry autoload — autoloads parse before the `class_name` cache. Use `ItemDefScript` (preloaded `Script`) and return `Resource`.
- New `class_name`? Run `godot --headless --path . --editor --quit` once to repopulate the class cache.
