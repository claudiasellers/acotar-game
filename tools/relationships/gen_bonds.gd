## Writes the bonds' tables, data/relationships/*.tres (lane L90,
## docs/contracts/relationships.md; design plans/relationship-loops/plan.md
## §2-3, Part One, slice 1). Edit the tables here and rerun:
##   tools/mq/godot.sh --headless -s tools/relationships/gen_bonds.gd
## The mare's ladder is read from MareBond.TIERS and MILESTONES, her own
## tables, so it is written once.
## Canon tags: C chapter, A adapted, X invented.
extends SceneTree

const OUT := "res://data/relationships/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for d: BondDef in [_tamlin(), _lucien(), _mare()]:
		var err := ResourceSaver.save(d, OUT + "%s.tres" % d.id)
		print("gen_bonds: %s -> %d stages, %d deeds, %d moods (%s)" % [
			d.id, d.stages.size(), d.deeds.size(), d.moods.size(), error_string(err)])
	quit()


static func stage(id: String, fact: String, gate: String, floor: int, canon_floor: String, warm_at: int,
		attitude: String, canon: String, elsewhere := false) -> BondStage:
	var s := BondStage.new()
	s.id = StringName(id)
	s.fact = fact
	s.raised_elsewhere = elsewhere
	s.gate = gate
	s.floor = floor
	s.canon_floor = canon_floor
	s.warm_at = warm_at
	s.attitude = StringName(attitude)
	s.canon = canon
	return s


static func deed(id: String, weight: int, on_flag: String, how: String, canon: String, on_cue := "") -> BondDeed:
	var d := BondDeed.new()
	d.id = StringName(id)
	d.weight = weight
	d.on_flag = on_flag
	d.on_cue = on_cue
	d.how = StringName(how)
	d.canon = canon
	return d


static func mood(kind: String, region: String, unless_flag: String, canon: String) -> BondMood:
	var m := BondMood.new()
	m.id = &"cool"
	m.kind = StringName(kind)
	m.region = StringName(region)
	m.unless_flag = unless_flag
	m.days = 1
	m.canon = canon
	return m


## Tamlin, "the beast who keeps letting her go" (plan §2). The deeds every run
## passes come to 6 by the wound; the others (her letters, the Suriel first,
## holding the Summer faerie still to the end, a first painting) are what turn a stage warm.
static func _tamlin() -> BondDef:
	var b := BondDef.new()
	b.id = &"tamlin"
	b.prefix = "tam"
	b.stages = [
		stage("beast", "beast_claim_accepted", "", 0, "", 0, "neutral", "C4", true),
		stage("host", "fact.tam_bond_host", "first_dinner_eaten", 0, "", 3, "neutral", "C9"),
		stage("wounded", "fact.tam_bond_wounded", "tamlin_wound_dressed", 4, "study_mural_seen", 7, "neutral", "C12-13"),
		stage("guide", "fact.tam_bond_guide", "starlight_pool_found", 8, "gallery_opened", 10, "neutral", "C18-19"),
	] as Array[BondStage]
	b.deeds = [
		deed("ate_at_table", 1, "first_dinner_eaten", "seen", "C9"),
		deed("resisted_puca", 1, "puca_resisted", "seen", "C11"),
		deed("didnt_look", 1, "bogge_survived", "reported", "A10"),
		deed("bound_hand", 2, "fact.tamlin_hand_bound", "seen", "C12"),
		deed("mapped_house", 1, "fact.hall_map_set_down", "found", "C12"),
		deed("practised_letters", 1, "fact.letters_practised", "found", "C16"),
		deed("freed_suriel_first", 2, "", "seen", "C18", "suriel:freed"),
		deed("held_him_still", 2, "fact.summer_faerie_held", "seen", "C17"),
		deed("painted", 1, "first_painting", "found", "C16"),
	] as Array[BondDeed]
	b.moods = [
		mood("region", "suriel_glade", "naga_survived", "A16"),
		mood("hurt_home", "", "", "X"),
	] as Array[BondMood]
	return b


## Lucien, "the fox who decides she's worth it" (plan §3). Hostile at first;
## the patrol, the Suriel and what Tamlin tells him of her bring him round.
static func _lucien() -> BondDef:
	var b := BondDef.new()
	b.id = &"lucien"
	b.prefix = "luc"
	b.stages = [
		stage("hostile", "first_dinner_eaten", "", 0, "", 0, "baiting", "C6-9", true),
		stage("patrol", "fact.luc_bond_patrol", "bogge_survived", 3, "puca_resisted", 4, "neutral", "C9-11"),
		stage("trap", "fact.luc_bond_trap", "study_mural_seen", 3, "fact.suriel_method_known", 0, "neutral", "C13"),
		stage("debt", "fact.luc_bond_debt", "naga_survived", 5, "summer_faerie_comforted", 0, "neutral", "C16-17"),
		stage("friend", "fact.luc_bond_friend", "starlight_pool_found", 7, "gallery_opened", 8, "neutral", "C18"),
	] as Array[BondStage]
	b.deeds = [
		deed("said_yes_to_hunt", 1, "fact.hunt_invited", "seen", "C9"),
		deed("didnt_look", 2, "bogge_survived", "seen", "C10"),
		deed("rode_out", 1, "fact.mare_ridden", "seen", "C11"),
		deed("asked_after_suriel", 1, "fact.suriel_method_known", "seen", "C13"),
		deed("freed_suriel_first", 2, "", "reported", "C18", "suriel:freed"),
		deed("held_him_still", 1, "fact.summer_faerie_held", "reported", "A17"),
	] as Array[BondDeed]
	return b


## The white mare (docs/contracts/mare_bond.md): her steps open on all their
## milestones, which count from the first ride and add no regard.
static func _mare() -> BondDef:
	var b := BondDef.new()
	b.id = MareBond.BOND
	b.prefix = "mare"
	var stages: Array[BondStage] = []
	for i in MareBond.TIERS.size():
		var fact := String(MareBond.TIERS[i]["fact"])
		var s := stage("tier%d" % i, fact, "", 0, "", 0, "neutral", "X", i <= 1)
		for id: StringName in MareBond.MILESTONES.get(i, []):
			s.needs.append(id)
		stages.append(s)
	b.stages = stages
	var deeds: Array[BondDeed] = []
	for step: int in MareBond.MILESTONES:
		for id: StringName in MareBond.MILESTONES[step]:
			var d := deed(String(id), 0, "", "seen", "X")
			d.from_stage = 1
			deeds.append(d)
	b.deeds = deeds
	return b
