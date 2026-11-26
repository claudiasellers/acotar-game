## Who Feyre knows and what has passed between them (owner, 2026-11-25): the
## people of plans/relationship-loops and the white mare, as she would write
## them down. A bond is told as moments, each
## one a story flag or a `fact.` flag that some deed raised, with the day it
## happened. A moment says what passed (`then`) and may say how they are with
## her since (`now`), what she calls them from then on (`called`) and which
## portrait is theirs from then on (`face`, an Icons.BONDS id; their own id
## until a moment says otherwise). Every bond is also read by one set of
## measures (`MEASURES`, `measures(bond)`), drawn as meters. Nobody
## is listed before the flag that brings them into her life (`met`).
##
## This only reads flags and keeps the day each moment came (WorldDeltas
## region `bonds`). It never sets a story flag and holds no regard: when a
## lane adds a deed, it adds the flag's row here and nothing else changes.
## The mare's moments are her own page's memories (data/mount/mare_page.tres),
## so they are written once.
##
## Canon tags: C chapter (the book), A (adapted from the book's own words),
## X (invented). No line says the curse, the masks' cause or "she" before
## Alis's truth (plan §10).
class_name BondBook
extends RefCounted

const DELTAS := &"bonds"
const PERSON := &"person"
const MARE := &"mare"
const MARE_PAGE := "res://data/mount/mare_page.tres"

const BONDS: Array[Dictionary] = [
	{
		"id": &"tamlin", "kind": PERSON, "met": "beast_claim_accepted", "called": "The beast", "face": &"tamlin_beast",
		"moments": [
			{"flag": "beast_claim_accepted", "canon": "C4",
				"then": "A beast with horns broke down our door and called me murderer. A life for a life. I went with him.",
				"now": "My captor. I watch his claws."},
			{"flag": "first_dinner_eaten", "canon": "C6-9", "called": "Tamlin", "face": &"tamlin",
				"then": "He is a High Lord, and he wears a mask he cannot take off. He fed me at his table, and every polite word seemed to pain him.",
				"now": "Stiff and gruff, and gone all day. He says he keeps no slaves."},
			{"flag": "puca_resisted", "canon": "C11",
				"then": "Something wore my father's face at the garden's edge. He stopped me at the gate before I could follow it."},
			{"flag": "fact.tam_warm_host", "canon": "A11",
				"then": "He told me to stay inside the gate after dark, whatever I heard calling. He meant it kindly, I think.",
				"now": "Gruff still, but he looks up when I come in."},
			{"flag": "tamlin_wound_dressed", "canon": "C12-13",
				"then": "He came home bloodied from hunting the Bogge. I bound his hand, and he asked where I had learned how.",
				"now": "Gentler when he is tired. He offered to help me with my letters, and I said no."},
			{"flag": "fact.tam_warm_wounded", "canon": "X",
				"then": "I found him in the halls in the middle of the night, as awake as I was.",
				"now": "He keeps the same late hours I do. Neither of us says why."},
			{"flag": "naga_survived", "canon": "C15",
				"then": "He came for me in the western woods and tore the naga apart. Then he healed my face and arm."},
			{"flag": "summer_faerie_comforted", "canon": "C17",
				"then": "I held the dying faerie's hand. He carried him out and buried him himself."},
			{"flag": "starlight_pool_found", "canon": "C18",
				"then": "He took me to a pool of starlight, his favourite place as a boy. I had not thought he could be shy.",
				"now": "At ease with me. He shows me the places he loves and waits to see what I make of them."},
			{"flag": "gallery_opened", "canon": "C19",
				"then": "He opened the gallery and told me to come whenever I want."},
			{"flag": "fact.tam_warm_guide", "canon": "A19",
				"then": "He said there was another place he wanted to show me, when I was ready.",
				"now": "My guide to his lands. He waits for me to say yes."},
			{"flag": "bite_endured", "canon": "C21",
				"then": "After Fire Night he was not himself. He pinned me in the hall and bit my neck, and I slapped him.",
				"now": "Something wilder under the manners. I have not forgotten it."},
			{"flag": "paintings_shown", "canon": "C22",
				"then": "He brought white roses, and I showed him my paintings. He kept the one of my winter forest.",
				"now": "Careful with me again. I did not lock my door."},
			{"flag": "glamour_lifted", "canon": "C23",
				"then": "In the willow glen he lifted a veil from my eyes. The world had been hiding from me."},
			{"flag": "solstice_danced", "canon": "C25",
				"then": "He played the fiddle and danced with me among the wisps until sunrise.",
				"now": "I think of him when he is away at the border, and he is away more and more."},
			{"flag": "sent_home", "canon": "C27-28",
				"then": "He sent me home to keep me safe. He said he loved me. I did not say it back.",
				"now": "Gone from me. I left him all my paintings."},
			{"flag": "alis_truth_heard", "canon": "C32",
				"then": "Alis told me what he never could.",
				"now": "Taken. I am going after him."},
		],
	},
	{
		"id": &"lucien", "kind": PERSON, "met": "first_dinner_eaten", "called": "Lucien",
		"moments": [
			{"flag": "first_dinner_eaten", "canon": "C6-7",
				"then": "Red hair, a fox mask, one eye of gold metal. He asked if I enjoyed killing his friend.",
				"now": "He despises me, and says so with a smile."},
			{"flag": "bogge_survived", "canon": "C9-11",
				"then": "He rode out with me, and when the Bogge came he told me not to look. I didn't.",
				"now": "He takes me along his friend's old patrol. He talks; I mostly don't."},
			{"flag": "fact.luc_warm_patrol", "canon": "X",
				"then": "He has started waiting for me by the front doors in the mornings.",
				"now": "He waits for me before the patrol, and pretends he doesn't."},
			{"flag": "suriel_bound", "canon": "C13-14",
				"then": "He told me how to snare a Suriel: young birch, a chicken, a double-loop snare, running water close by."},
			{"flag": "naga_survived", "canon": "C16",
				"then": "His advice nearly got me killed. He says he wishes he had been there to help.",
				"now": "In my debt, and he knows it."},
			{"flag": "fact.luc_did_freed_suriel_first", "canon": "C18",
				"then": "Tamlin told him my first shot was to save the Suriel, not myself. He looked at me differently after."},
			{"flag": "starlight_pool_found", "canon": "C18",
				"then": "He told me where he came from and what his family did, and gave me his own hunting knife.",
				"now": "A friend, I think. He would not call it that."},
			{"flag": "fact.luc_warm_friend", "canon": "X",
				"then": "He asked me to ride out with him, and let me choose the way.",
				"now": "A friend. He still would not call it that."},
			{"flag": "calanmai_attended", "canon": "C21",
				"then": "He dragged me away from the fires and told me to stay in my room.",
				"now": "He guards me, even from myself."},
			{"flag": "solstice_danced", "canon": "C25",
				"then": "He warned me off the faerie wine. I drank it anyway, and he minded me all night."},
			{"flag": "sent_home", "canon": "C28",
				"then": "He argued for me to stay a few more days. Then he walked off without a goodbye.",
				"now": "Left behind, like the rest of them."},
		],
	},
	{
		"id": &"alis", "kind": PERSON, "met": "first_dinner_eaten", "called": "Alis", "warmth": Relationships.NEUTRAL,
		"moments": [
			{"flag": "first_dinner_eaten", "canon": "C6-7",
				"then": "She scrubbed me, cut my hair, and found me a tunic and trousers when I would not wear the dress. She says the house is safe.",
				"now": "Brisk, and not unkind."},
			{"flag": "fact.alis_tripped", "canon": "C7",
				"then": "My curtain snare caught her instead of an intruder."},
			{"flag": "gallery_opened", "canon": "C19", "warmth": Relationships.WARM,
				"then": "She took me to a room stocked with paints, all for me.",
				"now": "She looks after what matters to me without my asking."},
			{"flag": "glamour_lifted", "canon": "C24", "face": &"alis_true",
				"then": "I saw her true face, skin like bark. She has always looked so.",
				"now": "Herself, at last, to my eyes."},
			{"flag": "solstice_danced", "canon": "C25",
				"then": "She dressed me in blue for the Solstice and put flowers in my hair."},
			{"flag": "sent_home", "canon": "C28",
				"then": "\"Make the most of your freedom.\" That was all she said."},
			{"flag": "alis_truth_heard", "canon": "C32",
				"then": "She was the only one left in the wrecked house, and she told me everything.",
				"now": "She will take me as far as the mountain."},
		],
	},
	{
		"id": &"mare", "kind": MARE, "met": "wall_crossed", "called": "The white mare",
		"moments": [
			{"flag": "wall_crossed", "canon": "C5",
				"then": "She carried me north with no rope on me and no bridle I could feel. I never thought to turn her.",
				"now": "His horse, not mine. She has no name that I've heard."},
			{"flag": "fact.mare_ridden", "canon": "C9",
				"then": "My first ride on her, out from the stables. It has been years, and then it was only a pony."},
		],
	},
	{
		"id": &"nesta", "kind": PERSON, "met": "", "called": "Nesta", "warmth": Relationships.COOL,
		"moments": [
			{"flag": "", "canon": "C1-3",
				"then": "My eldest sister. Sharp as a blade, and she has never forgiven our father.",
				"now": "Contempt, mostly. I hunt and she warms her hands."},
			{"flag": "nesta_truth_heard", "canon": "C30", "warmth": Relationships.NEUTRAL,
				"then": "The glamour never took on her. She came after me and could not get through the Wall.",
				"now": "I misjudged her. Something has eased between us."},
		],
	},
	{
		"id": &"elain", "kind": PERSON, "met": "", "called": "Elain", "warmth": Relationships.WARM,
		"moments": [
			{"flag": "", "canon": "C1-3",
				"then": "My middle sister. Gentle, and happiest with her hands in a flowerbed.",
				"now": "She asks me for seeds when we have no bread."},
		],
	},
	{
		"id": &"father", "kind": PERSON, "met": "", "called": "Father", "warmth": Relationships.NEUTRAL,
		"moments": [
			{"flag": "", "canon": "A",
				"then": "A creditor's men smashed his knee, and he has carved wood by the fire ever since.",
				"now": "He lets me do the hunting."},
		],
	},
	{
		"id": &"stranger", "kind": PERSON, "met": "stranger_met", "called": "The stranger", "warmth": Relationships.BAITING,
		"moments": [
			{"flag": "stranger_met", "canon": "C20-21",
				"then": "He stepped out of the dark at the fires and sent three faeries running from me. Then he mocked me.",
				"now": "I could not read him. I hope not to see him again."},
			{"flag": "rhysand_faced", "canon": "C26", "called": "Rhysand",
				"then": "He is High Lord of the Night Court. He looked into my mind, and Tamlin knelt to him. He asked my name and I gave him another girl's.",
				"now": "He knows my face now."},
		],
	},
]

## The one set of measures every bond is read by (owner, 2026-11-26), in the
## order the page draws them, each with the legend's line. Each is a meter
## (`filled` of `of`) and may have a word; one that does not apply to someone
## (`applies` false) is drawn faint and empty. Regard itself stays inside
## Relationships.
const CLOSENESS := &"closeness"
const WARMTH := &"warmth"
const DEEDS := &"deeds"
const MEMORIES := &"memories"
const SINCE := &"since"
const MEASURES: Array[Dictionary] = [
	{"id": CLOSENESS, "name": "Closeness", "says": "How far we have come. It never goes back."},
	{"id": WARMTH, "name": "Warmth", "says": "How they are with me now. A bad day cools it, and it passes."},
	{"id": DEEDS, "name": "Deeds", "says": "Things I did that they noticed."},
	{"id": MEMORIES, "name": "Memories", "says": "What has passed between us, kept on their page."},
	{"id": SINCE, "name": "Since", "says": "When it began between us."},
]
## Warmth's four steps, coldest first, and the word for each.
const WARMTH_STEPS: Array[StringName] = [Relationships.COOL, Relationships.BAITING, Relationships.NEUTRAL, Relationships.WARM]
const WARMTH_WORDS := {
	Relationships.COOL: "Cold", Relationships.BAITING: "Sharp", Relationships.NEUTRAL: "Civil", Relationships.WARM: "Warm",
}
## Warmth's word while a passing mood holds it down.
const COOL_FOR_NOW := "Cold, for now"
const ALWAYS := "Always"
const BEFORE := "Before I kept this book"

static var _mare_page: MarePageData


static func get_bond(id: StringName) -> Dictionary:
	for b in BONDS:
		if b.id == id:
			return b
	return {}


## Everyone in her life so far, in the table's order.
static func known() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in BONDS:
		if _up(b.met):
			out.append(b)
	return out


## Every moment a bond can hold, the mare's bond memories after her story ones.
static func all_moments(bond: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(bond.get("moments", []))
	if bond.get("kind") == MARE:
		for step: int in MareBond.MILESTONES:
			for id: StringName in MareBond.MILESTONES[step]:
				var note := _mare().note(id)
				if note:
					out.append({"flag": MareBond.DID_PREFIX + String(id), "then": note.memory, "canon": note.canon})
	return out


## The moments that have happened, oldest first: each with `day` (0 when it
## came before the book was kept). Moments keep the table's order within a day.
static func moments(bond: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in all_moments(bond):
		if _up(m.flag):
			var seen := m.duplicate()
			seen["day"] = day_of(m.flag)
			out.append(seen)
	var order := out.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.day != b.day:
			return a.day < b.day
		return order.find(a) < order.find(b))
	return out


## What she calls them now: the last name a reached moment gave.
static func called(bond: Dictionary) -> String:
	var out := String(bond.get("called", ""))
	for m in all_moments(bond):
		if m.has("called") and _up(m.flag):
			out = String(m.called)
	return out


## Their portrait now (Icons.BONDS): the last one a reached moment gave.
static func face(bond: Dictionary) -> StringName:
	var out := StringName(bond.get("face", bond.id))
	for m in all_moments(bond):
		if m.has("face") and _up(m.flag):
			out = m.face
	return out


## How they are with her these days: the newest moment that says, or for the
## mare what she does now at her bond step.
static func these_days(bond: Dictionary) -> String:
	if bond.get("kind") == MARE and WorldState.has_flag(String(MareBond.TIERS[0]["fact"])):
		return _mare().now[mini(MareBond.tier(), _mare().now.size() - 1)]
	var out := ""
	for m in moments(bond):
		if m.has("now"):
			out = String(m.now)
	return out


## A bond read by every measure, in MEASURES' order: each `id`, `name`,
## `applies`, a meter of `filled` of `of`, and a `word` ("" for none).
## Closeness and Deeds are the bond engine's (Relationships: the stage
## reached on its ladder, the deeds counted of those it knows), so they apply
## to whoever has a ladder there. Warmth is the engine's attitude, or for the
## others the last `warmth` a reached moment gave (the bond's own until then);
## the mare has none. Memories and Since apply to everyone; Since's meter is
## the share of the book's days they have been in her life.
static func measures(bond: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var def := Relationships.def(bond.id)
	var on_ladder := def != null and Relationships.stage(bond.id) >= 0
	for m in MEASURES:
		var row := {"id": m.id, "name": m.name, "applies": false, "filled": 0, "of": 1, "word": ""}
		match m.id:
			CLOSENESS:
				if on_ladder:
					row.applies = true
					row.filled = Relationships.stage(bond.id) + 1
					row.of = def.stages.size()
			WARMTH:
				var at := warmth(bond)
				if at != &"":
					row.applies = true
					row.filled = WARMTH_STEPS.find(at) + 1
					row.of = WARMTH_STEPS.size()
					row.word = COOL_FOR_NOW if on_ladder and Relationships.mood(bond.id) == Relationships.COOL else String(WARMTH_WORDS[at])
			DEEDS:
				if on_ladder:
					row.applies = true
					row.of = def.deeds.size()
					for d in def.deeds:
						if Relationships.done(bond.id, d.id):
							row.filled += 1
			MEMORIES:
				row.applies = true
				row.filled = moments(bond).size()
				row.of = all_moments(bond).size()
			SINCE:
				var day := day_of(String(bond.met))
				row.applies = true
				row.of = maxi(Clock.day, 1)
				row.filled = clampi(row.of - day + 1, 0, row.of) if day > 0 else row.of
				row.word = ALWAYS if bond.met == "" else ("Day %d" % day if day > 0 else BEFORE)
		out.append(row)
	return out


## How they are with her now, one of WARMTH_STEPS; &"" for the mare.
static func warmth(bond: Dictionary) -> StringName:
	if bond.get("kind") == MARE:
		return &""
	if Relationships.def(bond.id) != null and Relationships.stage(bond.id) >= 0:
		return Relationships.attitude(bond.id)
	var out := StringName(bond.get("warmth", &""))
	for m in all_moments(bond):
		if m.has("warmth") and _up(m.flag):
			out = m.warmth
	return out


## The day a moment came, or 0 if it was never stamped.
static func day_of(flag: String) -> int:
	return int(WorldDeltas.get_region_value(DELTAS, "day." + flag, 0))


## EventBus.flag_changed: a moment's flag has come up, so its day is kept.
static func stamp(flag: String, value: Variant) -> void:
	if not WorldState.truthy(value) or day_of(flag) > 0 or not _is_moment(flag):
		return
	WorldDeltas.set_region_value(DELTAS, "day." + flag, Clock.day)


## How many moments have happened across everyone she knows.
static func count() -> int:
	var n := 0
	for b in known():
		n += moments(b).size()
	return n


static func _is_moment(flag: String) -> bool:
	for b in BONDS:
		for m in all_moments(b):
			if m.flag == flag:
				return true
	return false


## A flag that is up; "" is true from the start (her family).
static func _up(flag: String) -> bool:
	return flag == "" or WorldState.has_flag(flag)


static func _mare() -> MarePageData:
	if _mare_page == null:
		_mare_page = load(MARE_PAGE) as MarePageData
	return _mare_page
