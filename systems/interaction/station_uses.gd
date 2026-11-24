## Runs the manor stations' small real uses (StationUse rows in
## data/stations/uses/): the pianoforte and harp, the library writing desk, the
## bow rack, the infirmary, her bed and her bath. The Interactor asks `of(id)`
## for the row and `perform` to do it; a station with no row, or one shut in
## this phase, is not a target, so E never silently does nothing there.
class_name StationUses
extends RefCounted

const DIR := "res://data/stations/uses/"
## She sleeps from evening (19:00) to before dawn (05:00) through to 07:00.
const NIGHT_FROM := 19.0
const NIGHT_TO := 5.0
const MORNING := 7.0
## How long the warmth of a bath lasts (seconds of play) and how strong it is.
const BATH_WARM_SECONDS := 600.0
const BATH_WARM := 1.0
## A thought after a few notes waits this long before another (ms).
const PLAY_THOUGHT_GAP_MS := 20000
const FACT_DAY := "fact.station.%s.day"
const FACT_LETTERS := "fact.letters_practised"

static var _rows: Dictionary = {}
static var _last_play_thought_ms: Dictionary = {}
static var _busy: bool = false


## The row for `station_id`, or null when it has none.
static func of(station_id: StringName) -> StationUse:
	if _rows.is_empty():
		_load()
	return _rows.get(station_id) as StationUse


## The prompt verb when E would use this station now, else "".
static func verb(station_id: StringName) -> String:
	var row := of(station_id)
	if row == null or not row.open_now() or _busy:
		return ""
	return row.day_verb if row.kind == "sleep" and row.day_verb != "" and not is_night() else row.verb


static func is_night() -> bool:
	var hour := Clock.hour()
	return hour >= NIGHT_FROM or hour < NIGHT_TO


## Does the row's thing. False when it is shut now (another phase, a scene
## holding her, already sleeping), so E falls through.
static func perform(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	if row == null or not row.open_now() or _busy:
		return false
	match row.kind:
		"play":
			return _play(interactor, station, row)
		"letters":
			return _letters(interactor, station, row)
		"arrows":
			return _arrows(interactor, station, row)
		"tend":
			return _tend(interactor, station, row)
		"sleep":
			return _sleep(interactor, row)
		"soak":
			return _soak(interactor, station, row)
	return false


static func _play(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	# A pentatonic step each press, so a few presses make a little tune.
	var step: float = Juice.COMBO_STEPS[randi() % Juice.COMBO_STEPS.size()]
	Juice.burst(station, row.station_id, Vector3.ZERO, step)
	var vitals := Vitals.of(interactor.feyre)
	if vitals:
		vitals.ease_moment_from("station:%s" % row.station_id)
	var now := Time.get_ticks_msec()
	var last := int(_last_play_thought_ms.get(row.station_id, -PLAY_THOUGHT_GAP_MS))
	if now - last >= PLAY_THOUGHT_GAP_MS:
		_last_play_thought_ms[row.station_id] = now
		_think(interactor, _any(row.lines))
	return true


static func _letters(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	if _used_today(row):
		_think(interactor, _any(row.alt_lines))
		return true
	_mark_today(row)
	var practised := int(WorldState.get_flag(FACT_LETTERS, 0)) + 1
	WorldState.set_flag(FACT_LETTERS, practised)
	Clock.advance(row.minutes)
	# Private and ashamed (Keeper, ch 13): a small chime, no fanfare.
	Juice.burst(station, &"pickup")
	_think(interactor, row.lines[mini(practised, row.lines.size()) - 1] if not row.lines.is_empty() else "")
	return true


static func _arrows(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	var inv := Gameplay.inventory
	var want := row.fill_to - inv.count(row.item_id)
	var room := inv.room_for(row.item_id, maxi(want, 0))
	if _used_today(row) or room <= 0:
		_think(interactor, _any(row.alt_lines))
		return true
	_mark_today(row)
	var added := inv.add(row.item_id, room)
	interactor.feyre.quiver_changed.emit(inv.arrow_count())
	interactor.picked_up(row.item_id, added, station)
	_think(interactor, _any(row.lines))
	return true


static func _tend(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	var vitals := Vitals.of(interactor.feyre)
	if vitals == null:
		return false
	var hurt := VitalsState.MAX_HEALTH - vitals.health
	if hurt < 1.0 and vitals.affliction(&"venom") <= 0.0:
		_think(interactor, _any(row.alt_lines))
		return true
	vitals.clear_status(&"venom")
	if hurt >= 1.0:
		vitals.heal_over_time(hurt)
	Clock.advance(row.minutes)
	Juice.burst(station, &"craft")
	_think(interactor, _any(row.lines))
	return true


static func _sleep(interactor: Interactor, row: StationUse) -> bool:
	if not StoryControl.holders().is_empty():
		return false
	var hour := Clock.hour()
	var night := is_night()
	var feyre := interactor.feyre
	var at_dark := func() -> void:
		if night:
			Clock.advance(fposmod(MORNING - hour, 24.0) / 24.0 * Clock.DAY_LENGTH_SECONDS)
		else:
			Clock.advance(row.minutes)
		var vitals := Vitals.of(feyre)
		if vitals:
			vitals.rest(night)
	var woke := func() -> void:
		_busy = false
		if is_instance_valid(interactor):
			_think(interactor, _any(row.lines if night else row.day_lines))
	_busy = true
	SleepFade.run(feyre, at_dark, woke)
	return true


static func _soak(interactor: Interactor, station: Node3D, row: StationUse) -> bool:
	if not StoryControl.holders().is_empty():
		return false
	var feyre := interactor.feyre
	var at_dark := func() -> void:
		Clock.advance(row.minutes)
		var body := feyre.body_state if is_instance_valid(feyre) else null
		if body:
			body.cold = 0.0
		var vitals := Vitals.of(feyre)
		if vitals:
			vitals.apply_status(&"bath", &"warm", BATH_WARM, BATH_WARM_SECONDS)
			vitals.ease_moment_from("station:bath")
	var done := func() -> void:
		_busy = false
		if is_instance_valid(station):
			Juice.burst(station, &"craft")
		if is_instance_valid(interactor):
			_think(interactor, _any(row.lines))
	_busy = true
	SleepFade.run(feyre, at_dark, done)
	return true


static func _used_today(row: StationUse) -> bool:
	return int(WorldState.get_flag(FACT_DAY % row.station_id, -1)) == Clock.day


static func _mark_today(row: StationUse) -> void:
	WorldState.set_flag(FACT_DAY % row.station_id, Clock.day)


static func _any(lines: PackedStringArray) -> String:
	return lines[randi() % lines.size()] if not lines.is_empty() else ""


## Her thought, on the corner card (docs/contracts/ui-frame.md: her voice).
static func _think(interactor: Interactor, text: String) -> void:
	if text != "" and interactor.is_inside_tree():
		LinePresenter.of(interactor.get_tree()).say(LinePresenter.Voice.THOUGHT, "", text, interactor.feyre)


static func _load() -> void:
	for file in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".tres"):
			continue
		var row := load(DIR + file) as StationUse
		if row and row.station_id != &"":
			_rows[row.station_id] = row
