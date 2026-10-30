# Feyre move set: credits

`feyre_moves.glb` holds motion-capture clips retargeted onto Feyre's rig by
`tools/blender/feyre_moves/retarget_moves.py` (deterministic; rerun it to rebuild).

## Source

- **Mesh2Motion** by Scott Petrovic and contributors:
  <https://github.com/scottpetrovic/mesh2motion-app>, commit
  `eef2de986dab53283cb636f860d502d64b8073e7`
- Files: `static/animations/human-base-animations.glb`,
  `static/animations/human-addon-animations.glb`
- Licence: **CC0 1.0 Universal** (public-domain dedication, `LICENSE-CC0.MD` in that
  repository). No attribution is required; this file records provenance anyway.

## Clip mapping

Source frame ranges are on a 30 fps timeline (the sources are keyed at 24 fps).

| Feyre clip      | Source file | Source clip        | Frames used  | Notes |
|-----------------|-------------|--------------------|--------------|-------|
| `idle`          | addon       | `Idle_Subtle`      | 1.25-77.5    | loop, 2.53 s |
| `walk`          | addon       | `Walk_Female`      | 1.25-41.25   | loop, played x1.43 (0.93 s) |
| `run`           | addon       | `Run_Female`       | 1.25-25      | loop, 0.80 s |
| `sprint`        | base        | `Sprint`           | 0-25         | loop, played x1.25 (0.67 s) |
| `jump_start`    | base        | `Jump_Start`       | 1.25-8.25    | crouch and push-off, 0.23 s |
| `jump_rise`     | base        | `Jump_air`         | 0-24         | ping-pong loop, 1.6 s; arms lowered from the source's level T to her sides, soft elbows, opposite arm swing |
| `jump_fall`     | base        | `Jump_air`         | 24-48        | airborne, legs reaching down, ping-pong loop, 1.6 s; arms lowered to a balance pose |
| `jump_land`     | base        | `Jump_Land`        | 1-12         | impact and absorb, 0.37 s; arms brought in from the flail |
| `jump_double`   | addon       | `Jump_2`           | 3.25-17.25   | tucked second jump, x1.27, 0.37 s |
| `jump_flourish` | addon       | `Jump_2`           | 3.25-17.25   | tucked pose under the game's procedural front flip, 0.6 s |
| `land_hero`     | addon       | `Land_Three_Point` | 13.25-30.25  | impact to three-point kneel, 0.57 s |

Changes made in retargeting: rotation transfer to Feyre's skeleton, hips scaled to
her leg length and made in place (no root motion), feet grounded each frame, a
stance-foot lock and hip surge on the gait loops, swing-leg clearance on the run, and
trimming and retiming as listed above. Native ground speeds for the gait loops are in
`data/animation/feyre_moves_speeds.txt`.
