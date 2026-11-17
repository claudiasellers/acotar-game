## Puts the mare's dress-up on her (lane L47-7, docs/contracts/mare_bond.md):
## recolours her own surfaces (saddle cloth, mane, brow blooms, tack, hooves)
## with surface overrides, hangs the pieces she wears (garland, bows) on her
## bones, and lays the groomed shine on her coat. Called whenever she appears
## and whenever Feyre changes something. Every colour stays under the 0.85
## albedo cap and nothing glows (project rules).
class_name MareLook
extends RefCounted

## Coat pearl when freshly brushed (0..1 shine adds up to this much).
const SHINE_PEARL := 0.55
const SHINE_GLITTER := 0.0
const DECOR_PREFIX := "MareDecor_"
## Material names on a worn piece that take the player's colour.
const TINTED := ["DecorBloom", "DecorRibbon"]


static func _mesh(horse: WhiteHorse) -> MeshInstance3D:
	if horse == null or horse.model == null:
		return null
	for m in horse.model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 6 and not String(mi.name).begins_with(DECOR_PREFIX):
			return mi
	return null


static func _surface_index(mi: MeshInstance3D) -> Dictionary:
	var out := {}
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		if mat:
			out[String(mat.resource_name)] = i
	return out


static func capped(c: Color) -> Color:
	var k := CandyMaterial.MAX_ALBEDO
	return Color(minf(c.r, k), minf(c.g, k), minf(c.b, k), c.a)


## Applies the whole outfit (MareTack.outfit()) and `shine` 0..1 to her.
static func apply(horse: WhiteHorse, outfit: Dictionary, shine: float = 0.0) -> void:
	var mi := _mesh(horse)
	if mi == null:
		return
	var idx := _surface_index(mi)
	# Start from her own look, then lay each piece over it.
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, null)
	for slot: StringName in outfit:
		var p := outfit[slot] as MareDecor
		if p and p.model == "" and not p.colors.is_empty():
			for k in p.tint_surfaces.size():
				var name := p.tint_surfaces[k]
				if not idx.has(name):
					continue
				var c := p.colors[mini(k, p.colors.size() - 1)]
				mi.set_surface_override_material(idx[name], _tinted(mi.mesh.surface_get_material(idx[name]), c, p.pearl, p.glitter))
	if idx.has("Coat") and shine > 0.01:
		var coat := mi.mesh.surface_get_material(idx["Coat"])
		var base_pearl := float(coat.get(&"pearl")) if coat and &"pearl" in coat else 0.0
		var m := coat.duplicate() as Material
		_set_extra(m, &"pearl", base_pearl + SHINE_PEARL * shine)
		_set_extra(m, &"glitter", SHINE_GLITTER * shine)
		mi.set_surface_override_material(idx["Coat"], m)
	_hang_pieces(horse, outfit)


static func _tinted(src: Material, c: Color, pearl: float, glitter: float) -> Material:
	var m: Material = src.duplicate() if src else MaterialLibrary.surface(c, 0.5)
	if &"albedo_color" in m:
		m.set(&"albedo_color", capped(c))
	_set_extra(m, &"pearl", pearl)
	_set_extra(m, &"glitter", glitter)
	return m


static func _set_extra(m: Material, prop: StringName, v: float) -> void:
	if m and prop in m:
		m.set(prop, v)


## The worn pieces (garland, bows, tail bow) on her bones; old ones come off.
static func _hang_pieces(horse: WhiteHorse, outfit: Dictionary) -> void:
	var sk := _skeleton(horse)
	if sk == null:
		return
	for n in sk.get_children():
		if String(n.name).begins_with(DECOR_PREFIX):
			sk.remove_child(n)
			n.queue_free()
	for slot: StringName in outfit:
		var p := outfit[slot] as MareDecor
		if p == null or p.model == "" or not ResourceLoader.exists(p.model):
			continue
		var bone := sk.find_bone(p.bone)
		if bone < 0:
			continue
		var att := BoneAttachment3D.new()
		att.name = DECOR_PREFIX + String(slot)
		att.bone_name = p.bone
		sk.add_child(att)
		var piece := (load(p.model) as PackedScene).instantiate() as Node3D
		att.add_child(piece)
		# Authored in her model space: undo the bone's rest and the skeleton's
		# place in the model, so at rest it sits exactly where it was made.
		var model_to_sk := sk.global_transform.affine_inverse() * horse.model.global_transform
		piece.transform = sk.get_bone_global_rest(bone).affine_inverse() * model_to_sk
		var c := p.colors[0] if not p.colors.is_empty() else Color(0.85, 0.66, 0.76)
		for m in piece.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			mi.add_to_group(CameraFade.NEVER_GROUP)
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				if mat and String(mat.resource_name) in TINTED:
					mi.set_surface_override_material(i, _tinted(mat, c, p.pearl, p.glitter))


static func _skeleton(horse: WhiteHorse) -> Skeleton3D:
	if horse == null or horse.model == null:
		return null
	var found := horse.model.find_children("*", "Skeleton3D", true, false)
	return null if found.is_empty() else found.front() as Skeleton3D


## The pieces hanging on her now (for tests and the screen).
static func hung(horse: WhiteHorse) -> PackedStringArray:
	var out := PackedStringArray()
	var sk := _skeleton(horse)
	if sk:
		for n in sk.get_children():
			if String(n.name).begins_with(DECOR_PREFIX):
				out.append(String(n.name).trim_prefix(DECOR_PREFIX))
	return out
