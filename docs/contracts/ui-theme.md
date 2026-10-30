# UI theme contract (L13)

Shared look for every UI lane. Owner: L13 (UI art direction). Changing a name here needs the director's OK.

## Files
- `res://ui/theme/acotar_theme.tres`: Spring Court theme (default after the Wall).
- `res://ui/theme/acotar_theme_human.tres`: Act I human-realm theme.
- `res://ui/theme/acotar_palette.gd` (`AcotarPalette`): colours per act; read them from here or from the theme, never hard-code.
- `tools/ui_theme/build_acotar_theme.gd`: regenerates both `.tres` (`godot --headless -s tools/ui_theme/build_acotar_theme.gd`). Don't hand-edit the `.tres`.
- `res://ui/theme/icons/notify/<name>.png` (coming): notification icons `thought, pickup, first_find, rare_find, recipe, truth, keepsake, sketch, painting, wardrobe, map, hunt`, 256 px plus `_128` versions.

## Type variations
| Variation | Base |
|---|---|
| SatchelCard, SatchelDetail, QuickBarSlot, QuickBarSlotSelected, NotifyCard | PanelContainer |
| SatchelTab, SatchelSlot, MenuTab | Button (all states, including focus) |
| SatchelHeading, SatchelBody, SatchelSmall, SatchelCount, QuickBarKey, QuickBarCount, MenuTitle, NotifyText, ThoughtText | Label |
| SatchelMeter | ProgressBar |

Colours under theme types `Satchel` and `Acotar`: `paper, paper_deep, ink, ink_soft, accent, glow, rare, danger, line`. (`glow` is a flat highlight; the direction uses no glow effects.)

## Rules
- Type: EB Garamond (body Medium, display SemiBold, thoughts MediumItalic).
- Flat fills and line ornament only: no gradients, outer glows or bevels in UI chrome. Juice (sparkle, chime, bounce) stays on events, per R3.
- Swap the theme by act: Act I uses `_human`, from the wall crossing onward use the Spring theme.
- The look is provisional until the user picks a direction (A painted drawer, B engraving, C herbarium; see /mnt/project-files/ui-direction/image-prompts.md). Names stay stable, and styleboxes will become textures.
