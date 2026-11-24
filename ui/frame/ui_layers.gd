## Every CanvasLayer number in the game, bottom to top. A script that makes a
## CanvasLayer takes its number from here and from nowhere else.
## Contract: docs/contracts/ui-frame.md.
class_name UiLayers
extends RefCounted

## Screen-edge effects (venom, low health, frost, dread, stealth).
const EDGE := 1
## The film stack: the grade at -1, inserts here, a staged lens's letterbox
## at +1, the film's veil at +3, its text at +4.
const FILM := 3
## HudLayout, the only HUD layer.
const HUD := 10
## The dim behind an open screen.
const BACKDROP := 17
## The book's pages, under its tab strip.
const PAGE := 19
## Open screens. ScreenStack gives each SCREEN + its depth.
const SCREEN := 20
## Spoken lines, thoughts, whispers (a whisper at +1, over a line). A story
## page held up mid-scene sits at -1, over any screen.
const LINE := 25
## Story fades and blackouts (-1 for one that must sit under another; +1 for
## travel cards drawn on the black).
const VEIL := 30
## The few things that must read over a fade.
const OVER_VEIL := 40
## The loading veil.
const LOADING := 90
