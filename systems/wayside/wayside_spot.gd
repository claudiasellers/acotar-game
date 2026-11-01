## One thing to find, watch or do on a walk between places (L23): a painter's
## rest, the corner shimmer, a doe, a hidden nook, stepping stones, a snare.
## Written by tools/wayside/wayside_gen.gd into data/wayside/<route>.tres;
## the Wayside director builds the matching node when Feyre comes near.
## No markers and no objective text (R2): each spot is found by looking.
class_name WaysideSpot
extends Resource

## What it is; Wayside.KINDS maps each kind to its node script.
@export var kind: StringName
## Unique across every route; the WorldDeltas key under region "wayside".
@export var id: StringName
## World position on the ground (y from WorldHeight at generation).
@export var position: Vector3
@export var yaw: float = 0.0
## Where it points: the view a rest frames, the far bank a crossing reaches,
## the sycamore or stream a shimmer turns into.
@export var target: Vector3
## Items found there (ing_* or col_* ids), in order.
@export var items: PackedStringArray = PackedStringArray()
## Feyre's thought when it happens (her voice: short, dry, practical).
@export var line: String = ""
## Shown only while every one of these WorldState flags is set...
@export var require_flags: PackedStringArray = PackedStringArray()
## ...and none of these.
@export var forbid_flags: PackedStringArray = PackedStringArray()
## Free per-kind settings (counts, radii, creature scene, sketch title).
@export var params: Dictionary = {}
## Lore confidence (R7): "C", "C?" or "X", with the book chapter in `source`.
@export var canon: String = "X"
@export var source: String = ""


func is_active(flags: Callable) -> bool:
	for f in require_flags:
		if not flags.call(f):
			return false
	for f in forbid_flags:
		if flags.call(f):
			return false
	return true


func param(key: String, default: Variant = null) -> Variant:
	return params.get(key, default)
