## Which free-roam line fits right now (lane L34). Pure and static, so tests
## can drive it without a world. `ctx` keys:
##   phase: StringName      PhaseManager.current_phase
##   hour: float            Clock.hour()
##   places: PackedStringArray  where Feyre is: region, zone (manor_house /
##                          manor_grounds), room, and any place she stands in
##   flag: Callable(String) -> bool   WorldState.has_flag
##   now: float             seconds, for cooldowns
##   said_at: Dictionary    line id -> last time spoken (repeatable lines)
class_name DialogueRules
extends RefCounted


## Speaker keys a CourtNpc / family member / cast actor answers to: its own
## id, then the group key lines may use instead.
static func keys_for(npc_id: StringName) -> PackedStringArray:
	var id := String(npc_id)
	var out := PackedStringArray([id])
	var group := group_of(id)
	if group != "":
		out.append(group)
	return out


static func group_of(id: String) -> String:
	if id.begins_with("human_"):
		return "villager"
	if id.begins_with("fae_") and id not in ["fae_greenbrown", "fae_longlimb"]:
		return "court_fae"
	if id.begins_with("servant_") or id in ["fae_greenbrown", "fae_longlimb"]:
		return "servant"
	if id.begins_with("gardener_"):
		return "gardener"
	if id.begins_with("sentry_"):
		return "sentry"
	if id.begins_with("reveler_"):
		return "reveler"
	return ""


## True when the line may play in this context (ignores the trigger kind).
static func fits(line: DialogueLine, ctx: Dictionary) -> bool:
	if not line.phases.is_empty() and not line.phases.has(String(ctx.get("phase", &""))):
		return false
	if not line.fits_hour(float(ctx.get("hour", 12.0))):
		return false
	var flag: Callable = ctx.get("flag", func(_f: String) -> bool: return false)
	for f in line.require_flags:
		if not flag.call(f):
			return false
	for f in line.forbid_flags:
		if flag.call(f):
			return false
	if line.once:
		if flag.call(line.heard_flag()):
			return false
	else:
		var said: Dictionary = ctx.get("said_at", {})
		if said.has(line.id) and float(ctx.get("now", 0.0)) - float(said[line.id]) < line.cooldown:
			return false
	if line.where != &"" and line.trigger in [DialogueLine.Trigger.NEAR_SPEAKER, DialogueLine.Trigger.DEED]:
		var places: PackedStringArray = ctx.get("places", PackedStringArray())
		if not places.has(String(line.where)):
			return false
	return true


## The best line of `candidates` that fits: once-lines before repeatable
## ones, then by priority; ties keep authoring order. null when none fits.
static func pick(candidates: Array, ctx: Dictionary) -> DialogueLine:
	var best: DialogueLine = null
	var best_score := -INF
	for line: DialogueLine in candidates:
		if not fits(line, ctx):
			continue
		var score := float(line.priority) + (1000.0 if line.once else 0.0)
		if score > best_score:
			best = line
			best_score = score
	return best
