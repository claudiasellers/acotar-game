## Decides when Feyre has a thought worth showing. Pure logic, no nodes, so
## the timings are testable (plans/guidance-journal.md, "When it appears").
##
## 1. The opening thought, OPENING_DELAY s after the player first has control.
## 2. A new open need: its first line NEW_DELAY s after control returns.
## 3. Stalling: STALL s with no story progress, then (idle IDLE s or wandered
##    WANDER m since the last thought), at most every COOLDOWN s; each one a
##    tier plainer than the last, stopping after the plainest.
## 4. On demand (G): the current line; again while showing, one tier plainer.
## Nothing while a scripted moment holds Feyre or the mood is dread.
class_name GuideDirector
extends RefCounted

const OPENING_DELAY := 20.0
const NEW_DELAY := 8.0
const STALL := 240.0
const COOLDOWN := 180.0
const IDLE := 30.0
const WANDER := 400.0

var book: GuideBook
var thread: GuideThread = null
## Highest tier shown for the current thread; -1 before any.
var shown_tier: int = -1
var stall: float = 0.0
var idle: float = 0.0
var wander: float = 0.0
var since_show: float = INF
var calm: float = 0.0
var announced: bool = false
var ever_shown: bool = false


func _init(guide_book: GuideBook = null) -> void:
	book = guide_book


## Re-reads the open need from the flags. Returns true when it changed.
func refresh(has_flag: Callable) -> bool:
	var next: GuideThread = book.pick(has_flag) if book else null
	if next == thread:
		return false
	thread = next
	shown_tier = -1
	stall = 0.0
	wander = 0.0
	announced = false
	return true


## Something in the story moved: the stall clock starts again.
func note_progress() -> void:
	stall = 0.0


## Advances the clocks. Returns {thread, tier} when a thought should surface
## on its own, else {}. can_show is false during scripted moments and dread.
func tick(delta: float, moved_m: float, input_active: bool, can_show: bool) -> Dictionary:
	stall += delta
	since_show += delta
	wander += moved_m
	idle = 0.0 if (input_active or moved_m > 0.05) else idle + delta
	if not can_show:
		calm = 0.0
		return {}
	calm += delta
	if thread == null or thread.tier_count() == 0:
		return {}
	if not announced:
		if calm >= (NEW_DELAY if ever_shown else OPENING_DELAY):
			announced = true
			return _show(0)
		return {}
	# Once the plainest line has been shown it stays quiet; G still recalls it.
	if shown_tier + 1 >= thread.tier_count():
		return {}
	if stall >= STALL and since_show >= COOLDOWN and (idle >= IDLE or wander >= WANDER):
		return _show(shown_tier + 1)
	return {}


## G pressed with nothing showing: the plainest line already earned, or the first.
func on_demand() -> Dictionary:
	if thread == null or thread.tier_count() == 0:
		return {}
	announced = true
	return _show(maxi(shown_tier, 0))


## G pressed while a thought shows: one tier plainer, or {} to close it.
func think_harder(current_tier: int) -> Dictionary:
	if thread == null or current_tier + 1 >= thread.tier_count():
		return {}
	return _show(current_tier + 1)


func _show(tier: int) -> Dictionary:
	shown_tier = maxi(shown_tier, tier)
	since_show = 0.0
	wander = 0.0
	ever_shown = true
	return {"thread": thread, "tier": tier}
