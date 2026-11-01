# Contract: the wounded Summer faerie (ch 17, L29)

Story lane L29 owns `story/act3/summer/**`. The scene is a deed, not a cutscene,
and it cannot be won (keeper, from the text): he dies whatever Feyre does.

## Where

- Two `Act3Anchors.ROWS` rows hang both spaces under the entrance-hall anchor
  `manor_window_hide`; each places itself in world space in `_ready`.
- `SummerFaerieTriage` sits on its own long table at world XZ (0, -35), between the
  front doors and the grand stair ("the long table in the center of the hall" [C]).
  The table, vase, conjured bowl and linen, and the blood pool are built in code
  (`TriageProps`). Region lanes: keep 3 m around that point clear.
- `SummerFaerieGrave` is in the fields beyond the rose garden at XZ (24, -228)
  (deer park edge; the grave is canon "X"). Region lanes: keep 4 m clear.

## Flags (all raised through the spaces' ActionTriggers, R2)

| Fact | When |
|---|---|
| `fact.summer_faerie_held` | she was beside him (2.5 m) or holding his hand when he died |
| `fact.summer_faerie_died_alone` | she was anywhere else |
| `fact.summer_faerie_buried` | either way; the grave appears |
| `fact.summer_faerie_mourned` | the daytime vigil at the grave (only after dying alone) |
| `fact.summer_faerie_farewell` | held, or mourned; the `summer_faerie` moment turns it into `summer_faerie_comforted` |

Later scenes may read `held` / `died_alone` for their own lines.

## Journal entries

`summer_faerie_wings` (held, and he spoke), `summer_faerie_held` (held, no words),
`summer_faerie_alone`, `summer_faerie_grave`.

## Actor cues (EventBus.story_actor_cue; unknown cues may be ignored)

| Actor | Cue | Meaning |
|---|---|---|
| `summer_faerie` | `laid_out` | spawned lying face down on the table (head toward -X); please pose for it |
| `summer_faerie` | `speaks` | he comes round: "She took my wings." |
| `summer_faerie` | `hand_held` | Feyre takes his hand |
| `summer_faerie` | `dies` | last breath. Must not stand or rotate the body: he stays on the table |
| `tamlin` | `tends_the_faerie`, `holds_other_hand`, `holds_him_alone`, `prays` | |
| `lucien` | `leaves_sick` | backs away, sick, and leaves |

Until the creature lane implements `laid_out`, the story poses the actor's root
itself and, at death, sets the actor's `alive` to false instead of letting the
current `dies` tween stand him up. When the actor exposes `laid_out == true`
the story leaves `dies` to it.
