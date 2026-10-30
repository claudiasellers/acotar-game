# Contract: the glamour on Feyre's senses

Owner: story/core lane. Source: Keeper, chapter-verified (ch23).

## State
- One story flag, `glamour_lifted`, raised only through an `ActionTrigger` by the story scene that lifts it (ch23). Before it: Feyre cannot see true fae forms, and magic smells of metal. After: true forms, and magic smells of flowers.
- Read it with `GlamourLayer.is_lifted()`; react to it on `EventBus.flag_changed` (flag `"glamour_lifted"`).

## World-layer swap
- `GlamourLayer` (`story/framework/glamour_layer.gd`, a Node3D) with `layer = GLAMOURED` or `TRUE_FORM`. Its children are visible (and their collision active) only in the matching state. The swap is instant when the flag rises and is correct after a save is loaded.
- Creature, NPC and region lanes supply both layers as siblings:

```
Puca (your actor root)
├── GlamourLayer (layer = GLAMOURED)   → what she sees first
└── GlamourLayer (layer = TRUE_FORM)   → the true form
```

- Scent: `GlamourLayer.magic_scent()` returns `&"metal"` or `&"flowers"`. Audio, VFX and sense systems key on it; nobody hard-codes the state.
- Logic that must differ (an NPC's reaction, a sense cue) reads `GlamourLayer.is_lifted()`; no other flag or global stands for the glamour.
