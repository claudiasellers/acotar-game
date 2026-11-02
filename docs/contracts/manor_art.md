# Contract: the manor's paintings (L39)

Every painting in the manor house is a real, unique work tied to the story. The
layouts only place **art slots**: the refurnish lane (L38) owns where they
hang. This lane owns what hangs in them.

## Pieces

| File | What |
|---|---|
| `tools/art/manor_paintings/catalog.py` | Every work: id, title, genre, format, room themes, canon tag, story link, recipe. The source of truth. |
| `tools/art/manor_paintings/build.py` | Paints every work (Blender lay figures + a brush engine), packs the texture array, writes the catalogue resource and the Keeper's review list. |
| `tools/blender/manor_art_refs.py` | Blender references: sitters (the cast bodies, re-dressed) and tableaux (creature models). |
| `tools/blender/manor_frames.py` | The frames: 12 styles, 8 shapes, a plaque under each. Prop-kit finishes only. |
| `art/house/paintings/paintings.webp` | Every hangable canvas: one WebP of 2048 x 2040 layers, two across, imported as a VRAM-compressed `Texture2DArray` with mipmaps (generated, committed like `prythian_mural.webp`). Held-back works are not in it. |
| `data/manor_art/manor_art_catalog.tres` `ManorArtCatalog` | Built; never hand-edited. Works (`ManorArtWork`), `room_themes`, `room_patterns`. |
| `world/spring_court/manor_estate/art/manor_art_hanger.gd` `ManorArtHanger` | `assign()` gives every slot a work, `hang()` dresses the built house. |
| `world/spring_court/manor_estate/art/manor_art_canvas.gd` `ManorArtCanvas` | Canvas meshes (rect, oval, round, arch) matching the frame openings. The array layer rides in UV.x as its whole part (the mesh merger keeps UV, not UV2). |
| `world/spring_court/manor_estate/art/manor_canvas.gdshader` | Oil on canvas: weave, varnish sheen, albedo ≤ 0.85, no emission. |

`ManorHouseBuilder.build()` calls `ManorArtHanger.hang(house, all)` once, after
the rooms are built and before their props merge.

## Slots

A slot is any prop placement whose id is `painting_large`, `painting_medium`,
`painting_small` or `portrait_masked`, keyed `room_id@level#n` (n counts the
art placements in that room, in order). The stand-in's `Look` is replaced by a
frame and canvas; the prop node keeps its name, position and rotation and gets
the meta `art_id`. The frame's back sits on the stand-in's back face; the
whole frame, crest to plaque, is kept between 0.25 m above the floor and the
ceiling.

Slot classes: `large` hangs major works up to 2.3 x 1.62 m (others up to
1.6 x 1.25); `medium` up to 1.25 x 1.1; `small` up to 0.62; `portrait` (only
portraits) up to 1.05 x 1.4, full-length up to 1.3 x 1.95.

## Rules

- **No work hangs twice anywhere in the house.** `assign()` hands each work out
  once; if the house ever has more slots than works it reuses (never in the
  same room) and lists them in `last_duplicates`, and the test fails. Add works
  to `catalog.py` and rebuild, never repeat one.
- Pinned works hang in their rooms first: `still_green_glass_vase` (ch7) in
  `upper_hall` by the stair (the slot nearest x 0.15, z 5.0), else
  `entrance_hall`, `two_boys_birch` in `svc_alis_room`.
- Works whose themes are only `store`, `store_secret` or `portrait_dim` hang
  only in rooms with one of those themes (the Keeper: Tamlin's father and
  brothers only in dim side rooms).
- Room themes: `build.py` `ROOM_THEMES` (by id, or `id@level`), then
  `ROOM_PATTERNS` by substring for new rooms. A new room needs no change here.
- Every work has a canon tag (`C`, `C?`, `X`), a story link, a source and a
  licence. Images are made for this game; nothing reproduces a real artwork.
- Subjects are Prythian and the Spring Court, nothing from later books (Keeper).
  Plaques and any script are illegible: Feyre can't read (ch13).
- Canvases: whites ≤ 0.85 (L18-4), never emissive. Every canvas shares one
  material (the array), so a room's canvases merge into one draw call; frames
  use prop-kit finishes and merge into the props' existing draws. The test
  holds the house to ≤ 60 canvas draws and one per room.
- Held-back works (`reserve`) stay in the catalogue and the Keeper's list but
  never hang and are not packed.
- The gallery moment (`painting:gallery_seen`, anchor `manor_gallery`) is not
  touched: the gallery trigger, its anchors and its open sky stay as they are.

## Rebuilding

    python3 tools/art/manor_paintings/build.py          # all works; cached by recipe
    /opt/bpyenv/bin/python tools/blender/manor_frames.py

Then a headless `--import` so a new array and new frames get their `.uid` and
`.import` files. Test: `tests/unit/manor_art/test_manor_art.gd`.
