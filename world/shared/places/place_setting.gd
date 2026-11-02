## The setting around one activity place (a landmark, station, set piece or
## story site): what tells the player "this spot is for something". Lane L32.
##   forecourt  a clear apron: no rocks, shrubs, logs or trees inside it
##   collar     a ring of planting that fits the place, open on the approach side
##   frame      a pair of markers flanking the approach (lanterns, stones, roses ...)
##   props      a few signature pieces around the ring, facing in
##   light, fx, sound   the place's own glow, particles and positional loop
## Built by PlaceComposer from data/places/<realm>_places.tres.
class_name PlaceSetting
extends Resource

## The landmark / anchor id this setting dresses.
@export var id: StringName
## Mood family (hearth, water, sacred, fire, garden, lookout, shrine, dread);
## informational, tools group by it.
@export var theme: StringName = &"garden"
## Place centre (world x, z) and forecourt radius (m): the landmark's own
## footprint plus a clear apron. Written by tools/landscape/gen_place_settings.gd.
@export var center: Vector2
@export var radius: float = 12.0
## Direction the player arrives from (degrees, 0 = -Z north, 90 = +X east):
## towards the nearest walk (data/wayside), else the region's middle.
@export var approach_deg: float = 0.0
## Collar ring width (m) and planting per metre of ring.
@export var collar_width: float = 4.0
@export var collar_per_m: float = 1.6
## Mesh ids (CourtAssets) planted in the collar, in beds of one kind.
@export var collar_meshes: PackedStringArray = []
## Opening in the collar on the approach side (degrees of arc).
@export var opening_deg: float = 50.0
## Pair of markers either side of the opening.
@export var frame_mesh: StringName = &""
@export var frame_scale: float = 1.0
## Signature props: mesh ids, placed round the ring facing the centre.
@export var props: PackedStringArray = []
@export var prop_scale: float = 1.0
## Local light (none when energy is 0).
@export var light_color: Color = Color(1.0, 0.85, 0.7)
@export var light_energy: float = 1.2
@export var light_height: float = 3.5
## FX scene id under world/spring_court/wider/fx/particles (fx_<id>.tscn), or empty.
@export var fx_id: StringName = &""
## Positional loop: a SoundCue resource path (L15's cue contract), or empty.
@export var sound_cue: String = ""
@export var canon: String = "X"
