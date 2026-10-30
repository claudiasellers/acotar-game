## Shared UI colours per act (L13 art direction). Provisional until the user
## picks a direction; consumers read colours through AcotarPalette or the
## "Satchel"/"Acotar" theme colour types, never hard-code them.
class_name AcotarPalette
extends RefCounted

enum Act { HUMAN, SPRING }

## Act I, human realm: grey-blue and smoke; Feyre's chipped paint is the only colour.
const HUMAN := {
	"paper": Color("#E9E4DA"),
	"paper_deep": Color("#D6D2CB"),
	"ink": Color("#2B2A33"),
	"ink_soft": Color("#5E6670"),
	"accent": Color("#D9A93A"),
	"glow": Color("#E3C35A"),
	"rare": Color("#8E7AA8"),
	"danger": Color("#8E2A2A"),
	"line": Color("#8C8A86"),
}

## Spring Court: the manor's pale green and ivory with gold-sketched pattern;
## rose and blush are accents (Keeper, ch 5–7). Flat, no gradients or glows.
const SPRING := {
	"paper": Color("#FBF7EE"),
	"paper_deep": Color("#DDEBDC"),
	"ink": Color("#5A2E44"),
	"ink_soft": Color("#8E6A6E"),
	"accent": Color("#F4A6C0"),
	"glow": Color("#FCE9A6"),
	"rare": Color("#C8A8E9"),
	"danger": Color("#7A2E45"),
	"line": Color("#D4A94F"),
}


static func colours(act: Act) -> Dictionary:
	return HUMAN if act == Act.HUMAN else SPRING
