class_name LandmassShape
extends RefCounted

## One island / continent. Pure data-driven shape helper used by
## `OverworldHexGenerator` to decide, for any (q, r) axial coord,
## whether it is on land and how far from the coast it sits.
##
## The generator can hold multiple `LandmassShape` instances in a
## list — `land_factor(q, r)` across the list takes the max of each
## shape so overlapping landmasses simply merge.
##
## Shape = an ellipse in axial (q, r) space, with its edge warped
## by a low-frequency noise so the coastline is irregular.

var center: Vector2 = Vector2.ZERO
var radius_q: float = 1.0
var radius_r: float = 1.0
## Optional low-frequency noise that warps the coastline. Can be
## `null` for a perfect ellipse.
var coastline_noise: FastNoiseLite = null
## How strongly the coastline noise deforms the ellipse edge
## (in normalized radii). 0.25 = the edge wobbles by ±25% of the radius.
var coastline_warp: float = 0.25


func _init(c: Vector2 = Vector2.ZERO,
		rq: float = 1.0,
		rr: float = 1.0,
		coastline: FastNoiseLite = null,
		warp: float = 0.25) -> void:
	center = c
	radius_q = maxf(rq, 0.001)
	radius_r = maxf(rr, 0.001)
	coastline_noise = coastline
	coastline_warp = warp


## `> 0`  = inside the landmass (1 at center, falling to 0 at the coast).
## `<= 0` = ocean. The magnitude of the negative value grows as you
##         travel away from shore.
func land_factor(q: float, r: float) -> float:
	var dq: float = (q - center.x) / radius_q
	var dr: float = (r - center.y) / radius_r
	var d2: float = dq * dq + dr * dr
	# Fast-path: deep ocean columns dominate world generation. If the
	# squared normalized distance is well past the warp envelope, we
	# can return a clearly-negative value without the sqrt or the
	# noise sample. `(1 + warp)^2` is the upper bound on the actual
	# distance after warp, so anything beyond that is guaranteed ocean.
	var max_warped: float = 1.0 + coastline_warp + 0.05  # small slack
	if d2 > max_warped * max_warped:
		# Approximate land_factor as `1 - sqrt(d2)` would be; for the
		# fast path we just return a clearly-negative magnitude that
		# preserves "further out = more negative" ordering used by
		# `_seabed_layer_at`.
		return 1.0 - sqrt(d2)
	var dist: float = sqrt(d2)
	if coastline_noise != null:
		dist += coastline_noise.get_noise_2d(q, r) * coastline_warp
	return 1.0 - dist


## True if the coord is inside the landmass (above sea level potential).
func is_land(q: float, r: float) -> bool:
	return land_factor(q, r) > 0.0


## Smooth 0..1 scalar that ramps up from 0 at the coast to 1 well
## inland. Useful for tapering elevation so beaches don't start as
## vertical cliffs. `falloff` controls how quickly the ramp saturates.
func coast_blend(q: float, r: float, falloff: float = 4.0) -> float:
	var lf: float = land_factor(q, r)
	if lf <= 0.0:
		return 0.0
	return clampf(lf * falloff, 0.0, 1.0)
