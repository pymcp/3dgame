---
description: "Scene composition conventions for Godot 4.3 .tscn files. Use when creating or editing scenes."
applyTo: "**/*.tscn"
---
# Scene Conventions (Godot 4.3)

## Root Node Types
- Player scene: `CharacterBody3D`
- World chunks (overworld/underground): `Node3D`
- UI panels: `Control` (or `PanelContainer`, `MarginContainer`)
- Pickup items: `Area3D`
- Main scene: `Node` (manages viewports)

## Node Naming
- Use PascalCase for all nodes: `MeshInstance3D`, `CollisionShape3D`, `AnimationPlayer`
- Suffix with purpose when ambiguous: `Camera_P1`, `Camera_P2`
- Group related nodes: `Player1/`, `Player2/`, `World/`

## Split-Screen Viewport Structure
The main scene uses this structure — both SubViewports share one World3D:
```
Main (Node)
├── HBoxContainer
│   ├── SubViewportContainer_P1 (stretch=true, expand fill)
│   │   └── SubViewport_P1
│   └── SubViewportContainer_P2 (stretch=true, expand fill)
│       └── SubViewport_P2
└── World (Node3D) — the shared world root
    ├── WorldEnvironment
    ├── DirectionalLight3D
    ├── ChunkManager
    ├── Player1 (CharacterBody3D)
    │   └── Camera_P1 (Camera3D, isometric)
    └── Player2 (CharacterBody3D)
        └── Camera_P2 (Camera3D, isometric)
```
Both SubViewports get their `world_3d` set to the same World3D resource from the World node.

## Scene Composition
- Prefer instancing child scenes over building monolithic scenes
- Player scene is its own `.tscn`, instanced into World
- Chunk scenes are their own `.tscn`, managed by ChunkManager
- UI panels are separate `.tscn` files, instanced in CanvasLayer nodes

## Camera Setup (Isometric)
- Camera3D with `projection = PROJECTION_ORTHOGONAL`
- `size = 15.0` (adjustable zoom)
- Rotation: X = -35.264°, Y = 45° (true isometric)
- Each player has their own camera as a child node; camera follows player
