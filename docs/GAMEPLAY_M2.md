# Gameplay systems, Spring Court: definition of done

Owner: gameplay lane. Written before the work. Three handoffs, each under ~1,500 hand-written lines.

## Slice A: stations, bows, arrows
1. All 7 stations usable through one `CookingStation` node: hearth, campfire, manor kitchen (cook, preserve, bake), stillroom (infuse, distill, salve, steep), fae potion room (infuse, tincture, salve, steep; halves fae toll), starlight pool (steep, **night only**), Rite cave fire (stew, **only once `calanmai_attended` is set**). Conditions are data on `StationData` (`night_only`, `required_flag`). Tested: each station accepts its methods and refuses others; the pool refuses by day; the Rite fire refuses before the flag.
2. Steeping arrows: a steep result plus wood arrows at a steep station makes steeped arrows. The steep's strongest tag picks the type: quiet → sleep, fae/vital → lure, warm → fire, cool → frost, bright → light. Tested for all 5.
3. 10 arrow types as `ArrowData`: wood, ash (unique, bought), barbed, rope, signal, and the 5 steeped. On hit each applies its effect: fire ignites the target's `ElementState` and lights a flame, frost chills and soaks, light leaves a glow, signal flares upward, rope leaves a climbable anchor (group `rope_anchor`), sleep/lure/barbed set `arrow_effect` meta and call `on_arrow_effect(effect, arrow)` for creatures. Tested on stand-in targets.
4. Craft recipes for barbed, rope and signal arrows. Tested.
5. Bows 2–5 (`yew_longbow`, `fae_recurve`, `sentry_warbow`, `gilded_bow`) as `BowData` + inventory items, each strictly better on at least one axis (draw speed, launch speed, sway) and with an honest trade-off. `BowController` equips any owned bow (key B cycles). Tested.
6. Flora stays Keeper-confirmed plus `[X]` additions; `ash` is the only anti-fae tag; no iron effect.

## Slice B: painting
7. Pigments as items (`pig_*`, ≥10 colours) made by infusing pigment ingredients (Chemistry already detects pigment infusions). Tested.
8. Easel station (`station_id` `easel`) opens a painting UI: 512×384 canvas, round brush (3 sizes), palette from owned pigments; each stroke spends pigment charges (1 pigment item = 40 strokes). Tested on the canvas model without UI.
9. Finishing saves the image to `user://paintings/<id>.png`, records it in `Gameplay.gallery` (saved), and hangs a framed `PaintingObject` in the world (nearest node in group `painting_hook`, else beside the easel). The first finished painting fires an `ActionTrigger` for `first_painting`. Tested, including save/load.

## Slice C: collection book and dress-up
10. Collection book (key J): tabs for ingredients (found / total), keepsakes, recipes, story truths, sketches, paintings and wardrobe, with colour swatch icons, progress bars, a "new" badge and juice when something new is logged. Discovery is tracked on first pickup. Tested on the progress model.
11. Wardrobe ≥150 pieces (more gowns and colour variants, tunics, cloaks, jewellery incl. new `ears` and `wrist` slots, ≥8 masks), ≥14 hairstyles, ≥50 makeup looks. Tested counts and slot validity.

Checks per slice: `godot --headless --import` clean and only this lane's GUT dirs. No screenshots in A; one each at the end of B and C.

## Slice D: reward loop (plans/experience-bar.md §1.4, lead designer)
12. Pickup arc: a glowing token in the item's colour arcs from the pickup to Feyre's satchel in 0.25 s, with a sparkle and a bounce on arrival.
13. Combo chime: pickups within 3 s of each other step up a pentatonic scale (8 steps, then hold); a 3 s gap resets it.
14. First find of a type: a big card with an illustrated icon, the name in a script face and one flavour line, held 1.2 s; the game never pauses for it. Rare finds get a gold card and a bigger burst.
15. Every item has an icon shape (flower, berry, leaf, mushroom, feather, gem, drop, twig, shell, meat, pelt, trinket) drawn procedurally. In the book an unfound entry shows that shape as a lilac silhouette plus a place hint ("Estate woods, at dusk"), never a bare "?". Every unfound ingredient and keepsake has a non-empty hint (tested).
16. Each book page has rewards along its progress bar (≥3 per fixed page: outfit colours, sketches, pigments). The next reward shows on the page; reaching it grants it with an unlock burst. Tested.
17. Rarity: 10–15% of ingredient and keepsake types are rare, each bound to a time or weather window (dawn, dusk, night, rain, mist, snow); about a third of those are shiny and glimmer in the book. `ForageRegistry.in_window(item, hour, weather)` lets region lanes gate spawns. Tested.
18. Woven flower crown: C (or d-pad down) weaves a crown from 5 picked blooms, coloured by the blooms used (rose, butter, lilac, pearl, sky). It is put on at once with the outfit burst. Mesh: the existing flower_crown.glb tinted; per-colour meshes requested from the Blender thread. Tested.
