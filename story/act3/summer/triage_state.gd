## The bleed clock and what Feyre has done (L29, ch 17), free of nodes so
## tests can run it at any speed. SummerFaerieTriage feeds it her presses.
##
## Unwinnable by design (keeper): the best care buys him minutes and his
## words, never his life. Holding his hand is the deed; when she takes it he
## lets go, gently, within FADE_SECONDS.
class_name TriageState
extends RefCounted

signal step_done(wound: int, step: TriageWound.Step)
signal came_round
signal faded

const START_BLOOD := 100.0
## Linen strips Tamlin conjures: one per stump and one spare.
const LINEN_STRIPS := 3
## He comes round enough to speak once both stumps are tended and he has this much left.
const LUCID_BLOOD := 30.0
## From her taking his hand to his last breath.
const FADE_SECONDS := 22.0
const SPOKEN_LINE := "She took my wings."

var blood: float = START_BLOOD
var wounds: Array[TriageWound] = [TriageWound.new(&"left"), TriageWound.new(&"right")]
var has_rag: bool = false
var linen_left: int = LINEN_STRIPS
var linen_held: bool = false
var lucid: bool = false
var holding: bool = false
var promised: bool = false
var dead: bool = false
var elapsed: float = 0.0
var died_at: float = -1.0
## Blood lost to harmful dressings (for the log and tests).
var harmed: float = 0.0

## The step in hand: {"wound": i, "step": Step, "left": seconds}, or {} when idle.
var work: Dictionary = {}
var _fade_rate: float = 0.0


func bleed_rate() -> float:
	if dead:
		return 0.0
	var r := 0.0
	for w in wounds:
		r += w.rate()
	if holding:
		r = maxf(r, _fade_rate)
	return r


## Seconds of life left at the current rate.
func seconds_left() -> float:
	var r := bleed_rate()
	return INF if r <= 0.0 else blood / r


func tick(delta: float) -> void:
	if dead:
		return
	elapsed += delta
	for w in wounds:
		w.tick(delta)
	if not work.is_empty() and not holding:
		work.left = float(work.left) - delta
		if float(work.left) <= 0.0:
			_complete(int(work.wound), work.step)
			work = {}
	blood = maxf(blood - bleed_rate() * delta, 0.0)
	if not lucid and blood >= LUCID_BLOOD and wounds.all(func(w: TriageWound) -> bool: return w.tended()):
		lucid = true
		came_round.emit()
	if blood <= 0.0:
		dead = true
		died_at = elapsed
		work = {}
		faded.emit()


## The wound she'd work on next, and its step: the first stump still needing
## something she can do. {"wound": -1} when there is nothing to do.
func next_work(has_dressing: bool) -> Dictionary:
	for i in wounds.size():
		var s := wounds[i].next_step(has_rag, has_dressing, linen_held)
		if s != TriageWound.Step.NONE:
			return {"wound": i, "step": s}
	return {"wound": -1, "step": TriageWound.Step.NONE}


## Starts a step (she has to stay at the wounds while it lasts).
func begin(wound: int, step: TriageWound.Step) -> void:
	if dead or holding or wound < 0:
		return
	work = {"wound": wound, "step": step, "left": float(TriageWound.SECONDS[step])}


## She stepped away: the step in hand is lost.
func interrupt() -> void:
	work = {}


## Called when a DRESS step completes, with TriageMath's rating.
var dressing_rating: float = 0.0


func _complete(i: int, step: TriageWound.Step) -> void:
	var w := wounds[i]
	match step:
		TriageWound.Step.READ:
			w.read = true
		TriageWound.Step.CLEAN:
			w.cleaned = true
			has_rag = wounds.any(func(x: TriageWound) -> bool: return not x.cleaned and not x.dressed)
		TriageWound.Step.DRESS:
			w.dressed = true
			w.dressing = dressing_rating
			if dressing_rating <= TriageMath.MIN_RATING:
				blood = maxf(blood - TriageMath.HARM_LOSS, 0.0)
				harmed += TriageMath.HARM_LOSS
		TriageWound.Step.BIND:
			w.bound = true
			linen_held = false
	step_done.emit(i, step)


## At the bowl: the wet rag first if a stump still needs cleaning, else linen.
## Returns what she took: "rag", "linen" or "".
func take_supplies() -> String:
	if dead:
		return ""
	if not has_rag and wounds.any(func(w: TriageWound) -> bool: return not w.cleaned and not w.dressed):
		has_rag = true
		return "rag"
	if not linen_held and linen_left > 0 and wounds.any(func(w: TriageWound) -> bool: return not w.bound):
		linen_left -= 1
		linen_held = true
		return "linen"
	return ""


## She takes his hand: he lets go within FADE_SECONDS. Returns true if he can
## hear her promise (he came round first).
func take_hand() -> bool:
	if dead:
		return false
	holding = true
	work = {}
	_fade_rate = maxf(blood / FADE_SECONDS, 0.0)
	if lucid:
		promised = true
	return promised


func let_go() -> void:
	holding = false
	_fade_rate = 0.0
