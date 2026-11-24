## Where things sit on the open book: Feyre's journal, 1700 x 900 on a
## 1920 x 1080 screen, its two sheets, and the index tabs along its top edge.
## The shell draws the book; every page lays out on these rects and nowhere
## else, so the five pages are one book.
class_name BookLayout
extends RefCounted

const ART := "res://ui/menu/art/book.webp"
const SKY := "res://ui/menu/art/sky.png"
const WASH := "res://ui/menu/art/wash.png"

const SIZE := Vector2(1700, 900)
## The screen the book is drawn for. On a smaller one (a larger text size
## makes the screen smaller, in its own units) the whole book shrinks to fit.
const SCREEN := Vector2(1920, 1080)
## The book's centre, from the screen's centre: room for the tabs above it.
const DROP := Vector2(0, 38)
## The art carries the cover's shadow this far past the book on every side.
const ART_BLEED := 80.0
## The writing area of each sheet, in book space: inside the vines she
## painted in the corners and the paint dabs down the right edge.
const LEFT := Rect2(104, 64, 700, 776)
const RIGHT := Rect2(900, 64, 704, 776)
## Both sheets as one, for a page that is a single picture (the map).
const SPREAD := Rect2(104, 64, 1500, 776)
## The index tabs: their left end and their foot, in book space.
const TABS_AT := Vector2(66, 4)
## Where the ribbon leaves the book's foot: the top centre of its tab.
const RIBBON_AT := Vector2(905, 898)


## How much smaller than drawn the book is on a screen of `view` size.
static func fit(view: Vector2) -> float:
	return minf(1.0, minf(view.x / SCREEN.x, view.y / SCREEN.y))


## The book's top-left corner on a screen of `view` size.
static func origin(view: Vector2) -> Vector2:
	var scale := fit(view)
	return ((view - SIZE * scale) * 0.5 + DROP * scale).round()


## Where a rect of the book (LEFT, a page's window) lands on the screen.
static func on_screen(view: Vector2, rect: Rect2) -> Rect2:
	var scale := fit(view)
	return Rect2(origin(view) + rect.position * scale, rect.size * scale)
