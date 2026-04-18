class_name TilePalette
extends Resource

## A palette is the set of `TileKind`s (bases) and `OverlayKind`s a
## given `HexWorld` draws from.

@export var bases: Array[TileKind] = []
@export var overlays: Array[OverlayKind] = []

# Lazily-built id -> index lookups. Built on first lookup and reused.
# Cleared by `invalidate_index_caches()` if the arrays are mutated
# at runtime (rare). Lookups happen many thousands of times during
# generation and crafting, so the previous linear scan was a real cost.
var _base_id_index: Dictionary = {}
var _overlay_id_index: Dictionary = {}
var _overlay_marker_index: Dictionary = {}
var _indices_built: bool = false


func _ensure_indices_built() -> void:
	if _indices_built:
		return
	_base_id_index.clear()
	_overlay_id_index.clear()
	_overlay_marker_index.clear()
	for i: int in bases.size():
		var tk: TileKind = bases[i]
		if tk != null and tk.id != &"":
			_base_id_index[tk.id] = i
	for i: int in overlays.size():
		var ok: OverlayKind = overlays[i]
		if ok == null:
			continue
		if ok.id != &"":
			_overlay_id_index[ok.id] = i
		if ok.marker != &"" and not _overlay_marker_index.has(ok.marker):
			_overlay_marker_index[ok.marker] = i
	_indices_built = true


## Call after mutating `bases` / `overlays` at runtime.
func invalidate_index_caches() -> void:
	_indices_built = false


## Look up a base tile by its string id. Returns `null` if missing.
func find_base(base_id: StringName) -> TileKind:
	var i: int = base_index(base_id)
	return bases[i] if i >= 0 else null


## Look up an overlay by its string id. Returns `null` if missing.
func find_overlay(overlay_id: StringName) -> OverlayKind:
	var i: int = overlay_index(overlay_id)
	return overlays[i] if i >= 0 else null


## Numeric index of a base tile (for storing in `HexCell.base_id`).
## Returns `-1` if not found.
func base_index(base_id: StringName) -> int:
	_ensure_indices_built()
	return _base_id_index.get(base_id, -1)


## Numeric index of an overlay (for storing in `HexCell.overlay_id`).
## Returns `-1` if not found.
func overlay_index(overlay_id: StringName) -> int:
	_ensure_indices_built()
	return _overlay_id_index.get(overlay_id, -1)


## Find overlay by its `marker` field (e.g. mine_entrance, ladder_up).
func find_overlay_by_marker(marker: StringName) -> OverlayKind:
	var i: int = overlay_index_by_marker(marker)
	return overlays[i] if i >= 0 else null


## Numeric index of the first overlay carrying a given marker.
func overlay_index_by_marker(marker: StringName) -> int:
	_ensure_indices_built()
	return _overlay_marker_index.get(marker, -1)
