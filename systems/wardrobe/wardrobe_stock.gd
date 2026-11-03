## How every wardrobe piece reaches Feyre, and the dressing room's restock as
## the story moves (lane L64). Purely aesthetic: arriving pieces are looks,
## never stats or gates.
##
## Pieces from the house (the manor wardrobe, Alis, the stables, the painting
## room, the seamstress, the Calanmai things, Alis's gifts) hang in a wardrobe
## from their phase on: opening one after a phase change is when they arrive.
## Her cottage things are hers from the start; story pieces come with their
## beats; woven crowns are crafted from forage.
class_name WardrobeStock
extends RefCounted

const COTTAGE := &"cottage_chest"

## source -> where it comes from, as the collection page might say it.
## A source missing here would be a piece no one can ever get (tested).
const ROUTES := {
	&"cottage_chest": "hers from the cottage",
	&"woven": "woven from flowers she gathers",
	&"story": "given at a turn of the story",
	&"manor_wardrobe": "the manor wardrobe",
	&"alis": "the manor wardrobe, from Alis",
	&"alis_gift": "the manor wardrobe, a gift from Alis",
	&"stables": "the manor wardrobe, from the stables",
	&"painting_room": "the manor wardrobe, from the painting room",
	&"seamstress": "the manor wardrobe, from the seamstress",
	&"calanmai": "the manor wardrobe, readied for Calanmai",
}
## Sources that restock into a wardrobe by phase. The cottage is in it so
## older saves pick up cottage pieces added later.
const ROOM_SOURCES: Array[StringName] = [
	&"cottage_chest", &"manor_wardrobe", &"alis", &"alis_gift", &"stables",
	&"painting_room", &"seamstress", &"calanmai",
]
## No phase ladder running (shots, sandboxes): everything is due.
const ALL_PHASES := 99


## "p3_house_and_woods" -> 3. Anything that isn't a "pN_" id means no ladder.
static func phase_index(phase_id: StringName) -> int:
	var s := String(phase_id)
	if s.length() < 2 or s[0] != "p" or not s[1].is_valid_int():
		return ALL_PHASES
	var digits := ""
	for i in range(1, s.length()):
		if not s[i].is_valid_int():
			break
		digits += s[i]
	return int(digits)


static func current_phase() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var pm: Node = tree.root.get_node_or_null(^"/root/PhaseManager") if tree else null
	return phase_index(StringName(pm.get(&"current_phase")) if pm else &"")


## The pieces a wardrobe holds at `phase`.
static func due(phase: int) -> Array[WardrobePiece]:
	var out: Array[WardrobePiece] = []
	for p in WardrobeCatalog.all_pieces():
		if ROOM_SOURCES.has(p.source) and p.phase <= phase:
			out.append(p)
	return out


## Hangs everything due at `phase` that she doesn't have yet. Returns the new
## ids; they are New (Wardrobe.unseen) until she looks at them.
static func restock(wardrobe: Wardrobe, phase: int = -1) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for p in due(current_phase() if phase < 0 else phase):
		if wardrobe.grant(p.id, true):
			fresh.append(p.id)
	return fresh


## "3 new gowns" style line for a batch of arrivals, or "" for none.
static func arrivals_line(ids: Array[StringName]) -> String:
	if ids.is_empty():
		return ""
	var by_source := {}
	for id in ids:
		var p := WardrobeCatalog.piece(id)
		if p:
			by_source[p.source] = int(by_source.get(p.source, 0)) + 1
	var top: StringName = &""
	for s: StringName in by_source:
		if top == &"" or by_source[s] > by_source[top]:
			top = s
	var where := {&"seamstress": " from the seamstress", &"alis_gift": ", gifts from Alis",
		&"calanmai": " for Calanmai", &"stables": " from the stables", &"cottage_chest": " from home"}
	var n := ids.size()
	return "%d new thing%s hang%s here%s" % [n, "" if n == 1 else "s", "s" if n == 1 else "",
		where.get(top, "") if by_source.size() == 1 else ""]
