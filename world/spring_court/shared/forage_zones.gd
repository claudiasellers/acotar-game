## Keys Spring Court forage to L09's landscape zones (LandscapeLayout.zone):
## shade things (mushrooms, moss, bluebells, ramsons, galls, owl feathers)
## under the grove core, hedgerow things (brambles, hips, haws, sloes, hazel,
## honeysuckle, primroses, foxgloves) along the feathered wood edge, and
## meadow things (clover, cowslips, thyme, poppies, chamomile) out in the
## open. Water, stones and dropped trinkets follow their habitat alone.
##
## The edge is the richest ground (the ecotone), so forage gathers there a
## little, with the region's total held where it was.
## Pure and deterministic; the woods and wider-court generators call it from
## worker threads. Loaded by path (no class_name), like LandscapeLayout.
extends RefCounted

const LandscapeLayout := preload("res://world/spring_court/shared/landscape_layout.gd")

## Affinity (open, edge, core) per kind. Neutral is (1, 1, 1).
const SHADE := Vector3(0.12, 0.55, 1.0)
const HEDGE := Vector3(0.25, 1.0, 0.3)
const MEADOW := Vector3(1.0, 0.4, 0.06)
const NEUTRAL := Vector3.ONE

## Matched against the item id with "ing_"/"col_" stripped, by substring.
const SHADE_WORDS := ["moss", "wild_garlic", "wood_sorrel", "wild_hyacinth", "sweet_woodruff", "chanterelle",
	"fly_agaric", "glowcap", "dreamcap", "tinder_fungus", "chaga", "oak_gall", "acorn", "birch_bark",
	"grey_lichen", "old_mans_beard", "owl_feather", "mistletoe", "pine_resin", "pinecone", "nightshade",
	"hollow_root", "snail", "violet", "snowdrop", "faerie_bread"]
const HEDGE_WORDS := ["blackberry", "rose_hip", "sloe", "hawthorn", "hazelnut", "elderflower", "honeysuckle",
	"rowan_berry", "bilberry", "wild_strawberry", "foxglove", "primrose", "cherry", "spring_apple", "quince",
	"honeyplum", "lilac", "wisteria", "nettle", "juniper", "thornbriar", "madder", "woad", "mugwort",
	"jay_feather", "robin_egg", "wren_feather", "spider_silk", "feather_pheasant", "ember_maple"]
const MEADOW_WORDS := ["clover", "dandelion", "yarrow", "chamomile", "cowslip", "lavender", "wild_thyme",
	"heather", "red_poppy", "cornflower", "meadowsweet", "crocus", "moonflower", "hawk_feather", "seed_pod",
	"wool_tuft", "beetle_jewel", "fae_bell"]

## Relative richness of each zone (open, edge, core) for whole clusters.
const RICHNESS := Vector3(0.8, 1.25, 0.85)


static func affinity(item_id: StringName) -> Vector3:
	var s := String(item_id).trim_prefix("ing_").trim_prefix("col_")
	for w: String in SHADE_WORDS:
		if s.contains(w):
			return SHADE
	for w: String in HEDGE_WORDS:
		if s.contains(w):
			return HEDGE
	for w: String in MEADOW_WORDS:
		if s.contains(w):
			return MEADOW
	return NEUTRAL


## The zone at a point as (open, edge, core) shares summing to 1.
static func shares(layout: Dictionary, p: Vector2, open: float) -> Vector3:
	var zn := LandscapeLayout.zone(LandscapeLayout.stand_at(layout, p.x, p.y), open)
	var grove: float = zn["grove"]
	return Vector3(1.0 - grove, zn["edge"], grove * float(zn["core"]))


## How well `item_id` fits a spot with zone `shares` (1 = neutral).
static func fit(item_id: StringName, s: Vector3) -> float:
	return affinity(item_id).dot(s)


## Chance a cluster centred in this zone is kept, out of RICHNESS's best.
static func keep_chance(s: Vector3) -> float:
	return RICHNESS.dot(s) / maxf(RICHNESS.x, maxf(RICHNESS.y, RICHNESS.z))


## Which zone a share vector mostly is: 0 open, 1 edge, 2 core.
static func dominant(s: Vector3) -> int:
	return 0 if s.x >= s.y and s.x >= s.z else (1 if s.y >= s.z else 2)
