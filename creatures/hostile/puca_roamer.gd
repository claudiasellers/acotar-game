## The roaming puca (hostile plan §5.2, health-interactions §4.2, bestiary §9):
## a night lure. By day there is nothing there. At night it shows itself as
## something Feyre wants, read from her state (pick_lure), and keeps just out
## of reach, drifting ahead at walk pace toward the nearest camp's leash. When
## she is inside that leash it is gone: whatever lives there is the danger.
## It never touches her (the Keeper, ch11): no contact rows. Too close and it
## slips away; two hits and it flees; a light arrow shows its true form for
## REVEAL_SECONDS and then it flees; ash kills it; iron does nothing.
##
## The tell (plan §5.2) is `tell`, 0 to 1: how strongly its wrongness shows
## to her from where she stands. It reaches TELL_RANGE bare and
## KEEN_TELL_RANGE with a full keen brew. The disguise material reads it as
## the instance uniform `puca_tell` (TELL_PARAM) when it lands; until then the
## placeholder body only carries the value. It casts no shadow and leaves no
## prints at any time.
##
## The story's ch10-11 garden puca is creatures/fae/puca.gd; this one roams.
class_name PucaRoamer
extends Creature

signal image_changed(image: StringName)
## It darted away (two hits, a light arrow's reveal running out, or she came
## too near while it was revealed).
signal darted
## It is gone for the night: fled, or she followed it into a camp's leash.
signal gone

enum State { HIDDEN, LURING, REVEALED, FLEEING }

const FAMILY := &"puca"
const TRUE_FORM := &"true_form"
## Every image it can wear. Each one is a real thing's model through the
## disguise (bestiary §9.2): the ash bow and quiver, a gold-rose glint, a
## gown, her father, her sisters.
const LURES: Array[StringName] = [&"quiver", &"gold_rose", &"gown", &"father", &"sisters"]
const GOLD_ROSE := &"ing_rose_gold"
## Arrows below this share of her quiver and a full quiver is what she wants.
const QUIVER_LOW := 1.0 / 3.0
## Night (health-interactions §4.2): 20:00 to 05:00.
const NIGHT_FROM := 20.0
const NIGHT_TO := 5.0
## Distances (flat, m): it keeps about KEEP_M ahead; nearer than CLOSE_M it
## slips away fast; she is following while within FOLLOW_M, and it waits,
## beckoning, when she hangs back further; NOTICE_M is where its image first
## startles her.
const KEEP_M := 9.0
const CLOSE_M := 4.0
const FOLLOW_M := 25.0
const NOTICE_M := 30.0
## Each new image adds this much startle (health-interactions §4.2).
const STARTLE := 0.1
## Hits it takes before it flees, and how long a flight lasts.
const FLEE_HITS := 2
const FLEE_SECONDS := 1.5
## A light arrow holds its true form this long.
const REVEAL_SECONDS := 3.0
## It leads toward the nearest camp within this.
const LEAD_RANGE := 400.0
## The tell: visible out to TELL_RANGE bare, KEEN_TELL_RANGE at keen 1.0, at
## full strength inside TELL_FULL of that reach. TELL_SHOWN is the strength the
## disguise makes readable. Rows in docs/tuning.md, "Puca (L75)".
const TELL_RANGE := 8.0
const KEEN_TELL_RANGE := 40.0
const TELL_FULL := 0.4
const TELL_SHOWN := 0.25
const TELL_PARAM := &"puca_tell"

var state: State = State.HIDDEN
## The image it wears now: one of LURES, TRUE_FORM, or &"" when hidden.
var showing: StringName = &""
## Where it rests by day and drifts back to when she is gone.
var home: Vector3
var tell: float = 0.0
var hits_taken: int = 0
## The camp it is leading her toward, or null.
var lure_site: HostileSite
## Clock for REVEALED and FLEEING.
var state_left: float = 0.0
## Hooks for tests and story: the clock, and who it lures (empty: the
## node in group "player").
var hour_func: Callable = func() -> float: return Clock.hour()
var day_func: Callable = func() -> int: return Clock.day
var player_func: Callable

var _startled: bool = false
var _away: Vector3 = Vector3.FORWARD
var _layer: int = 0
## The night it last vanished (night_of), so it rests until the next one.
var _rested_night: int = -999999


func _ready() -> void:
	super._ready()
	home = global_position
	_layer = collision_layer
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hide()


func _player() -> Node3D:
	if player_func.is_valid():
		return player_func.call() as Node3D
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Node3D


## What she wants most, from her state (plan §5.2, slice 2(a)). `wants` is
## wants_of()'s dictionary. A low quiver first (a hunter's need), then the
## gold rose missing from her book; otherwise it is her family, or on every
## third night, while her wardrobe is unfinished, a gown.
static func pick_lure(wants: Dictionary) -> StringName:
	var size := int(wants.get("quiver_size", Inventory.FULL_QUIVER))
	if size > 0 and float(wants.get("arrows", size)) < float(size) * QUIVER_LOW:
		return &"quiver"
	if not bool(wants.get("has_gold_rose", true)):
		return &"gold_rose"
	var night := int(wants.get("night", 0))
	if int(wants.get("wardrobe_missing", 0)) > 0 and posmod(night, 3) == 0:
		return &"gown"
	return &"father" if posmod(night, 2) == 1 else &"sisters"


## Her state as pick_lure reads it: arrows in the quiver and its size, whether
## the book has the gold rose, wardrobe pieces she doesn't own, and the night.
static func wants_of(inventory: Inventory, book: CollectionBook, wardrobe: Wardrobe, night: int) -> Dictionary:
	var arrows := 0
	var size := Inventory.FULL_QUIVER
	if inventory:
		var quiver := inventory.contents(Inventory.QUIVER)
		for id in quiver:
			arrows += int(quiver[id])
		size = int(inventory.capacity(Inventory.QUIVER))
	var missing := 0
	if wardrobe:
		for p in WardrobeCatalog.all_pieces():
			if not wardrobe.owns(p.id):
				missing += 1
	return {"arrows": arrows, "quiver_size": size,
		"has_gold_rose": book != null and book.is_found(GOLD_ROSE),
		"wardrobe_missing": missing, "night": night}


static func is_night(hour: float) -> bool:
	return hour >= NIGHT_FROM or hour < NIGHT_TO


## Which night an hour belongs to: the small hours count with the evening before.
static func night_of(day: int, hour: float) -> int:
	return day - 1 if hour < NIGHT_TO else day


## How strongly the tell shows at `distance` with keen brew `keen` (0 to 1+).
static func tell_strength(distance: float, keen: float) -> float:
	var reach := lerpf(TELL_RANGE, KEEN_TELL_RANGE, clampf(keen, 0.0, 1.0))
	if distance >= reach:
		return 0.0
	return clampf((reach - distance) / (reach * (1.0 - TELL_FULL)), 0.0, 1.0)


## Her keen brew's strength (BodyState effect &"keen"), 0 without one.
static func keen_of(player: Node) -> float:
	var body := player.get(&"body_state") as BodyState if player else null
	return body.effect(&"keen") if body else 0.0


func _think(delta: float) -> void:
	move_direction = Vector3.ZERO
	move_speed = 0.0
	var player := _player()
	var hour := float(hour_func.call())
	match state:
		State.HIDDEN:
			if is_night(hour) and night_of(int(day_func.call()), hour) != _rested_night:
				appear()
		State.LURING:
			if not is_night(hour):
				_hide()
			else:
				_lure(player)
		State.REVEALED:
			state_left -= delta
			if state_left <= 0.0:
				flee(player.global_position if player else global_position + global_basis.z)
		State.FLEEING:
			state_left -= delta
			move_direction = _away
			move_speed = data.run_speed
			if state_left <= 0.0:
				vanish()
	update_tell(player)


## Nightfall: it wears what she wants and starts to lure.
func appear() -> void:
	var night := night_of(int(day_func.call()), float(hour_func.call()))
	_show(PucaRoamer.pick_lure(PucaRoamer.wants_of(Gameplay.inventory, Gameplay.collection,
			Gameplay.wardrobe, night)))
	state = State.LURING
	hits_taken = 0
	_startled = false
	model.visible = true
	collision_layer = _layer


## Just ahead, never caught: drift toward the camp at walk pace while she
## follows, wait while she lags, slip away when she closes, go home when she
## is gone, and be gone once she is inside the camp's leash.
func _lure(player: Node3D) -> void:
	if player == null:
		_go_home()
		return
	var to_her := player.global_position - global_position
	to_her.y = 0.0
	var gap := to_her.length()
	if gap > data.sight_range:
		_go_home()
		return
	if not _startled and gap <= NOTICE_M:
		_startled = true
		EventBus.player_startled.emit(creature_id, STARTLE)
	lure_site = nearest_site()
	if lure_site and lure_site.in_leash(player.global_position):
		vanish()
		return
	face_towards(player.global_position, get_physics_process_delta_time())
	if gap > FOLLOW_M:
		return
	var lead := lead_direction(player.global_position)
	if gap < CLOSE_M:
		move_direction = lead
		move_speed = data.run_speed
	elif gap < FOLLOW_M:
		move_direction = lead
		move_speed = data.walk_speed if gap < KEEP_M * 1.5 else data.walk_speed * 0.5


## Toward the camp it leads to (or straight away from her without one), but
## never past her: when the camp is behind her it backs away instead.
func lead_direction(her: Vector3) -> Vector3:
	var away := global_position - her
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -global_basis.z
	if lure_site == null:
		return away
	var to_site := lure_site.global_position - global_position
	to_site.y = 0.0
	if to_site.length_squared() < 0.0001:
		return away
	to_site = to_site.normalized()
	return to_site if to_site.dot(-away) < 0.3 else away


## The nearest camp that still stands, within LEAD_RANGE.
func nearest_site() -> HostileSite:
	if not is_inside_tree():
		return null
	var best: HostileSite = null
	var best_d := LEAD_RANGE
	for node in get_tree().get_nodes_in_group(HostileSite.GROUP):
		var s := node as HostileSite
		if s == null or s.is_settled or s.is_queued_for_deletion():
			continue
		var d := Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best


func _go_home() -> void:
	var to := home - global_position
	to.y = 0.0
	if to.length() > 1.0:
		move_direction = to
		move_speed = data.walk_speed


## How strongly its wrongness shows to her now (the disguise reads `tell`).
func update_tell(player: Node3D) -> void:
	if player == null or state == State.HIDDEN or showing == TRUE_FORM:
		tell = 1.0 if showing == TRUE_FORM else 0.0
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	tell = PucaRoamer.tell_strength(d, PucaRoamer.keen_of(player))


## Two hits and it flees (health-interactions §4.2). Ash kills it outright.
func apply_hit(cause: StringName, weapon_id: StringName, weapon_mult: float, zone: StringName,
		at: Vector3) -> Dictionary:
	var result := super.apply_hit(cause, weapon_id, weapon_mult, zone, at)
	if alive and state == State.LURING:
		hits_taken += 1
		if hits_taken >= FLEE_HITS:
			var p := _player()
			flee(p.global_position if p else at)
	return result


## A light arrow "burns white": its true form shows, and then it flees.
func on_arrow_effect(effect: StringName, arrow: Node3D) -> void:
	if effect == &"light":
		reveal()
		return
	super.on_arrow_effect(effect, arrow)


func reveal() -> void:
	if not alive or state == State.HIDDEN:
		return
	state = State.REVEALED
	state_left = REVEAL_SECONDS
	_show(TRUE_FORM)


## It shimmers and darts away from `from`, then is gone.
func flee(from: Vector3) -> void:
	if state == State.FLEEING or state == State.HIDDEN:
		return
	_away = global_position - from
	_away.y = 0.0
	_away = _away.normalized() if _away.length_squared() > 0.0001 else -global_basis.z
	state = State.FLEEING
	state_left = FLEE_SECONDS
	darted.emit()


## Gone for the night: it rests at home, unseen, until the next one.
func vanish() -> void:
	_rested_night = night_of(int(day_func.call()), float(hour_func.call()))
	_hide()
	global_position = home
	velocity = Vector3.ZERO
	gone.emit()


func _hide() -> void:
	state = State.HIDDEN
	showing = &""
	tell = 0.0
	if model:
		model.visible = false
	collision_layer = 0


func _show(image: StringName) -> void:
	if image == showing:
		return
	showing = image
	image_changed.emit(image)


## What it leaves is nothing: it's gone.
func die(cause: StringName) -> void:
	super.die(cause)
	if harvestable and is_instance_valid(harvestable):
		harvestable.queue_free()
		harvestable = null
	if model:
		model.visible = false
	showing = &""
	gone.emit()
