# acotar-game

An open-world adventure set in Prythian, built in Godot 4.7. Play as Feyre, from the human realm in winter to the Spring Court, ending at the road to Under the Mountain.

- Root design doc: `GAME_DESIGN_PLAN.md` in the project files (wins where documents differ).
- Book facts: the Keeper of the Story's lore bible (`lore/` in the project files).
- How lanes work and hand off: [docs/LANES.md](docs/LANES.md).

## Layout

```
core/        Autoloads: EventBus, WorldState, Clock, PhaseManager, SaveSystem
data/        Resources: phases/, bows/ (later ingredients, recipes, arrows, outfits, creatures...)
systems/     ActionTrigger, RegionGate, bow/ (arrows)
world/       human_realm/, spring_court/, shared/ (test_hill for M0)
characters/  feyre/ (placeholder until the art lane delivers her model)
creatures/  ui/  art/  docs/
tests/       GUT unit/ and integration/ tests
addons/gut/  GUT 9.7.1 test framework (vendored)
```

## How the story moves

Gameplay never calls story code. An `ActionTrigger` raises a flag in `WorldState` when Feyre does something (reaches a place, hits a target, closes a snare). `PhaseManager` checks the current phase's `ExitCondition` and, when it is met, enters the next phase, which unlocks regions. Each region's `RegionGate` is a physical lock (thorns, wards, sentries) that disappears when its region opens.

Phase ladders are data: `data/phases/spring_court_phases.tres` is the root doc's phases 0 to 8; `data/phases/m0_test_phases.tres` drives the test hill.

## Running

The main scene is the M0 test hill. Controls: WASD move, Shift sprint, Space jump (and climb ledges), hold left mouse to draw and release to shoot, right mouse to aim, E to pick up a stuck arrow, Esc to free the mouse. Gamepad is mapped too.

Tests (headless):

```
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd
```
