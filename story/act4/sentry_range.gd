## The sentries' bow range below the North Watchtower on the fells (L44,
## GAME_DESIGN_PLAN §2 "Western Fells: bow range, climbing, upgraded bow";
## bows ladder §4.3: 4 = sentry warbow, from the fells tower). Canon [X]:
## Tamlin's sentries [C] keep watchtowers in the fells [X].
## Three straw butts at 20, 35 and 55 m. Every arrow in the rings rings out
## (pearl, periwinkle, rose, gold: bigger bursts nearer the heart). Hitting
## all three in one visit clears the range: a sheaf of arrows, once a day.
## The sentries' chest by the tower holds the warbow; it opens for whoever
## has cleared the range (fact.fells_range_cleared), once
## (fact.sentry_warbow_taken). Items and facts only, never a phase flag.
class_name SentryRange
extends Node3D

signal struck(butt: int, ring: int)
signal cleared

const RINGS := [0.16, 0.30, 0.46, 0.64]  # gold, rose, periwinkle, pearl radii (m)
const RING_NAMES := ["gold", "rose", "periwinkle", "pearl"]
## Anchor-local: the shooting line at the origin, shooting toward -Z.
const BUTTS := [Vector3(-3.0, 0.0, -20.0), Vector3(2.5, 0.0, -35.0), Vector3(-1.0, 0.0, -55.0)]
const CHEST := Vector3(-11.0, 0.0, 3.5)
const ARROWS_FOR_CLEAR := 6

var butts: Array[SentryButt] = []
var chest: SentryChest
## Butts struck this visit (index -> best ring).
var hits: Dictionary = {}
var cleared_day: int = -1


func _ready() -> void:
	_dress()


func _dress() -> void:
	for i in BUTTS.size():
		var at := to_global(BUTTS[i])
		var b := SentryButt.new()
		b.name = "Butt%d" % (i + 1)
		b.index = i
		add_child(b)
		b.global_position = Act4Walk.ground_point(self, at)
		Act4Walk.face(b, to_global(Vector3.ZERO))
		b.struck.connect(_on_struck)
		butts.append(b)
	var line := Node3D.new()
	line.name = "ShootingLine"
	add_child(line)
	Act4Props.place(line, &"bow_rack", to_global(Vector3(-4.5, 0, 2.5)), to_global(Vector3(-4.5, 0, -10)))
	Act4Props.place(line, &"quiver_barrel", to_global(Vector3(2.2, 0, 1.2)), to_global(Vector3.ZERO))
	Act4Props.place(line, &"quiver_barrel", to_global(Vector3(3.0, 0, 1.8)), to_global(Vector3.ZERO))
	Act4Props.place(line, &"weapon_rack", to_global(Vector3(-8.0, 0, 4.0)), to_global(Vector3(-8.0, 0, -10)))
	Act4Props.place(line, &"hay_bale", to_global(Vector3(5.0, 0, 3.0)), to_global(Vector3.ZERO))
	Act4Props.place(line, &"faelight_lantern", to_global(Vector3(-1.8, 0, 0.6)), to_global(Vector3(0, 0, -10)))
	Act4Props.place(line, &"faelight_lantern", to_global(Vector3(1.8, 0, 0.6)), to_global(Vector3(0, 0, -10)))
	chest = SentryChest.new()
	chest.name = "WarbowChest"
	chest.range = self
	add_child(chest)
	chest.global_position = Act4Walk.ground_point(self, to_global(CHEST))
	Act4Walk.face(chest, to_global(Vector3(-4.0, 0, 0)))


func _on_struck(index: int, ring: int) -> void:
	struck.emit(index, ring)
	if ring < 0:
		return
	hits[index] = mini(int(hits.get(index, 99)), ring)
	if hits.size() == BUTTS.size() and cleared_day != Clock.day:
		cleared_day = Clock.day
		_clear()


func _clear() -> void:
	hits.clear()
	var trigger := ActionTrigger.new()
	trigger.name = "Raise_fells_range_cleared"
	trigger.flag = "fact.fells_range_cleared"
	trigger.fire_on_body_enter = false
	trigger.monitoring = false
	trigger.monitorable = false
	add_child(trigger)
	trigger.fire()
	trigger.queue_free()
	EventBus.story_item_granted.emit(&"arrow_wood", ARROWS_FOR_CLEAR)
	EventBus.celebration_requested.emit(&"unlock", global_position)
	cleared.emit()


## Ring a hit lands in (0 gold .. 3 pearl), or -1 for the straw outside them.
static func ring_for(offset: float) -> int:
	for i in RINGS.size():
		if offset <= RINGS[i]:
			return i
	return -1
