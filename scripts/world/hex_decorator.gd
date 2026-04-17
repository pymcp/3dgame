class_name HexDecorator
extends Resource

## A data-driven cluster of props placed around an anchor hex cell.
## Reusable for any point-of-interest: mine entrance, village center,
## ruin, shrine, etc.
##
## Use `HexDecoratorNode.apply(world, anchor_coord, decorator)` to
## instantiate the props.

@export var display_name: String = ""
@export var props: Array[HexDecorationProp] = []
