## Dresses activity places from their PlaceSetting (lane L32): keeps clutter
## out of each forecourt, plants the collar beds, the framing pair and the
## signature props as ScatterLayers (pure, worker-thread safe), and builds the
## light, particles and positional sound as nodes (main thread).
class_name PlaceComposer
extends RefCounted

const COURT_TABLE := "res://data/places/court_places.tres"
const FX_DIR := "res://world/spring_court/wider/fx/particles/fx_%s.tscn"
## Bed length along the ring (m): one kind per bed, kinds alternate.
const BED := 5.5
const DRAW := 170.0

static var _tables := {}
static var _lock := Mutex.new()


## The table at `path` (cached; safe from worker threads).
static func table(path: String = COURT_TABLE) -> PlaceTable:
	_lock.lock()
	if not _tables.has(path):
		_tables[path] = load(path) as PlaceTable if ResourceLoader.exists(path) else null
	var t: PlaceTable = _tables[path]
	_lock.unlock()
	return t


## Settings whose forecourt touches `rect`.
static func in_rect(t: PlaceTable, rect: Rect2) -> Array[PlaceSetting]:
	var out: Array[PlaceSetting] = []
	if t == null:
		return out
	for s in t.settings:
		if rect.grow(s.radius + s.collar_width).has_point(s.center):
			out.append(s)
	return out


## True inside a forecourt (grown by `extra` m): no tall or cluttering scatter here.
static func blocks(settings: Array[PlaceSetting], p: Vector2, extra: float = 0.0) -> bool:
	for s in settings:
		if p.distance_squared_to(s.center) < (s.radius + extra) * (s.radius + extra):
			return true
	return false


## Unit direction the player arrives from (x, z).
static func approach(s: PlaceSetting) -> Vector2:
	var a := deg_to_rad(s.approach_deg)
	return Vector2(sin(a), -cos(a))


## Collar beds, framing pair and props as ScatterLayers, one per mesh id.
## `mesh_for` maps a mesh id to a Mesh; `ground_y(Vector2) -> float`.
static func layers(settings: Array[PlaceSetting], seed_value: int, mesh_for: Callable, ground_y: Callable,
		owns: Callable) -> Array[ScatterLayer]:
	var by_mesh := {}
	var put := func(mesh_id: StringName, p: Vector2, yaw: float, scale: float, solid: bool) -> void:
		if not owns.call(p):
			return
		if not by_mesh.has(mesh_id):
			var l := ScatterLayer.new()
			l.id = StringName("place_%s" % mesh_id)
			l.mesh = mesh_for.call(mesh_id)
			l.tags = PackedStringArray(["place"])
			l.cast_shadow = solid
			l.wind = 0.0 if solid else 0.4
			l.draw_distance = DRAW
			by_mesh[mesh_id] = l
		(by_mesh[mesh_id] as ScatterLayer).add(Vector3(p.x, ground_y.call(p), p.y), yaw, scale)
	for s in settings:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "place", s.id])
		var fwd := approach(s)
		var a0 := atan2(fwd.y, fwd.x)
		var half_open := deg_to_rad(s.opening_deg) * 0.5
		var arc := TAU - half_open * 2.0
		var r_mid := s.radius + s.collar_width * 0.5
		# Collar beds, alternating kinds, a small gap between beds.
		if not s.collar_meshes.is_empty():
			var beds := maxi(2, int(arc * r_mid / BED))
			var per_bed := maxi(2, int(BED * s.collar_per_m))
			for b in beds:
				var mesh_id := StringName(s.collar_meshes[b % s.collar_meshes.size()])
				var b0 := a0 + half_open + arc * float(b) / beds
				var b1 := b0 + arc / beds * rng.randf_range(0.7, 0.9)
				# Beds swell and step in and out a little, so the ring reads planted, not drawn.
				var r0 := s.radius + rng.randf_range(-0.6, 1.2)
				var depth := s.collar_width * rng.randf_range(0.6, 1.4)
				for k in per_bed:
					var u := (k + rng.randf()) / per_bed
					var a := lerpf(b0, b1, u)
					var r := r0 + rng.randf() * depth * sin(PI * clampf(u, 0.1, 0.9))
					var p := s.center + Vector2(cos(a), sin(a)) * r
					put.call(mesh_id, p, rng.randf() * TAU, rng.randf_range(0.8, 1.15), false)
		# The framing pair either side of the opening, facing out along the approach.
		if s.frame_mesh != &"":
			for side in [-1.0, 1.0]:
				var a: float = a0 + side * (half_open + 0.06)
				var p := s.center + Vector2(cos(a), sin(a)) * (s.radius + 0.6)
				put.call(s.frame_mesh, p, atan2(-fwd.x, -fwd.y), s.frame_scale, true)
		# Signature props round the inside of the ring, facing the centre,
		# spread over the arc opposite the opening.
		var n := s.props.size()
		for i in n:
			var a := a0 + PI + (float(i) - (n - 1) * 0.5) * minf(arc / maxf(n, 1.0), 0.7)
			var p := s.center + Vector2(cos(a), sin(a)) * maxf(s.radius - 1.8, 2.0)
			var toward := s.center - p
			put.call(StringName(s.props[i]), p, atan2(-toward.x, -toward.y), s.prop_scale, true)
	var out: Array[ScatterLayer] = []
	var ids := by_mesh.keys()
	# By text: StringName order follows pointers, which can change between runs.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		out.append(by_mesh[id])
	return out


## Light, particles and positional sound for each place, under `parent`
## (main thread). Sound plays through L15's SoundCue on the Sound bus.
static func build_nodes(parent: Node3D, settings: Array[PlaceSetting]) -> void:
	for s in settings:
		var node := Node3D.new()
		node.name = "Place_%s" % s.id
		node.add_to_group(&"place_setting")
		node.set_meta(&"place_id", s.id)
		node.set_meta(&"theme", s.theme)
		node.position = Vector3(s.center.x, WorldHeight.height_at(s.center.x, s.center.y), s.center.y)
		parent.add_child(node)
		if s.light_energy > 0.0:
			var light := OmniLight3D.new()
			light.name = "Glow"
			light.light_color = s.light_color
			light.light_energy = s.light_energy
			light.omni_range = s.radius + s.collar_width + 6.0
			light.omni_attenuation = 1.4
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 90.0
			light.distance_fade_length = 30.0
			light.position = Vector3(0.0, s.light_height, 0.0)
			node.add_child(light)
		var fx_path := FX_DIR % s.fx_id
		if s.fx_id != &"" and ResourceLoader.exists(fx_path):
			var fx := (load(fx_path) as PackedScene).instantiate() as Node3D
			if fx != null:
				fx.name = "Fx"
				fx.position = Vector3(0.0, 1.4, 0.0)
				node.add_child(fx)
		if s.sound_cue != "" and ResourceLoader.exists(s.sound_cue):
			var cue := load(s.sound_cue) as SoundCue
			if cue != null:
				var player := AudioStreamPlayer3D.new()
				player.name = "Sound"
				player.stream = cue.pick()
				player.volume_db = cue.volume_db
				player.max_distance = cue.max_distance
				player.unit_size = cue.max_distance / 6.0
				player.attenuation_filter_cutoff_hz = 6000.0
				player.bus = GameSettings.SOUND_BUS
				player.autoplay = true
				player.position = Vector3(0.0, 1.2, 0.0)
				node.add_child(player)
