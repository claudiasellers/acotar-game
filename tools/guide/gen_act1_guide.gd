## Builds data/guide/act1_guide.tres: Feyre's thoughts for Act I, the
## cottage to the first evening past the wall (plans/guidance-journal.md).
## Tier 0 lines are the keeper's (plans/voice-lines-act1.md, H1_*); tiers 1-2
## are plainer nudges in her voice, invented where the book is silent (X).
## The ride north (beast_claim_accepted until wall_crossed) is scripted, so it
## deliberately has no thread.
##   godot --headless --path . -s tools/guide/gen_act1_guide.gd
extends SceneTree

const OUT := "res://data/guide/act1_guide.tres"
const NOT_YET_MET: Array[String] = ["beast", "faerie", "fae", "tamlin", "lucien",
	"prythian", "murderer", "high lord", "spring court"]

const THREADS: Array[Dictionary] = [
	{
		"id": &"hunt", "priority": 40, "icon": &"larder", "canon": "X",
		"require": [], "done": ["wolf_killed"],
		"lines": [
			"Last loaf's gone. If I come back with nothing, we don't eat.",
			"Deer come down the trail past our door at first light. Quiet feet. Patience.",
			"Up the deer trail from the door and into the trees, before the snow fills the tracks.",
		],
		"voice": ["H1_hunger", "", ""],
		"forbid": ["wolf", "wall", "mercenary", "village"],
	},
	{
		"id": &"skin", "priority": 30, "icon": &"knife", "canon": "X",
		"require": ["wolf_killed"], "done": ["fact.wolf_skinned"],
		"lines": [
			"I can't leave a pelt like that to the snow.",
			"My knife, before the cold sets it stiff.",
			"Kneel by the kill and take the pelt.",
		],
		"voice": ["", "", ""],
		"forbid": ["wall", "mercenary"],
	},
	{
		"id": &"sell", "priority": 20, "icon": &"coins", "canon": "X",
		"require": ["wolf_killed", "fact.wolf_skinned"], "done": ["pelt_sold"],
		"lines": [
			"A pelt that size is worth more at market than on our floor.",
			"The road runs down to the village. Someone at the market always buys furs.",
			"Take the pelt to the fur stall in the village square.",
		],
		"voice": ["H1_pelt", "", ""],
		"forbid": ["wall", "mercenary", "scars"],
	},
	{
		"id": &"home", "priority": 10, "icon": &"hearth", "canon": "V",
		"require": ["pelt_sold"], "done": ["beast_claim_accepted"],
		"lines": [
			"Stay together. Look after them.",
			"They'll be by the fire tonight, waiting on what I bring home.",
			"Home to the cottage before dark, and stay the night with them.",
		],
		"voice": ["H1_promise", "", ""],
		"forbid": ["door", "wall", "bracelet", "claim"],
	},
	{
		"id": &"quiet", "priority": 10, "icon": &"rose", "canon": "A",
		"require": ["wall_crossed"], "done": ["first_dinner_eaten"],
		"lines": [
			"Too much quiet for a place this beautiful.",
			"Learn the grounds. Every path and every gate, before I need them.",
			"The great house is the only place with its lamps lit. Someone there will expect me.",
		],
		"voice": ["H1_quiet", "", ""],
		"forbid": ["mask", "alis", "curse", "amarantha", "andras"],
	},
]


func _init() -> void:
	var book := GuideBook.new()
	for spec in THREADS:
		var t := GuideThread.new()
		t.id = spec.id
		# Fixed ids so regenerating never makes diff noise (R15).
		t.resource_scene_unique_id = "thread_%s" % spec.id
		t.priority = spec.priority
		t.icon = spec.icon
		t.canon = spec.canon
		t.require_flags = PackedStringArray(spec.require)
		t.done_flags = PackedStringArray(spec.done)
		t.lines = PackedStringArray(spec.lines)
		t.voice_ids = PackedStringArray(spec.voice)
		var forbid := PackedStringArray(NOT_YET_MET)
		forbid.append_array(PackedStringArray(spec.forbid))
		t.forbidden_words = forbid
		book.threads.append(t)
	var err := ResourceSaver.save(book, OUT)
	print("gen_act1_guide: %d threads -> %s (%s)" % [book.threads.size(), OUT, error_string(err)])
	quit(0 if err == OK else 1)
