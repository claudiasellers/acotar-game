## Every bow feel number that isn't per bow, in one place (R8). The values and
## what each one changes: plans/combat/bow-combat-design.md §10 and
## docs/tuning.md "Bow feel".
class_name BowTuning
extends Resource

@export_group("Shot cycle")
## After a shot, seconds before the next draw can start (the bow stays raised).
@export var follow_through_s: float = 0.25
## Past the bow's true range, gravity eases in over this many seconds.
@export var gravity_blend_s: float = 0.4
## The bow stays in her hands this long after the last shot or the last hold.
@export var stay_up_s: float = 1.6

@export_group("Sway")
## Her hands stay steady through ordinary hunger, cold and fear: BodyState's
## sway multiplier counts only past this, and its tremor (degrees) only past
## steady_tremor. Hungry and cold in the winter wood is inside both.
@export var steady_body: float = 2.2
@export var steady_tremor: float = 0.45
## Holding a full draw longer than this starts the trembling arm.
@export var fatigue_after_s: float = 3.0
@export var fatigue_rate: float = 0.25
@export var fatigue_max: float = 2.0
## Stamina per second while the trembling arm lasts.
@export var hold_drain: float = 6.0
## Below this fraction of stamina her breath shakes the aim.
@export var breath_low_fraction: float = 0.25
@export var breath_low: float = 1.5
@export var breath_winded: float = 2.0
@export var breath_winded_tremor: float = 0.4

@export_group("Focus")
## Time scale while Focus is held (the TimeScale request &"bow_slow").
@export var focus_scale: float = 0.4
## Stamina per real second while Focused, times (1 + focus_dread_drain x dread).
@export var focus_drain: float = 28.0
@export var focus_dread_drain: float = 0.5
@export var focus_sway: float = 0.4
## Dread above which Focus is the shakier, panicked kind.
@export var panic_dread: float = 0.6
@export var focus_sway_panic: float = 0.6
## Real seconds Focus holds after the release, so the arrow leaves in the hush.
@export var focus_hold_after_release_s: float = 0.3

@export_group("Feedback")
## The share of her draw she keeps when a blow lands on her.
@export var draw_kept_when_hit: float = 0.5
## The share of her draw she keeps through a sidestep.
@export var draw_kept_when_sidestepping: float = 0.5
## How long the crosshair's catch at full draw and its pulse on a creature
## hit last (real seconds).
@export var full_draw_catch_s: float = 0.18
@export var hit_pulse_s: float = 0.22
## The Focus hush on the Ambience bus (dB), and how fast it comes and goes.
@export var hush_duck_db: float = -12.0
@export var hush_fade_s: float = 0.12

@export_group("Camera")
## Mouse and stick look speed while the bow is raised.
@export var aim_sensitivity: float = 0.7
## The release kick rises over this long, then eases back (BowData.kick_degrees).
@export var kick_rise_s: float = 0.06
@export var kick_fall_s: float = 0.15
## FOV change from the base while raised, and while Focused.
@export var fov_raised: float = -10.0
@export var fov_focus: float = -16.0
