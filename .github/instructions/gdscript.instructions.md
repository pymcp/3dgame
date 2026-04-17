---
description: "GDScript coding conventions for Godot 4.3. Use when writing or editing GDScript files."
applyTo: "**/*.gd"
---
# GDScript Conventions (Godot 4.3)

## Typing
- Always use static typing for variables, parameters, and return types:
  ```gdscript
  var speed: float = 5.0
  var player_id: int = 1
  var inventory: Dictionary = {}
  func move(direction: Vector3) -> void:
  func get_block(pos: Vector3i) -> BlockType:
  ```
- Use `Array[Type]` for typed arrays: `var chunks: Array[OverworldChunk] = []`
- Use `-> void` for functions that don't return a value

## Signals
- Declare with types: `signal block_mined(position: Vector3i, block_type: BlockType)`
- Name in past tense: `inventory_changed`, `chunk_loaded`, `player_entered_mine`
- Connect in `_ready()` using callable syntax: `block_mined.connect(_on_block_mined)`

## Node References
- Use `@onready` for child node references:
  ```gdscript
  @onready var mesh: MeshInstance3D = $MeshInstance3D
  @onready var collision: CollisionShape3D = $CollisionShape3D
  @onready var anim_player: AnimationPlayer = $AnimationPlayer
  ```
- Use `%UniqueNodeName` for unique-named nodes in complex scenes

## Exports
- Use `@export` for inspector-tunable values:
  ```gdscript
  @export var player_id: int = 1
  @export var move_speed: float = 5.0
  @export var mine_time: float = 1.5
  ```
- Use `@export_enum`, `@export_range`, `@export_group` for organization

## Autoloads
- Access directly by name: `GameManager`, `InputManager`
- GameManager: game state, scene transitions, world seed
- InputManager: per-player action mapping

## Per-Player Input
- All input actions prefixed with player ID: `p1_move_up`, `p1_move_down`, `p1_move_left`, `p1_move_right`, `p1_mine`, `p1_inventory`
- Player 2 uses `p2_` prefix with same suffixes
- In player scripts, build action names dynamically:
  ```gdscript
  var prefix: String = "p%d_" % player_id
  var input_dir: Vector2 = Input.get_vector(
      prefix + "move_left", prefix + "move_right",
      prefix + "move_up", prefix + "move_down"
  )
  ```

## Enums
- Use `class_name` enum pattern or inner enum:
  ```gdscript
  enum BlockType { AIR, STONE, ROCK, ORE_IRON, ORE_GOLD, ORE_CRYSTAL, BEDROCK }
  enum TerrainType { GRASS, DIRT, SAND, STONE, WATER }
  enum GameState { OVERWORLD, UNDERGROUND, TRANSITION }
  ```

## File Structure
- Order: `class_name` → `extends` → signals → enums/constants → `@export` vars → `@onready` vars → private vars → `_ready()` → `_process()/_physics_process()` → public methods → private methods
