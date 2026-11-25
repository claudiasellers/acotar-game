## Writes data/combat/attacks/*.tres: the starting attack rows from
## docs/contracts/vitals.md §3. Hostile-fae retunes its own rows afterwards.
##   tools/mq/godot.sh -s tools/vitals/gen_attack_rows.gd
extends SceneTree

const OUT := "res://data/combat/attacks/"

## id, family, default, damage, kind, reaction, knockback, status, magnitude,
## seconds, dread, can_knock_down, floor
const ROWS := [
	[&"naga_claw", &"naga", true, 22.0, &"claw", &"medium", 2.0, &"", 0.0, 0.0, 0.15, true, 0.0],
	[&"naga_lunge", &"naga", false, 30.0, &"blunt", &"heavy", 4.0, &"", 0.0, 0.0, 0.2, true, 0.0],
	[&"naga_coil", &"naga", false, 0.0, &"grab", &"none", 0.0, &"", 0.0, 0.0, 0.25, true, 0.0],
	[&"briarling_lash", &"briarling", true, 8.0, &"thorn", &"light", 0.5, &"", 0.0, 0.0, 0.1, true, 0.0],
	[&"briarling_snare", &"briarling", false, 0.0, &"grab", &"none", 0.0, &"", 0.0, 0.0, 0.15, true, 0.0],
	[&"lampwing_swarm", &"lampwing", true, 0.0, &"blunt", &"none", 0.0, &"drowsy", 0.15, 6.0, 0.05, true, 0.0],
	[&"crow_peck", &"crow", true, 4.0, &"claw", &"light", 0.0, &"", 0.0, 0.0, 0.05, true, 0.0],
	[&"crow_dive", &"crow", false, 8.0, &"claw", &"light", 1.0, &"", 0.0, 0.0, 0.1, true, 0.0],
	[&"hob_swat", &"hob", true, 55.0, &"blunt", &"heavy", 6.0, &"", 0.0, 0.0, 0.3, true, 0.0],
	[&"hob_stomp", &"hob", false, 35.0, &"blunt", &"heavy", 3.0, &"", 0.0, 0.0, 0.25, true, 0.0],
	[&"blackvein_bite", &"blackvein", true, 10.0, &"bite", &"light", 0.0, &"venom", 0.35, 1.0, 0.2, true, 0.0],
	[&"blackvein_drop", &"blackvein", false, 18.0, &"claw", &"medium", 2.0, &"venom", 0.2, 1.0, 0.35, true, 0.0],
	[&"martax_maul", &"martax", true, 45.0, &"claw", &"heavy", 5.0, &"", 0.0, 0.0, 0.3, true, 0.0],
	[&"martax_charge", &"martax", false, 35.0, &"blunt", &"heavy", 6.0, &"", 0.0, 0.0, 0.25, true, 0.0],
	[&"martax_roar", &"martax", false, 0.0, &"blunt", &"none", 0.0, &"roar_shake", 0.8, 6.0, 0.25, true, 0.0],
	[&"prowler_grab", &"prowler", true, 0.0, &"grab", &"none", 0.0, &"", 0.0, 0.0, 0.3, true, 0.0],
	[&"wolf_bite", &"wolf", true, 25.0, &"bite", &"medium", 2.0, &"", 0.0, 0.0, 0.2, true, 0.0],
	# Hazard rows (vitals lane).
	[&"thorns", &"", false, 3.0, &"thorn", &"light", 0.0, &"", 0.0, 0.0, 0.0, false, 25.0],
	[&"fire", &"", false, 6.0, &"fire", &"light", 0.0, &"", 0.0, 0.0, 0.05, false, 10.0],
	[&"cold_exposure", &"", false, 1.0, &"cold", &"none", 0.0, &"", 0.0, 0.0, 0.0, false, 30.0],
	[&"venom_drain", &"", false, 0.2, &"venom", &"none", 0.0, &"", 0.0, 0.0, 0.0, false, 10.0],
	[&"fall", &"", false, 8.0, &"fall", &"heavy", 0.0, &"", 0.0, 0.0, 0.1, true, 0.0],
	[&"food_harm", &"", false, 1.0, &"venom", &"none", 0.0, &"", 0.0, 0.0, 0.0, false, 10.0],
	[&"generic_hit", &"", false, 10.0, &"blunt", &"light", 0.0, &"", 0.0, 0.0, 0.1, true, 0.0],
]

## Tell to contact, s (bestiary; floors in AttackData.windup_s). Hazards have none.
const WINDUP := {
	&"naga_claw": 0.55,
	&"naga_lunge": 0.8,
	&"naga_coil": 0.6,
	&"briarling_lash": 0.4,
	&"briarling_snare": 0.6,
	&"lampwing_swarm": 0.6,
	&"crow_peck": 0.4,
	&"crow_dive": 0.45,
	&"hob_swat": 0.9,
	&"hob_stomp": 1.0,
	&"blackvein_bite": 0.45,
	&"blackvein_drop": 0.6,
	&"martax_maul": 0.85,
	&"martax_charge": 2.0,
	&"martax_roar": 0.6,
	&"prowler_grab": 0.6,
	&"wolf_bite": 0.55,
}

## Grab rows: [presses to break, seconds it holds, fail strike scale]
## (health-interactions §4: the coil 6 / 3 s then a claw ×1.5; the snare
## 4 / 2.5 s then two lashes).
const GRABS := {
	&"naga_coil": [6, 3.0, 1.5],
	&"briarling_snare": [4, 2.5, 2.0],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var written := 0
	for r: Array in ROWS:
		var row := AttackData.new()
		row.id = r[0]
		row.family = r[1]
		row.is_default = r[2]
		row.damage = r[3]
		row.damage_kind = r[4]
		row.reaction = r[5]
		row.knockback_m = r[6]
		row.status_tag = r[7]
		row.status_magnitude = r[8]
		row.status_seconds = r[9]
		row.dread_spike = r[10]
		row.can_knock_down = r[11]
		row.floor_hp = r[12]
		row.windup_s = float(WINDUP.get(row.id, 0.0))
		if GRABS.has(row.id):
			row.grab_presses = int(GRABS[row.id][0])
			row.grab_seconds = float(GRABS[row.id][1])
			row.grab_fail_scale = float(GRABS[row.id][2])
		if ResourceSaver.save(row, OUT + "%s.tres" % row.id) == OK:
			written += 1
	print("gen_attack_rows: wrote %d rows to %s" % [written, OUT])
	quit()
