## Generates the stylized terrain textures (albedo with height in alpha,
## normal with roughness in alpha) for every slot in TerrainSetup.TEXTURES.
##   godot --headless -s world/shared/terrain/gen_terrain_textures.gd
## Output is committed (engineering rule R15). Soft, painterly, low-contrast:
## the colour comes from the grade and lighting, not busy texture detail.
extends SceneTree

const SIZE := 512
const OUT := "res://world/shared/terrain/textures"

## slot stem: [base colour, accent colour, noise scale, height contrast, roughness, accent amount]
const LOOKS := {
	"snow": [Color(0.80, 0.84, 0.91), Color(0.66, 0.73, 0.86), 6.0, 0.45, 0.55, 0.5],
	"frozen_earth": [Color(0.42, 0.39, 0.37), Color(0.62, 0.64, 0.70), 10.0, 0.6, 0.9, 0.4],
	"rock": [Color(0.48, 0.50, 0.56), Color(0.66, 0.66, 0.72), 5.0, 0.9, 0.85, 0.45],
	"winter_grass": [Color(0.62, 0.58, 0.44), Color(0.82, 0.84, 0.88), 14.0, 0.5, 0.9, 0.45],
	"spring_grass": [Color(0.55, 0.82, 0.50), Color(0.85, 0.93, 0.55), 12.0, 0.45, 0.85, 0.35],
	"moss": [Color(0.42, 0.68, 0.42), Color(0.74, 0.62, 0.86), 9.0, 0.5, 0.95, 0.18],
	"forest_floor": [Color(0.40, 0.31, 0.24), Color(0.62, 0.45, 0.30), 16.0, 0.55, 0.95, 0.4],
	"path": [Color(0.50, 0.40, 0.31), Color(0.66, 0.56, 0.44), 8.0, 0.4, 0.9, 0.35],
	"riverbed": [Color(0.50, 0.52, 0.52), Color(0.70, 0.68, 0.62), 18.0, 0.8, 0.6, 0.5],
	"blight": [Color(0.46, 0.44, 0.48), Color(0.58, 0.54, 0.62), 10.0, 0.5, 0.7, 0.4],
	"ice": [Color(0.72, 0.86, 0.92), Color(0.90, 0.97, 1.00), 4.0, 0.2, 0.12, 0.4],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var seed := 900
	for stem: String in LOOKS:
		seed += 1
		_make(stem, LOOKS[stem], seed)
	print("terrain textures written: %d slots" % LOOKS.size())
	quit(0)


func _make(stem: String, look: Array, seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(look[2]) / SIZE
	noise.fractal_octaves = 4
	var cells := FastNoiseLite.new()
	cells.seed = seed * 7
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.frequency = float(look[2]) * 2.0 / SIZE
	var albedo := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bump := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			# Tileable: sample the noise on a torus.
			var n := _tile(noise, x, y) * 0.5 + 0.5
			var c := _tile(cells, x, y) * 0.5 + 0.5
			var h := clampf(lerpf(0.5, n * 0.7 + c * 0.3, float(look[3])), 0.0, 1.0)
			var col := (look[0] as Color).lerp(look[1], smoothstep(0.45, 1.0, n) * float(look[5]))
			col = col.lightened((h - 0.5) * 0.12)
			albedo.set_pixel(x, y, Color(col.r, col.g, col.b, h))
			bump.set_pixel(x, y, Color(h, h, h, 1.0))
	bump.bump_map_to_normal_map(2.0)
	var normal := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rough := float(look[4])
	for y in SIZE:
		for x in SIZE:
			var nc := bump.get_pixel(x, y)
			normal.set_pixel(x, y, Color(nc.r, nc.g, nc.b, rough))
	albedo.save_png("%s/%s_albedo.png" % [OUT, stem])
	normal.save_png("%s/%s_normal.png" % [OUT, stem])


func _tile(n: FastNoiseLite, x: int, y: int) -> float:
	var a := TAU * x / SIZE
	var b := TAU * y / SIZE
	var r := SIZE / TAU
	return n.get_noise_3d(r * cos(a), r * sin(a), r * cos(b)) * 0.5 + n.get_noise_3d(r * sin(b), r * cos(a), r * sin(a)) * 0.5
