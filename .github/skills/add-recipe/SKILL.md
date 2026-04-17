---
name: add-recipe
description: "Add a crafting Recipe to the RecipeRegistry so it appears in the CharacterSheet's Crafting tab. Use when adding new craftable weapons, tools, or items gated by the workbench marker."
---
# Add Recipe

## When to Use
- Adding a new craftable weapon, armor piece, or consumable
- Adding an upgrade path (e.g. `iron_ore + hammer_basic → hammer_upgraded`)
- Gating a craft on a new marker overlay (e.g. a magic anvil)

## Background
`Recipe` (`scripts/inventory/recipe.gd`) is a `Resource` with parallel `input_ids` / `input_counts` arrays, a single `output_id` + `output_count`, and a `requires_marker` (default `&"workbench"`). `RecipeRegistry` (`scripts/inventory/recipe_registry.gd`) holds the seed list. `CharacterSheet`'s Crafting tab reads from the registry and gates `mine` (interact) on both `Recipe.can_craft(inv)` AND `HexWorld.find_nearby_marker(player_coord, requires_marker)`.

## Procedure

### 1. Ensure all referenced items exist
Every `input_id` and the `output_id` must already be registered in `ItemRegistry` — see [add-item](../add-item/SKILL.md).

### 2. Append in `RecipeRegistry._seed_recipes()`
Edit `scripts/inventory/recipe_registry.gd`:
```gdscript
_recipes.append(RecipeScript.build(
    &"recipe_sword_fancy",          # recipe id (unique, convention: "recipe_<output>")
    "Fancy Sword",                  # display name
    [                               # inputs: Array of [StringName, int] pairs
        [&"iron_ore", 5],
        [&"gold_ore", 1],
        [&"wood", 2],
    ],
    &"sword_fancy",                 # output_id (must exist in ItemRegistry)
    1,                              # output_count (default 1)
    &"workbench"                    # requires_marker (default &"workbench")
))
```

### 3. (Optional) New marker type
If the recipe should require a different station (e.g. `&"anvil"`), add a matching `OverlayKind` with that `marker` in `DefaultPalettes` — see the [add-overlay](../add-overlay/SKILL.md) skill. Place an instance in the world via `main.gd._setup_decorations` or a decorator.

### 4. Verify
- `godot --headless --path . --script res://tests/test_runner.gd --quit` — all tests pass (there is a generic `Recipe.can_craft` test but not one per recipe).
- In-game: grant the inputs to a player (mine ores, chop trees), stand adjacent to the workbench in the mine spawn chamber, open Character Sheet → Crafting tab, confirm the recipe is listed, inputs show have/need, status line shows "Near workbench: Yes", and `mine` crafts the output.

## Pitfalls
- Inputs are parallel arrays, not a Dictionary. Use `Recipe.build(...)` with the `[[id, count], ...]` shape — don't populate `input_ids` and `input_counts` out of sync.
- `Recipe.craft(inv)` does NOT check marker proximity. The Crafting tab enforces it before calling. If you add a new caller, gate on `HexWorld.find_nearby_marker` yourself.
- If the output is a newly added weapon, confirm `ItemDef.category = CAT_WEAPON` so `PlayerEquipment.equip` routes to the weapon slot.
