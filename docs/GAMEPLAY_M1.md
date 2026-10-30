# Gameplay systems, M1: definition of done

Owner: the gameplay lane (`systems/`, `data/` except `data/phases/`). Written before the work started; the lane stops when every box below is true.

## Done means

1. **Bow and arrows**
   - `ArrowData` resources for wood and ash arrows (drag, wet drag, stone break chance, fae lethality).
   - Arrows fly with gravity, quadratic drag against the air *relative to the wind* (`Weather.wind_at`), and wet fletching flies measurably short. Unit tests prove: drag shortens range, crosswind drifts the arrow downwind, wet lands shorter than dry.
   - Arrows hitting stone (group `stone` or meta `surface == "stone"`) break by their data's chance (seeded, tested); intact arrows stick and are retrievable as the same arrow type.
   - Every arrow carries `arrow_id` (property and meta), `data.fae_lethal`.
   - Slow time while drawing and aiming, draining stamina; normal time when stamina runs out or the draw ends (tested on the controller logic).
   - Crafting: wood arrow = shaft + fletching feather + arrowhead; ash arrow = ash wood carved + feather. Shafts are carved from hazel rods, heads knapped from flint or bought. Tests prove inputs are consumed and outputs added, and missing inputs fail cleanly.
2. **Inventory**: weight classes; quiver (arrows by type), satchel, forage pouch, keepsakes, sketchbook; routing by item kind and weight class with overflow; encumbrance as a speed multiplier; coin, buy and sell; save/load round trip. Tested.
3. **Foraging**: one pickup path for all world lanes (group `forage` with `harvest()`, group `forage_field` with `pick_nearest()`, and the lane's own `ForageScatter`). Picked instances hide and respawn on `Clock` after their data's respawn days. Tested.
4. **Chemistry**: data for **every** ingredient in the lore catalogue (not only the winter set), stations and methods; rules (reinforce, cancel, bitter flips healing, fae multiplies and adds toll, bind required for salves and steeps, ash/iron apply-only). The hearth station with roast, stew and infuse works with the ~10 human-realm winter ingredients. Proof journal records each discovery once. Tested with numbers.
5. **Body state**: cold and hunger from weather, element state, time and food; outputs aim sway, bow-hand tremor and breath (visible breath particles on placeholder Feyre). Family food tally emits `food_stock_changed`. Tested.
6. **Notice moments and sketchbook**: `NoticePoint` + director; soft camera drift when Feyre is idle and roughly facing it; holding the look adds the sketch once. Tested on the logic.
7. **Element states**: `ElementState` component with fire, wet and cold, their interactions, and a `Weather` node (group `wind_source`, `wind_at`). Tested.
8. Test hill shows the systems in play: hearth, winter forage, notice points, weather.
9. Checks run: import clean, plus only the new/changed tests in this lane (full suite is the build lane's job). One milestone screenshot at most.

## Not in M1
Painting tool, stillroom/kitchen stations beyond data, outfit effects, UI polish (the hearth panel is functional, not final).
