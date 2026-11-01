## Feyre's thought when the Suriel beat opens (Lucien has told her how, in the
## study: fact.suriel_method_known) and she has nothing to tie the loops with:
## the gardener's twine in the kitchen garden's potting shed. Again, plainer,
## if she tries to rig the snare without cordage. Shown on the GuideJournal
## card like Act I's landmark thoughts (the world teaches, the card confirms).
class_name SnareKitThought
extends Node

const THREAD := "res://data/story/suriel/snare_kit_thought.tres"
const OPEN_FLAG := "fact.suriel_method_known"

static var _thread: GuideThread


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag)


func _on_flag(flag: String, value: Variant) -> void:
	if flag == OPEN_FLAG and value and SnarePlan.loops_from(Gameplay.inventory) < 2:
		SnareKitThought.think(get_tree(), 0)


## Shows tier `tier` of the twine thought on Feyre's card. False if there is
## no card to show it on (tests, cutscenes) or she already has the twine.
static func think(tree: SceneTree, tier: int) -> bool:
	if tree == null or SnarePlan.loops_from(Gameplay.inventory) >= 2:
		return false
	if _thread == null:
		_thread = load(THREAD) as GuideThread
	for node in tree.root.find_children("*", "CanvasLayer", true, false):
		var card := node as GuideJournal
		if card and card.can_show():
			card.show_thought(_thread, clampi(tier, 0, _thread.tier_count() - 1), false)
			return true
	return false
