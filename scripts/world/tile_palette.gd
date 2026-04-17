class_name TilePalette
extends Resource

## A palette is the set of `TileKind`s (bases) and `OverlayKind`s a
## given `HexWorld` draws from. The overworld uses one palette; the
## mine uses another. Both can share entries if desired (e.g. `stone`
## may appear in both).

@export var bases: Array[TileKind] = []
@export var overlays: Array[OverlayKind] = []


## Look up a base tile by its string id. Returns `null` if missing.
func find_base(base_id: StringName) -> TileKind:
	for tk: TileKind in bases:
		if tk != null and tk.id == base_id:
			return tk
	return null


## Look up an overlay by its string id. Returns `null` if missing.
func find_overlay(overlay_id: StringName) -> OverlayKind:
	for ok: OverlayKind in overlays:
		if ok != null and ok.id == overlay_id:
			return ok
	return null


## Numeric index of a base tile (for storing in `HexCell.base_id`).
## Returns `-1` if not found.
func base_index(base_id: StringName) -> int:
	for i: int in bases.size():
		if bases[i] != null and bases[i].id == base_id:
			return i
	return -1


## Numeric index of an overlay (for storing in `HexCell.overlay_id`).
## Returns `-1` if not found.
func overlay_index(overlay_id: StringName) -> int:
	for i: int in overlays.size():
		if overlays[i] != null and overlays[i].id == overlay_id:
			return i
	return -1


## Find overlay by its `marker` field (e.g. mine_entrance, ladder_up).
func find_overlay_by_marker(marker: StringName) -> OverlayKind:
	for ok: OverlayKind in overlays:
		if ok != null and ok.marker == marker:
			return ok
	return null


## Numeric index of the first overlay carrying a given marker.
func overlay_index_by_marker(marker: StringName) -> int:
	for i: int in overlays.size():
		if overlays[i] != null and overlays[i].marker == marker:
			return i
	return -1
