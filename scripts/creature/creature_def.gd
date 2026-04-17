class_name CreatureDef
extends Resource

## Data-driven definition for a creature type. Drop one of these into
## `DefaultCreatures` (or load from disk) and pass to
## `CreatureFactory.build(def, world, pathfinder, home)`.

## Stable identifier, used by the spawner + serialization.
@export var id: StringName = &""
@export var display_name: String = ""

## Path to the visual GLB. The factory instantiates this as the
## creature's model and scans embedded `AnimationPlayer`s.
@export_file("*.glb") var model_scene_path: String = ""

## Uniform model scale. Player default is 0.15; creatures are usually
## similar (these Kenney humanoids are roughly the same size as the
## player char).
@export var model_scale: float = 0.15
## Collision capsule sizing — radius/height multipliers on `model_scale`.
@export var collision_radius_scale: float = 0.6
@export var collision_height_scale: float = 2.0

## Walk speed (world units / second) used by BTFollowPath when not
## sprinting.
@export var move_speed: float = 1.5
## Sprint speed used by BTChase / BTFlee.
@export var run_speed: float = 2.8

## How far (in axial hexes) this creature can detect a player. 0
## disables awareness entirely (pure wildlife wander loop).
@export var detection_range: int = 0

## Hexes from `home_coord` the wander leaf may pick. Larger = roams
## farther from spawn.
@export var wander_radius: int = 6

## Idle pause range between wander goals (seconds).
@export var idle_time_min: float = 1.0
@export var idle_time_max: float = 4.0

## Faction tag for future combat / AI decisions ("hostile", "neutral",
## "wildlife"). Currently informational only.
@export var faction: StringName = &"neutral"

## Behavior tree root that drives this creature. Built by
## `DefaultCreatures` (the same tree resource can be shared across
## many creatures because all per-instance state lives on the
## `BTBlackboard`).
@export var behavior: BTNode

## Override mapping from simple animation names (`idle`, `walk`, `run`,
## `attack`) to the actual animation names embedded in the GLB. If a
## simple name is missing here, the factory tries direct lookup
## (`anim_player.has_animation(simple_name)`) and then a case-insensitive
## fuzzy match.
@export var anim_name_map: Dictionary = {}

## Which world this creature spawns in: `&"overworld"` or `&"mine"`.
@export var world_kind: StringName = &"overworld"
