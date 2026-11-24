# The journal's art

`ui/menu/art/book.webp` (the open book: cover, sheets, vines, paint dabs) and
`ui/menu/art/sky.png` (the night-sky stroke) are pictures of the mock the owner
chose (Direction E, Feyre's Journal; project files
`ui/redesign/directions/src`). `render_book.js` takes them from that mock with
Playwright: `node render_book.js <mock folder> <out folder>`, then the book is
scaled to 2790 x 1590 and saved as WebP at quality 92. `ui/menu/art/wash.png`
is a white watercolour blot, tinted in the game. They are source art: change
the mock and render again, never paint over them by hand.
