"""The manor's art: every work that can hang in the house, one entry each.

Each entry is unique by construction (its own id, title, subject and seed);
tests/unit/manor_art/test_manor_art.gd checks that no work hangs twice.

Keys: id, title, genre (landscape|still|portrait|animal|plate|botanical|map|
cauldron|interior), fmt (land|port|square|oval_p|oval_l|round|arch_p), major
(painted at 1024 for the 2.6 m frames), rooms (themes where it may hang, see
ROOM_THEMES in build.py), canon ("C" book, "C?" map lore, "X" invented, per
lore/00-keeper/README.md), ref (the story link, shown to the keeper and kept
in the .tres), pin (a room id it must hang in first), eye (human|fae: ch19,
some works seen "through eyes like mine", others with "a bend to the world"),
age (0..1: varnish, craquelure; pre-Treaty works are old), and the genre's own
parameters. Sitters and tableaux are rendered in Blender first
(tools/blender/manor_art_refs.py).

Keeper rulings (2026-11-02): gallery = pastorals, portraits, still lifes, no
named works; portraits from before the curse (49 years ago) are unmasked,
after it masked; Tamlin's mother may hang in honour, his father and brothers
only in dim side rooms (he is ashamed of them); War/Treaty/Wall subjects fit
the library; Bogge plates show a shape that never resolves; nothing from later
books; nothing triumphant about human slaves.
"""

WORKS = []
_SEED = [1000]


def w(id, title, genre, fmt, rooms, canon, ref, **p):
    _SEED[0] += 7
    e = dict(id=id, title=title, genre=genre, fmt=fmt, rooms=rooms, canon=canon, ref=ref, seed=p.pop("seed", _SEED[0]),
             major=p.pop("major", False), eye=p.pop("eye", "fae"), age=p.pop("age", 0.0), pin=p.pop("pin", ""))
    e.update(p)
    WORKS.append(e)


# RGB helpers for sitters (sRGB 0..1)
ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, PEARL = [0.95, 0.6, 0.72], [0.98, 0.82, 0.86], [0.8, 0.72, 0.95], [0.66, 0.74, 0.96], [0.66, 0.88, 0.76], [1.0, 0.9, 0.6], [0.95, 0.93, 0.96]
EMERALD, RUBY, GOLDC, RUSSET, SKY, PLUM, SILVER, IVORY = [0.25, 0.62, 0.48], [0.75, 0.2, 0.32], [0.9, 0.75, 0.4], [0.75, 0.38, 0.22], [0.6, 0.78, 0.95], [0.45, 0.25, 0.45], [0.85, 0.86, 0.92], [0.97, 0.94, 0.88]
H_GOLD, H_HONEY, H_AUBURN, H_BLACK, H_SILVER, H_CHESTNUT, H_COPPER, H_ROSE, H_WHITE = [0.95, 0.78, 0.45], [0.85, 0.6, 0.35], [0.65, 0.28, 0.18], [0.12, 0.1, 0.14], [0.9, 0.9, 0.95], [0.45, 0.28, 0.2], [0.85, 0.45, 0.25], [0.95, 0.66, 0.75], [0.97, 0.96, 0.98]
SK_GOLD, SK_BRONZE, SK_UMBER, SK_PEARL, SK_BARK, SK_BLUE = [1.0, 0.92, 0.82], [0.82, 0.66, 0.55], [0.6, 0.45, 0.38], [1.0, 0.97, 1.0], [0.72, 0.58, 0.48], [0.62, 0.75, 0.95]


def sitter(model, frame="bust", **k):
    d = dict(model=model, frame=frame)
    d.update(k)
    return d


# =================================================================== canon anchors

w("still_green_glass_vase", "Still Life with a Green Glass Vase", "still", "port", ["hall"], "C",
  "Ch7: the first hall painting Feyre stops at, a green glass vase of roses, tulips, morning glory, goldenrod, maiden's lace and peonies against a dark ground; she had never seen anything like it.",
  pin="upper_hall@0.15,5.0|entrance_hall", eye="human", age=0.25, ground="dark", vessel="green_glass", table="ledge",
  flowers=["rose", "tulip", "morning_glory", "goldenrod", "maiden_lace", "peony"], blooms=34, bouquet_r=0.27, vase_h=0.28)
w("cauldron_making", "The Cauldron Poured", "cauldron", "port", ["shrine", "library"], "C",
  "Ch13 mural, first panel: a black cauldron tipped by glowing, slender female hands in a starry night, spilling gold effervescent with symbols.", age=0.5)
w("war_before_treaty", "The War", "landscape", "land", ["library", "store"], "C",
  "Ch13 mural: bloodied mud; human soldiers facing High Fae in glimmering armour and faeries with claws and fangs. Not for human eyes.",
  major=True, eye="fae", age=0.6, time="storm", season="blight", far="hills", mid_trees=False, flowers=0.0, features=["battle"], show_sun=False)
w("treaty_signed", "The Treaty", "landscape", "land", ["library"], "C",
  "The Treaty ended the War five centuries ago and split the land at the Wall; humans freed. Signing scene [X].",
  major=True, eye="human", age=0.55, time="overcast", season="summer", far="hills", features=["signing"], flowers=0.2, mid_n=6)
w("wall_raised", "The Wall at First Light", "landscape", "land", ["library", "hall"], "C",
  "The Wall: invisible and magical, crossable only at gaps (prythian-overview). Painted as a shimmering veil across the land.",
  major=True, age=0.4, time="dawn", season="spring", far="mountains", features=["wall"], wall_k=0.75, trees=["conifer", "round"])
w("lone_peak", "The Mountain in the Middle", "landscape", "land", ["store", "library"], "C",
  "Ch13 mural, last panel: a snowy range with a mammoth, solitary peak, bald of snow, bald of life. Unnamed.",
  age=0.5, time="twilight", season="winter", far="peak", mid_trees=False, flowers=0.0, eye="fae")
w("court_map_spring", "The Spring Court, Mapped", "map", "land", ["library", "study", "map"], "C?",
  "Spring is the southernmost court, painted with crocuses, lambs and roses; the Wall a dark smear to the south (ch13).", age=0.35)
w("court_map_estate", "The Estate and its Woods", "map", "square", ["map", "study", "library"], "X",
  "The manor among its woods: the region Feyre maps by hand in ch12.", seed=4410, age=0.2)
w("rose_garden_gift", "The Rose Garden, a Mating Gift", "landscape", "land", ["gallery", "hall", "bedroom"], "C",
  "Ch19: Tamlin's father planted the rose garden for his mother as a mating present.",
  major=True, time="golden", season="summer", far="hills", trees=["blossom"], flowers=1.0,
  flower_cols=["#e8708f", "#f39cb8", "#d0485e", "#fde2ea", "#ffffff"], features=["manor"], manor_w=0.3, manor_x=0.62, fx=["petals", "butterflies"])
w("high_lady_roses", "The High Lady of Spring, with Roses", "portrait", "port", ["gallery", "hall", "portrait"], "X",
  "Tamlin's mother (no description in the book): she loved her mate deeply. Painted before the curse, so unmasked. Keeper: a place of honour.",
  age=0.3, back="roses", sitter=sitter("nesta", "bust", turn=-12, hair="elain", hair_col=H_GOLD, garment=ROSE, trim=GOLDC, hide=["nesta_cloak"], light="soft"))
w("high_lord_father", "A High Lord of Spring", "portrait", "port", ["store", "portrait_dim"], "X",
  "Tamlin's father: 'a tyrant' who kept slaves (ch19). No description. Hung only in dim rooms; unmasked (before the curse).",
  age=0.5, eye="human", back="storm", sitter=sitter("tamlin", "half", turn=10, mask="none", hair_col=H_HONEY, garment=PLUM, trim=GOLDC, light="rembrandt"))
w("elder_brothers", "Two Sons of Spring", "portrait", "land", ["store"], "X",
  "Tamlin's two older brothers, 'just like him' (their father), killed with him by an enemy High Lord (ch19). Stored away.",
  age=0.45, back="storm", pair=[sitter("tamlin", "bust", turn=18, mask="none", hair="lucien", hair_col=H_HONEY, garment=RUBY, light="rembrandt"),
                                sitter("lucien", "bust", turn=-18, mask="none", hide=["EyeOrb"], hair="tamlin", hair_col=H_GOLD, garment=EMERALD, light="rembrandt")])
w("youngest_son", "The Youngest Son", "portrait", "port", ["store_secret"], "X",
  "An old portrait of a golden-haired youth, unmasked: Tamlin before the curse (keeper: sparingly; Feyre has never seen his face). Under a dust sheet in the loft.",
  age=0.35, back="garden", sitter=sitter("tamlin", "bust", turn=-8, mask="none", hide=["tamlin_baldric"], garment=MINT, light="soft"))
w("war_band", "The War-Band Rides Out", "animal", "land", ["store", "study"], "X",
  "Tamlin trained in his father's war-band from youth (ch19).",
  age=0.4, time="dusk", season="autumn", far="hills", flowers=0.1, mid_n=8,
  tableau=dict(items=[dict(src="creatures/models/fae/white_horse.gltf", at=[-1.6, 0.8, 0], yaw=110, tint=[0.6, 0.5, 0.45]),
                      dict(src="creatures/models/fae/white_horse.gltf", at=[0.6, 0.2, 0], yaw=105, tint=[0.85, 0.82, 0.8]),
                      dict(src="creatures/models/fae/white_horse.gltf", at=[2.6, 1.4, 0], yaw=100, tint=[0.45, 0.35, 0.32])],
               cam=dict(at=[0.5, -9, 1.6], look=[0.5, 0.5, 0.9], lens=40), light="rim", sun=[0.6, 0.5, -0.4]))
w("calanmai_fires", "Calanmai: Fires on the Hill", "landscape", "land", ["gallery", "ballroom", "music"], "C",
  "Calanmai, the fire night of spring: bonfires on the hills (festival-sites). The Rite itself is not shown.",
  major=True, time="night", season="spring", far="hills", features=["stones", "bonfire", "dancers"], fire_y=0.8, fire_size=0.14, dancers_n=12, flowers=0.15, mid_n=5, fx=["faelights"])
w("solstice_wisps", "Solstice Dawn with Will-o'-the-Wisps", "landscape", "land", ["gallery", "ballroom", "bedroom"], "C",
  "Ch25: the solstice meadow, will-o'-the-wisps, dancing until sunrise.",
  time="dawn", season="summer", far="hills", features=["dancers"], fire_x=0.5, fire_y=0.72, dancers_n=9, fx=["wisps", "mist"], flowers=0.7)
w("white_mare", "A White Mare by the Painted Stables", "animal", "land", ["hall", "study", "service"], "C",
  "Ch9: the pretty, painted stables; Feyre rides a white mare with Lucien.",
  time="morning", season="spring", far="hills", flowers=0.6, trees=["blossom"],
  tableau=dict(items=[dict(src="creatures/models/fae/white_horse.gltf", at=[0, 0, 0], yaw=110, tint=[0.86, 0.85, 0.88])],
               cam=dict(at=[1.0, -6.4, 1.4], look=[0, 0, 1.0], lens=45), light="soft", sun=[-0.5, 0.5, -0.6]))
w("blight_grove", "The Grove after the Blight", "landscape", "land", ["store", "library"], "C",
  "The blight: a sickness through the courts, the outward sign of Amarantha's poison (the blight and the curse). Grey, wilted spring.",
  age=0.2, time="overcast", season="blight", far="hills", trees=["round", "willow"], flowers=0.15, flower_cols=["#8a7a80", "#9a9480"], fx=["mist"])
w("andras_sentries", "Sentries on the Southern March", "landscape", "land", ["study", "hall"], "C",
  "Tamlin's sentries patrol the lands toward the Wall (spring-court-regions: reg_wall_marches).",
  time="dusk", season="spring", far="mountains", features=["wall", "strollers"], strollers_n=3, masked=True, wall_x=0.8, wall_k=0.4, trees=["conifer"])
w("crocus_lambs_roses", "Crocuses, Lambs and Roses", "landscape", "land", ["gallery", "hall", "nursery"], "C",
  "Spring's emblems as the study mural paints them (ch13): crocuses, lambs and roses.",
  major=True, time="morning", season="spring", far="hills", flower_cols=["#b8a0f0", "#d8c8ff", "#fff1a8", "#e8708f"], flowers=1.2,
  tableau=dict(items=[dict(src="creatures/models/spring/lamb.gltf", at=[-1.2, 0, 0], yaw=150), dict(src="creatures/models/spring/lamb.gltf", at=[0.6, -0.6, 0], yaw=230),
                      dict(src="creatures/models/spring/lamb.gltf", at=[1.8, 1.4, 0], yaw=170), dict(src="creatures/models/spring/lamb.gltf", at=[-2.6, 2.2, 0], yaw=200)],
               cam=dict(at=[0, -7, 1.4], look=[0, 0.8, 0.3], lens=42), light="soft", sun=[-0.5, 0.6, -0.6]))
w("two_boys_birch", "Two Boys under a Birch", "landscape", "square", ["alis"], "X",
  "Alis is raising her dead sister's two sons (ch16). A small, humble picture in her room.",
  pin="svc_alis_room", time="morning", season="spring", far="hills", trees=["birch"], near_trees=[(0.18, "birch")], near_tree_h=0.7,
  features=["strollers"], strollers_n=2, flowers=0.5, eye="human")
w("summer_envoy", "An Envoy from the Summer Court", "portrait", "port", ["gallery", "portrait", "hall"], "X",
  "Summer folk as the book shows one (ch17): blue skin, long black hair, glossy dark eyes. A guest from better days.",
  back="sky", sitter=sitter("lucien", "bust", turn=12, mask="none", hide=["EyeOrb"], hair="nesta", hair_col=H_BLACK, skin=SK_BLUE, garment=[0.5, 0.82, 0.8], trim=GOLDC, light="soft"))
w("autumn_woods_lucien", "The Autumn Court in its Turning", "landscape", "land", ["autumn", "hall", "gallery"], "C",
  "Lucien comes from the Autumn Court, west of Spring (lucien.md, spring-court-regions: reg_autumn_border).",
  major=True, time="golden", season="autumn", far="mountains", mount_col="#c8a0b8", trees=["round", "willow"], water="lake", fx=["rays"])

# =================================================================== the seven courts and the regions (landscapes)

COURTS = [
    ("spring", "The Spring Court at Blossom-Time", dict(time="morning", season="spring", far="hills", trees=["blossom"], fx=["petals"], flowers=1.0)),
    ("summer", "The Summer Court's Bright Coast", dict(time="noon", season="summer", far="cliffs", sea_col="#7fd0d8", mid_trees=False, flowers=0.6, horizon=0.5)),
    ("autumn", "Autumn Woods at Evening", dict(time="dusk", season="autumn", far="hills", trees=["round"], flowers=0.4)),
    ("winter", "The Winter Court's White Peaks", dict(time="morning", season="winter", far="mountains", mount_col="#b8c0e8", trees=["conifer"], flowers=0.0, fx=["snow"])),
    ("dawn", "Dawn over the Eastern Cliffs", dict(time="dawn", season="spring", far="cliffs", sea_col="#f2c0d0", mid_trees=False, horizon=0.48)),
    ("day", "Noon in the Day Court", dict(time="noon", season="summer", far="hills", features=["tower"], tower_x=0.6, roof="#e6c068", trees=["round"], fx=["rays"])),
    ("night", "Stars over the Northern Mountains", dict(time="night", season="winter", far="mountains", mount_col="#4a4a7a", trees=["conifer"], flowers=0.0, crescent=True)),
]
for i, (court, title, prm) in enumerate(COURTS):
    w("court_%s" % court, title, "landscape", "land", ["hall", "corridor", "gallery"], "C?",
      "One of the seven courts of Prythian (prythian-overview); positions are map lore. Part of a set of seven.", **prm)

REGIONS = [
    ("rosewild", "The Rosewild", "reg_rosewild: wild roses spilling from the gardens into the countryside.", dict(time="golden", season="summer", far="hills", flower_cols=["#e8708f", "#f39cb8", "#fde2ea"], flowers=1.3, trees=["round"])),
    ("blossom_vale", "Blossom Vale Orchards", "Spring Court lands (spring-court-regions, reg_blossom_vale): an orchard valley in bloom under the court's endless spring.", dict(time="morning", season="spring", far="hills", trees=["blossom"], mid_n=24, fx=["petals"])),
    ("mirror_lakes", "The Mirror Lakes", "Spring Court lands (spring-court-regions, reg_mirror_lakes): a chain of still pools below the mountains.", dict(time="golden", season="spring", far="mountains", water="lake", trees=["willow", "round"], fore=["swans"])),
    ("greenmarch", "Stone Circle on the Greenmarch", "Spring Court lands (spring-court-regions, reg_greenmarch): wildflower downs and old stone circles at dusk.", dict(time="dusk", season="spring", far="hills", features=["stones"], flowers=1.0, mid_trees=False)),
    ("old_shrines", "The Old Shrines", "Spring Court lands (spring-court-regions, reg_old_temples): overgrown shrines from before the Treaty.", dict(time="golden", season="summer", far="hills", features=["ruin"], trees=["round"], age=0.3)),
    ("western_fells", "The Western Fells above the Summer Coast", "reg_western_fells: an escarpment with the Summer coast far off.", dict(time="dusk", season="spring", far="cliffs", sea_col="#a8d0e8", mid_trees=False)),
    ("masked_hamlet", "A Masked Hamlet", "Spring Court lands (spring-court-regions, reg_mask_villages): a lesser-fae hamlet whose folk wear the curse's masks.", dict(time="morning", season="spring", far="hills", features=["cottage", "strollers"], cottage_x=0.6, strollers_n=4, masked=True)),
    ("manor_drive", "The Manor from the Drive", "Arrival (ch6): alabaster house veiled in roses and ivy at the end of a gravel drive.", dict(time="golden", season="spring", far="hills", features=["manor"], manor_w=0.5, trees=["blossom"], near_trees=[(0.05, "blossom"), (0.96, "blossom")])),
    ("manor_night", "The Manor by Moonlight", "The house at night, lamps lit; a quiet echo of the nights Feyre walks its halls.", dict(time="night", season="spring", far="hills", features=["manor"], manor_w=0.46, trees=["round"], fx=["fireflies"])),
    ("estate_woods", "The Estate Woods in Spring", "Spring Court lands (spring-court-regions, reg_estate_woods): the woods around the manor, sun-dappled and deceptive.", dict(time="morning", season="spring", far="hills", trees=["round", "birch"], mid_n=30, near_trees=[(0.1, "round"), (0.88, "birch")], fx=["rays"])),
    ("western_birches", "Birches by Running Water", "The western woods: young birches by running water, where the Suriel is caught (ch13). No Suriel shown.", dict(time="overcast", season="spring", far="hills", trees=["birch"], water="river", near_trees=[(0.15, "birch"), (0.8, "birch")])),
    ("solstice_meadow", "The Solstice Meadow at Noon", "Spring Court lands (spring-court-regions, reg_solstice_meadow): the solstice meadow by day, flowers and butterflies.", dict(time="noon", season="summer", far="hills", flowers=1.4, mid_trees=False, fx=["butterflies"])),
    ("wall_marches", "Toward the Wall", "Spring Court lands (spring-court-regions, reg_wall_marches): Feyre's road in and out of Prythian, toward the Wall.", dict(time="overcast", season="winter", far="mountains", features=["wall"], trees=["conifer"], flowers=0.0, wall_k=0.45)),
    ("glass_houses", "The Glass Houses in Rain", "The manor's glass houses [X], where the court's flowers are grown, under a silver rain.", dict(time="overcast", season="spring", far="hills", features=["tower"], roof="#c8d8f0", trees=["round"], fx=["mist"])),
    ("hedge_maze", "Evening in the Hedge Maze", "The manor's hedge maze [X] at evening, two masked courtiers walking its paths.", dict(time="dusk", season="summer", far="hills", trees=["round"], mid_n=30, features=["strollers"], strollers_n=2)),
    ("rite_cave_hill", "The Hill of the Rite by Day", "reg_calanmai_hills: the hill and cave of the Great Rite, quiet in daylight.", dict(time="noon", season="spring", far="hills", features=["stones"], stones_x=0.62, flowers=0.8)),
    ("fae_village_market", "Market Day in the Fae Village", "Spring Court lands (plan region): market day in the village of the court's lesser faeries.", dict(time="morning", season="summer", far="hills", features=["cottage", "strollers"], strollers_n=5)),
    ("autumn_border", "Where Spring Meets Autumn", "reg_autumn_border: the forest turning red and gold at the court's edge.", dict(time="golden", season="autumn", far="mountains", trees=["round"], near_trees=[(0.08, "blossom")], fx=["rays"])),
    ("spring_river", "A River through the Downs", "The rivers and fords of the Spring Court's downs [X], crossed by an old stone bridge.", dict(time="golden", season="spring", far="hills", water="river", trees=["willow"], features=["bridge"], bridge_x=0.5)),
    ("starry_fells", "Starlight on the Fells", "A clear night over the Spring Court's high ground [X], faelights drifting below the stars.", dict(time="night", season="spring", far="mountains", mount_col="#5a5a90", mid_trees=False, flowers=0.2, fx=["faelights"])),
]
for rid, title, ref, prm in REGIONS:
    age = prm.pop("age", 0.0)
    w("region_%s" % rid, title, "landscape", "land", ["hall", "corridor", "gallery", "bedroom"], "X", ref, age=age, **prm)

# Pastorals for the gallery: the book's category, varied by season and hour.
PASTORALS = [
    ("Shepherdess at Morning", dict(time="morning", season="spring", features=["strollers", "lambs"], strollers_n=1, lambs_n=6)),
    ("Lambs at the Ford", dict(time="golden", season="spring", water="river", features=["lambs"], lambs_n=5)),
    ("A Picnic under the Blossom", dict(time="noon", season="spring", fore=["picnic"], trees=["blossom"], near_trees=[(0.85, "blossom")])),
    ("Boating on the Lake", dict(time="golden", season="summer", water="lake", fore=["boat", "swans"], trees=["willow"])),
    ("Haymaking on the Downs", dict(time="noon", season="summer", features=["strollers"], strollers_n=4, flowers=0.3, flower_cols=["#ffe070", "#fff1a8"])),
    ("Apple Harvest", dict(time="golden", season="autumn", trees=["round"], mid_n=20, features=["strollers"], strollers_n=3)),
    ("Deer at the Wood's Edge", dict(time="dawn", season="spring", fore=["deer"], deer_n=3, trees=["round", "birch"], fx=["mist"])),
    ("First Snow on the Downs", dict(time="overcast", season="winter", trees=["round"], fore=["deer"], deer_n=2, flowers=0.0, fx=["snow"])),
    ("A Hunting Party", dict(time="morning", season="autumn", fore=["riders"], riders_n=3, hounds_n=4, trees=["round"])),
    ("Swans at Dusk", dict(time="dusk", season="summer", water="lake", fore=["swans"], swans_n=4, trees=["willow"], mid_trees=True)),
    ("A Walk in the Rose Garden", dict(time="golden", season="summer", features=["strollers"], strollers_n=3, masked=False, flower_cols=["#e8708f", "#f39cb8", "#ffffff"], flowers=1.2, near_trees=[(0.06, "blossom")])),
    ("Dancers in a Ring of Flowers", dict(time="golden", season="spring", features=["dancers"], fire_y=0.74, dancers_n=8, flowers=1.2, fx=["petals"])),
    ("Spring Rain over the Orchards", dict(time="overcast", season="spring", trees=["blossom"], mid_n=26, fx=["mist"])),
    ("A Summer Evening, Fireflies", dict(time="twilight", season="summer", trees=["round"], fx=["fireflies"], flowers=0.5)),
    ("The Gazebo by the Water", dict(time="morning", season="summer", water="lake", features=["tower"], tower_x=0.3, roof="#f3a8c0")),
    ("Faelights in the Garden", dict(time="twilight", season="spring", features=["manor"], manor_w=0.3, manor_x=0.7, fx=["faelights"], trees=["blossom"])),
    ("Hares in the Meadow", dict(time="morning", season="spring", flowers=1.0, mid_trees=True)),
    ("An Old Bridge in Autumn", dict(time="dusk", season="autumn", water="river", features=["bridge"], trees=["willow"])),
    ("Wisteria Walk", dict(time="golden", season="spring", trees=["willow"], near_trees=[(0.08, "willow"), (0.92, "willow")], flowers=0.6, flower_cols=["#b8a8f2", "#c8b6f2"])),
    ("Blue Hour on the Water", dict(time="twilight", season="spring", water="lake", trees=["willow"], fx=["wisps"])),
]
for i, (title, prm) in enumerate(PASTORALS):
    prm.setdefault("far", "hills" if i % 3 else "mountains")
    w("pastoral_%02d" % (i + 1), title, "landscape", "land" if i % 4 else "oval_l", ["gallery", "hall", "bedroom", "music"], "C",
      "Ch19: the gallery holds pastorals (no named works). Subject invented [X].", major=i < 10, eye="human" if i % 2 else "fae", age=0.15 * (i % 3), **prm)

# =================================================================== still lifes

STILLS = [
    ("Peonies and a Gilt Urn", dict(ground="plum", vessel="gilt_urn", flowers=["peony", "rose"], table="marble", objects=[("pearls", 0.78)])),
    ("Tulips in a Crystal Vase", dict(ground="pearl", vessel="crystal", flowers=["tulip"], table="white_cloth", objects=[("lemon", 0.2)])),
    ("Irises with Pears", dict(ground="umber", vessel="blue_jug", flowers=["iris"], table="oak", objects=[("pear", 0.22), ("pear", 0.8, 0.02)])),
    ("Morning Glory and Teacups", dict(ground="blush", vessel="porcelain", flowers=["morning_glory", "sweet_pea"], table="rose_cloth", objects=[("teacups", 0.78)])),
    ("Lilac in a Porcelain Vase", dict(ground="lilac", vessel="porcelain", flowers=["lilac"], table="lilac_cloth", objects=[("book", 0.22)])),
    ("Snowdrops and Crocus", dict(ground="mint", vessel="silver_bowl", flowers=["snowdrop", "crocus"], table="marble", vase_h=0.2, bouquet_r=0.18)),
    ("Daffodils by a Window", dict(ground="window", vessel="stone_crock", flowers=["daffodil"], table="ledge")),
    ("Roses and Faerie Wine", dict(ground="dark", vessel="crystal", flowers=["rose"], table="marble", objects=[("wine", 0.78), ("grapes", 0.2)])),
    ("Chocolate Torte and Roses", dict(ground="plum", vessel="rose_ewer", flowers=["rose", "sweet_pea"], table="white_cloth", objects=[("torte", 0.22), ("wine", 0.8)])),
    ("Lemon Tart and Lilies", dict(ground="pearl", vessel="crystal", flowers=["lily"], table="white_cloth", objects=[("tart", 0.25), ("lemon", 0.78)])),
    ("Apples, a Lemon and a Chocolate Cookie", dict(ground="umber", vessel="basket", flowers=[], table="oak", objects=[("apple", 0.4), ("green_apple", 0.55, 0.01), ("lemon", 0.68)])),
    ("Bread, Cheese and Honey", dict(ground="umber", vessel="stone_crock", flowers=["daisy"] if False else ["goldenrod"], table="oak", objects=[("bread", 0.22), ("cheese", 0.78), ("honey", 0.62)])),
    ("Masks on a Marble Table", dict(ground="dark", vessel="gilt_urn", flowers=["rose"], table="marble", objects=[("mask_leaf", 0.25), ("mask_gold", 0.76), ("candle", 0.9)])),
    ("A Fox Mask and Autumn Leaves", dict(ground="umber", vessel="copper_pot", flowers=["ranunculus"], table="oak", objects=[("mask_fox", 0.24), ("plum", 0.78)])),
    ("Spoils of the Hunt", dict(ground="dark", vessel="stone_crock", flowers=["foxglove"], table="ledge", objects=[("game_birds", 0.28), ("red_wine", 0.82)])),
    ("Hourglass and Candle", dict(ground="dark", vessel="crystal", flowers=["hellebore"], table="oak", objects=[("hourglass", 0.24), ("candle", 0.78), ("book", 0.62)])),
    ("Camellias and Pearls", dict(ground="blush", vessel="porcelain", flowers=["camellia"], table="marble", objects=[("pearls", 0.25), ("shell", 0.8)])),
    ("Pomegranates and Anemones", dict(ground="plum", vessel="gilt_urn", flowers=["anemone"], table="marble", objects=[("pomegranate", 0.22), ("fig", 0.78)])),
    ("Wisteria and Cherries", dict(ground="lilac", vessel="crystal", flowers=["wisteria"], table="lilac_cloth", objects=[("cherries", 0.78)])),
    ("Foxglove and a Quill", dict(ground="mint", vessel="blue_jug", flowers=["foxglove", "bluebell"], table="mint_cloth", objects=[("quill", 0.22), ("book", 0.75)])),
    ("Bluebells in a Stone Crock", dict(ground="pearl", vessel="stone_crock", flowers=["bluebell"], table="oak", objects=[("green_apple", 0.78)])),
    ("Poppies and Oranges", dict(ground="umber", vessel="copper_pot", flowers=["poppy"], table="rose_cloth", objects=[("orange", 0.22), ("orange", 0.8)])),
    ("Hellebores at Midwinter", dict(ground="plum", vessel="silver_bowl", flowers=["hellebore", "snowdrop"], table="marble", objects=[("candle", 0.8)])),
    ("Sweet Peas and a Butterfly", dict(ground="blush", vessel="crystal", flowers=["sweet_pea"], table="rose_cloth", butterfly=(0.72, 0.3, 0.035, "#c8b6f2"))),
    ("Ranunculus and Peaches", dict(ground="pearl", vessel="porcelain", flowers=["ranunculus"], table="white_cloth", objects=[("peach", 0.22), ("peach", 0.78)])),
    ("Roses for the Dining Hall", dict(ground="dark", vessel="gilt_urn", flowers=["rose", "peony", "lily"], table="marble", objects=[("grapes", 0.18), ("apple", 0.85)], blooms=34)),
    ("A Bowl of Plums", dict(ground="umber", vessel="silver_bowl", flowers=[], table="oak", objects=[("plum", 0.35), ("plum", 0.42, 0.02), ("plum", 0.6)])),
    ("Lilies of the Shrine", dict(ground="dark", vessel="crystal", flowers=["lily", "maiden_lace"], table="marble", objects=[("candle", 0.22), ("candle", 0.8)])),
    ("Shells from the Summer Coast", dict(ground="mint", vessel="silver_bowl", flowers=[], table="white_cloth", objects=[("shell", 0.3), ("shell", 0.55, 0.02), ("pearls", 0.75)])),
    ("Mixed Bouquet with a Lilac Mask", dict(ground="lilac", vessel="rose_ewer", flowers=["tulip", "rose", "lilac", "daffodil"], table="lilac_cloth", objects=[("mask_lilac", 0.78)])),
]
STILL_ROOMS = [["gallery", "dining", "hall"], ["gallery", "bedroom"], ["gallery", "dining", "kitchen"]]
for i, (title, prm) in enumerate(STILLS):
    rooms = ["gallery", "dining", "hall"] if i % 3 == 0 else (["gallery", "bedroom", "hall"] if i % 3 == 1 else ["gallery", "dining", "service", "hall"])
    if "Masks" in title or "Mask" in title:
        rooms = ["mask", "gallery", "hall"]
    if "Hunt" in title:
        rooms = ["study", "dining", "store"]
    if "Hourglass" in title:
        rooms = ["library", "store"]
    if "Shrine" in title:
        rooms = ["shrine", "gallery"]
    if "Bread" in title or "Plums" in title or "Apples" in title:
        rooms = ["service", "dining", "kitchen"]
    fmt = ["port", "port", "square", "oval_p", "port", "arch_p"][i % 6]
    w("still_%02d" % (i + 1), title, "still", fmt, rooms, "C" if rooms[0] == "gallery" else "X",
      "Ch19: the gallery holds still lifes; the canon dinner and night snack foods (ch7) and the court's masks recur. Subject invented [X].",
      eye="human" if i % 2 else "fae", age=0.12 * (i % 4), **prm)

# =================================================================== portraits

PORTRAITS = [
    # title, rooms, sitter, back, masked? (after the curse)
    ("A Lady of the Spring Court, Masked", ["portrait", "gallery", "mask"], sitter("elain", "bust", turn=-14, hair_col=H_HONEY, garment=MINT, mask="tamlin", mask_col=[0.95, 0.75, 0.4], hide=["elain_garden_hat"], light="soft"), "roses"),
    ("A Courtier in a Fox Mask", ["portrait", "mask", "hall"], sitter("tamlin", "bust", turn=14, mask="lucien", hair="lucien", hair_col=H_COPPER, garment=RUSSET, hide=["tamlin_baldric"], light="rembrandt"), "umber"),
    ("Lady with a Lamb", ["portrait", "gallery", "nursery"], sitter("elain", "half", turn=8, hair_col=H_GOLD, garment=BLUSH, hide=["elain_garden_hat"], light="soft"), "garden"),
    ("The Lady in Lilac", ["portrait", "gallery", "bedroom"], sitter("nesta", "bust", turn=-10, hair_col=H_CHESTNUT, garment=LILAC, hide=["nesta_cloak"], light="soft"), "lilac"),
    ("A Lord in Emerald", ["portrait", "gallery", "hall"], sitter("lucien", "bust", turn=-12, mask="none", hide=["EyeOrb"], hair="tamlin", hair_col=H_CHESTNUT, garment=EMERALD, light="rembrandt"), "drape"),
    ("A Huntress of the Court", ["portrait", "study", "hall"], sitter("nesta", "bust", turn=16, hair="alis", hair_col=H_AUBURN, garment=[0.45, 0.55, 0.42], hide=["nesta_cloak"], light="rim"), "column"),
    ("A Winter Lady in Pearl", ["portrait", "gallery"], sitter("nesta", "bust", turn=-6, hair="elain", hair_col=H_SILVER, garment=PEARL, trim=SKY, skin=SK_PEARL, hide=["nesta_cloak"], light="moon"), "night"),
    ("A Lady of the Dawn Court", ["portrait", "gallery"], sitter("elain", "bust", turn=10, hair="nesta", hair_col=H_ROSE, garment=[0.98, 0.72, 0.66], trim=GOLDC, hide=["elain_garden_hat"], light="soft"), "sky"),
    ("A Day Court Scholar", ["portrait", "library"], sitter("lucien", "bust", turn=14, mask="none", hide=["EyeOrb"], hair="tamlin", hair_col=H_BLACK, skin=SK_UMBER, garment=GOLDC, light="soft"), "column"),
    ("A Masked Musician", ["portrait", "music", "mask"], sitter("lucien", "bust", turn=-16, mask="tamlin", mask_col=[0.75, 0.6, 0.9], hair_col=H_GOLD, garment=PERI, hide=["EyeOrb"], light="soft"), "drape"),
    ("The Rose Maiden", ["portrait", "gallery", "bedroom"], sitter("elain", "bust", turn=-6, hair_col=H_COPPER, garment=ROSE, hide=["elain_garden_hat"], light="soft"), "roses"),
    ("A Sentry of Spring, Masked", ["portrait", "hall", "study"], sitter("tamlin", "bust", turn=-10, mask="keep", mask_col=[0.7, 0.72, 0.8], hair_col=H_BLACK, skin=SK_BRONZE, garment=[0.35, 0.45, 0.4], light="rembrandt"), "storm"),
    ("A Lady of the Autumn Court", ["portrait", "autumn", "gallery"], sitter("nesta", "bust", turn=12, hair="lucien", hair_col=H_AUBURN, garment=[0.85, 0.5, 0.3], trim=GOLDC, hide=["nesta_cloak"], light="rembrandt"), "umber"),
    ("A Young Lord with a Book", ["portrait", "library", "gallery"], sitter("lucien", "half", turn=10, mask="none", hide=["EyeOrb"], hair_col=H_CHESTNUT, garment=SKY, light="soft"), "column"),
    ("The Lady of the Glass Houses", ["portrait", "gallery", "bedroom"], sitter("alis", "bust", turn=-12, mask="none", hair="elain", hair_col=H_HONEY, skin=SK_GOLD, garment=MINT, hide=["alis_apron"], light="soft"), "garden"),
    ("A Housekeeper of Long Ago", ["service", "portrait"], sitter("alis", "bust", turn=10, mask="none", hair_col=H_CHESTNUT, skin=SK_BARK, garment=[0.6, 0.5, 0.55], light="rembrandt"), "umber"),
    ("A Masked Lady in Butter-Yellow", ["portrait", "mask", "gallery"], sitter("nesta", "bust", turn=8, mask="alis", mask_col=GOLDC, hair_col=H_GOLD, garment=BUTTER, hide=["nesta_cloak"], light="soft"), "rose"),
    ("A Lord in Plum Velvet", ["portrait", "portrait_dim", "store"], sitter("tamlin", "bust", turn=-14, mask="none", hair="lucien", hair_col=H_BLACK, garment=PLUM, hide=["tamlin_baldric"], light="candle"), "plum"),
    ("Lady with a Fan", ["portrait", "gallery", "music"], sitter("elain", "half", turn=-10, hair="nesta", hair_col=H_BLACK, skin=SK_BRONZE, garment=RUBY, hide=["elain_garden_hat"], light="rembrandt"), "drape"),
    ("A Masked Gardener", ["service", "portrait"], sitter("alis", "bust", turn=-8, mask="keep", hair_col=H_HONEY, skin=SK_BARK, garment=MINT, light="soft"), "garden"),
    ("A Young Lady in Periwinkle", ["portrait", "bedroom", "gallery"], sitter("elain", "bust", turn=14, hair_col=H_CHESTNUT, skin=SK_UMBER, garment=PERI, hide=["elain_garden_hat"], light="soft"), "pearl"),
    ("A Lord of Summer at Ease", ["portrait", "gallery"], sitter("lucien", "bust", turn=-10, mask="none", hide=["EyeOrb"], hair="nesta", hair_col=H_BLACK, skin=SK_UMBER, garment=[0.4, 0.75, 0.75], light="soft"), "sky"),
    ("A Masked Lady in Silver", ["portrait", "mask", "hall"], sitter("nesta", "bust", turn=-14, mask="lucien", mask_col=SILVER, hair_col=H_SILVER, garment=SILVER, hide=["nesta_cloak"], light="moon"), "night"),
    ("The Embroideress", ["portrait", "service", "bedroom"], sitter("alis", "half", turn=8, mask="none", hair="nesta", hair_col=H_CHESTNUT, skin=SK_GOLD, garment=LILAC, hide=["alis_apron"], light="soft"), "pearl"),
    ("A Captain of the Guard", ["portrait", "study", "store"], sitter("tamlin", "half", turn=12, mask="none", hair_col=H_AUBURN, garment=[0.55, 0.3, 0.3], light="rembrandt"), "storm"),
    ("A Lady in a Flower Crown", ["portrait", "gallery", "bedroom", "nursery"], sitter("elain", "bust", turn=4, hair_col=H_GOLD, garment=BUTTER, light="soft"), "roses"),
    ("A Lady of the Court, Unmasked", ["portrait", "gallery"], sitter("nesta", "bust", turn=10, hair="elain", hair_col=H_ROSE, garment=[0.9, 0.85, 0.96], hide=["nesta_cloak"], light="soft"), "mint"),
    ("A Masked Lord in Gold", ["portrait", "mask", "hall"], sitter("lucien", "bust", turn=8, mask="tamlin", mask_col=GOLDC, hair="tamlin", hair_col=H_HONEY, garment=IVORY, hide=["EyeOrb"], light="rim"), "drape"),
    ("An Old Lord of Spring", ["portrait_dim", "store", "portrait"], sitter("tamlin", "bust", turn=-6, mask="none", hair="alis", hair_col=H_WHITE, garment=[0.4, 0.5, 0.42], light="candle"), "umber"),
    ("A Lady of the Night Sky", ["portrait", "night"], sitter("nesta", "bust", turn=12, hair_col=H_BLACK, garment=[0.3, 0.3, 0.55], trim=SILVER, hide=["nesta_cloak"], light="moon"), "night"),
    ("A Masked Lady in Rose", ["portrait", "mask", "bedroom"], sitter("elain", "bust", turn=-10, mask="lucien", mask_col=ROSE, hair_col=H_GOLD, garment=ROSE, hide=["elain_garden_hat"], light="soft"), "rose"),
    ("A Herald in Mint and Gold", ["portrait", "hall"], sitter("lucien", "half", turn=-12, mask="keep", mask_col=GOLDC, hair_col=H_GOLD, garment=MINT, hide=["EyeOrb"], light="soft"), "column"),
]
for i, (title, rooms, sit, back) in enumerate(PORTRAITS):
    masked = sit.get("mask") not in ("none",) and not (sit["model"] in ("elain", "nesta") and sit.get("mask") is None)
    note = ("After the curse: masked (ch7, ch32)." if masked else "Before the curse: unmasked (keeper, ch32).")
    fmt = ["port", "oval_p", "port", "arch_p"][i % 4]
    w("portrait_%02d" % (i + 1), title, "portrait", fmt, rooms, "C" if "gallery" in rooms else "X",
      "Ch19: the gallery holds portraits. Sitter invented [X]. " + note, back=back, sitter=sit, age=0.2 if not masked else 0.05,
      eye="human" if i % 3 == 0 else "fae")

# Full-length portraits (portrait_masked hung at scale ~1.5 in the long gallery).
FULLS = [
    ("The High Lady in the Rose Garden", sitter("nesta", "full", turn=-15, hair="elain", hair_col=H_GOLD, garment=ROSE, hide=["nesta_cloak"], light="soft"), "garden", "Tamlin's mother, before the curse [X]; companion to the rose-garden painting."),
    ("A Lady in Mint Silk", sitter("elain", "full", turn=12, hair_col=H_HONEY, garment=MINT, hide=["elain_garden_hat"], light="soft"), "garden", "Ch19: the gallery holds portraits of the court; a lady of Spring before the curse. Sitter invented [X]."),
    ("A Lord of Spring in Hunting Dress", sitter("tamlin", "full", turn=-12, mask="none", hair_col=H_CHESTNUT, garment=[0.4, 0.55, 0.45], light="rembrandt"), "column", "Ch19: gallery portraits. Before the curse: an unmasked lord dressed for the hunt. Sitter invented [X]."),
    ("A Masked Lady at the Ball", sitter("nesta", "full", turn=10, mask="tamlin", mask_col=GOLDC, hair_col=H_BLACK, garment=LILAC, hide=["nesta_cloak"], light="rim"), "drape", "Ch19: gallery portraits. After the curse: a lady masked like the rest of the court. Sitter invented [X]."),
    ("A Lady in Butter Silk", sitter("alis", "full", turn=-8, mask="none", hair="nesta", hair_col=H_COPPER, skin=SK_GOLD, garment=BUTTER, hide=["alis_apron"], light="soft"), "garden", "Ch19: the gallery holds portraits of the court; a lady in spring silks, unmasked. Sitter invented [X]."),
    ("A Masked Lord in Blue", sitter("lucien", "full", turn=14, mask="keep", mask_col=SILVER, hair_col=H_BLACK, garment=PERI, hide=["EyeOrb"], light="soft"), "column", "Ch19: gallery portraits. After the curse: a lord masked like the rest of the court. Sitter invented [X]."),
]
for i, (title, sit, back, ref) in enumerate(FULLS):
    w("full_%02d" % (i + 1), title, "portrait", "port", ["portrait_full", "portrait", "gallery"], "X", ref, major=True, back=back, sitter=sit, age=0.1 * (i % 3))

# Pairs
w("pair_mated", "A Mated Pair of the Spring Court", "portrait", "land", ["gallery", "portrait"], "X",
  "Mating bonds are canon (ch19: Tamlin's parents were mated). Sitters invented, before the curse.",
  back="garden", pair=[sitter("lucien", "bust", turn=16, mask="none", hide=["EyeOrb"], hair="tamlin", hair_col=H_CHESTNUT, garment=SKY, light="soft"),
                       sitter("elain", "bust", turn=-16, hair_col=H_GOLD, garment=BLUSH, hide=["elain_garden_hat"], light="soft")])
w("pair_sisters", "Two Sisters of the Dawn Court", "portrait", "land", ["gallery", "bedroom"], "X", "Ch19: the gallery holds portraits; two sisters visiting from the Dawn Court, one of Prythian's seven courts. Sitters invented [X].",
  back="sky", pair=[sitter("nesta", "bust", turn=16, hair_col=H_ROSE, garment=BUTTER, hide=["nesta_cloak"], light="soft"),
                    sitter("elain", "bust", turn=-16, hair="nesta", hair_col=H_ROSE, garment=[0.98, 0.72, 0.66], hide=["elain_garden_hat"], light="soft")])

# =================================================================== animals (Blender tableaux over painted land)

def tab(items, cam_at, look, lens=45, light="soft", sun=(-0.5, 0.5, -0.6)):
    return dict(items=[dict(src=s, at=a, yaw=y, **({"tint": t} if t else {})) for s, a, y, t in items], cam=dict(at=cam_at, look=look, lens=lens), light=light, sun=list(sun))


S = "creatures/models/spring/"
P = "creatures/models/people/"
ANIMALS = [
    ("Swans on the Mirror Lakes", ["gallery", "bedroom", "hall"], dict(time="golden", season="summer", water="lake", near_top=0.88), tab([(S + "swan.gltf", [0, 0, 0], 150, None), (S + "swan.gltf", [1.4, 1.6, 0], 220, None)], [0.5, -5, 1.0], [0.4, 0.5, 0.3])),
    ("A Fox among Bluebells", ["study", "gallery", "autumn"], dict(time="morning", season="spring", flower_cols=["#8aa0f0", "#a8b8f8"], flowers=1.4), tab([(S + "fox.gltf", [0, 0, 0], 230, None)], [0.5, -3, 0.6], [0, 0, 0.3], 50)),
    ("Hares at Twilight", ["nursery", "gallery", "bedroom"], dict(time="twilight", season="spring", flowers=0.8), tab([("creatures/models/hare.gltf", [0, 0, 0], 140, None), ("creatures/models/hare.gltf", [0.9, 1.0, 0], 150, None)], [0.4, -3.6, 0.7], [0.3, 0.4, 0.2], 45)),
    ("A Stag in the Estate Woods", ["study", "hall", "gallery"], dict(time="dawn", season="spring", trees=["round", "birch"], mid_n=24, fx=["mist", "rays"]), tab([("creatures/models/deer.gltf", [0, 0, 0], 235, None)], [1.0, -5.4, 1.2], [0, 0, 0.9], 45)),
    ("Songbirds in the Blossom", ["bedroom", "nursery", "music"], dict(time="morning", season="spring", trees=["blossom"], near_trees=[(0.2, "blossom"), (0.8, "blossom")], near_tree_h=0.9), tab([(S + "songbird_blue.gltf", [0, 0, 0.4], 250, None), (S + "songbird_rose.gltf", [0.5, 0.3, 0.55], 160, None), (S + "songbird_gold.gltf", [-0.45, 0.2, 0.3], 230, None)], [0.1, -2.2, 0.55], [0.0, 0.2, 0.45], 50, ground=False) if False else tab([(S + "songbird_blue.gltf", [0, 0, 0], 250, None), (S + "songbird_rose.gltf", [0.5, 0.3, 0], 160, None), (S + "songbird_gold.gltf", [-0.45, 0.2, 0], 230, None)], [0.1, -2.0, 0.35], [0.0, 0.2, 0.1], 50)),
    ("The Owl of the Old Tower", ["night", "library", "store"], dict(time="night", season="autumn", trees=["round"], fx=["faelights"]), tab([(S + "owl.gltf", [0, 0, 0], 240, None)], [0.2, -2.2, 0.5], [0, 0, 0.3], 55, "moon")),
    ("Butterflies of the Rosewild", ["bedroom", "nursery", "gallery"], dict(time="noon", season="summer", flower_cols=["#e8708f", "#f39cb8", "#fde2ea"], flowers=1.4, fx=["butterflies"]), tab([(S + "butterfly.gltf", [0, 0, 0.6], 235, None), (S + "butterfly.gltf", [0.6, 0.4, 0.9], 140, None), (S + "butterfly.gltf", [-0.7, 0.3, 0.8], 250, None)], [0, -2.6, 0.8], [0, 0.2, 0.75], 50)),
    ("A Hawk on the March", ["study", "hall"], dict(time="overcast", season="autumn", far="mountains", mid_trees=False), tab([(S + "hawk.gltf", [0, 0, 0], 110, None)], [0.3, -2.4, 0.6], [0, 0, 0.35], 55, "rembrandt")),
    ("The Cat in the Kitchen Garden", ["service", "kitchen"], dict(time="golden", season="summer", flowers=0.9), tab([(S + "cat.gltf", [0, 0, 0], 250, None)], [0.3, -2.0, 0.5], [0, 0, 0.2], 50)),
    ("Hens in the Yard", ["service", "kitchen"], dict(time="morning", season="spring", features=["cottage"], cottage_x=0.8, flowers=0.4), tab([(S + "hen.gltf", [0, 0, 0], 250, None), (S + "hen.gltf", [0.8, 0.8, 0], 140, None), (S + "hen.gltf", [-0.7, 0.6, 0], 250, None)], [0.3, -3.0, 0.7], [0, 0.4, 0.2], 45)),
    ("Squirrels in the Old Oak", ["nursery", "bedroom", "service"], dict(time="golden", season="autumn", trees=["round"], near_trees=[(0.5, "round")], near_tree_h=1.1), tab([(S + "squirrel.gltf", [0, 0, 0], 235, None), (S + "squirrel.gltf", [0.6, 0.4, 0], 160, None)], [0.2, -2.0, 0.4], [0.2, 0.2, 0.15], 50)),
    ("Larks over the Downs", ["music", "bedroom"], dict(time="dawn", season="spring", flowers=1.0, mid_trees=False), tab([(S + "lark.gltf", [0, 0, 0], 250, None)], [0.2, -1.8, 0.4], [0, 0, 0.15], 55)),
    ("Crows on the Wall Road", ["store", "study"], dict(time="overcast", season="winter", far="mountains", features=["wall"], flowers=0.0, trees=["conifer"]), tab([(S + "crow.gltf", [0, 0, 0], 250, None), (S + "crow.gltf", [0.9, 0.6, 0], 140, None)], [0.3, -2.6, 0.6], [0.3, 0.3, 0.2], 50, "rim")),
    ("A Rabbit by the Hedge", ["nursery", "service", "bedroom"], dict(time="morning", season="spring", flowers=0.9, trees=["round"]), tab([(S + "rabbit.gltf", [0, 0, 0], 235, None)], [0.2, -1.6, 0.35], [0, 0, 0.15], 55)),
    ("A Water Sprite at the Pool", ["bedroom", "gallery"], dict(time="twilight", season="summer", water="lake", near_top=0.86, fx=["wisps"]), tab([(S + "water_sprite.gltf", [0, 0, 0], 235, None)], [0.2, -2.4, 0.6], [0, 0, 0.4], 50, "moon")),
    ("Faelights over the Pond", ["night", "bedroom"], dict(time="night", season="summer", water="lake", fx=["faelights", "fireflies"]), tab([(S + "faelight.gltf", [0, 0, 0.8], 235, None), (S + "faelight.gltf", [0.8, 0.6, 1.1], 235, None), (S + "faelight.gltf", [-0.7, 0.4, 1.3], 235, None)], [0, -3.0, 1.0], [0, 0.3, 1.0], 45, "moon")),
]
for i, (title, rooms, land, tb) in enumerate(ANIMALS):
    land.setdefault("far", "hills")
    w("animal_%02d" % (i + 1), title, "animal", "land" if i % 3 else "oval_l", rooms, "X",
      "The court's creatures as the game's world has them (creatures/models). Subject invented [X].", tableau=tb, eye="human" if i % 2 else "fae", **land)

FAE_FOLK = [
    ("A Pixie in the Rose Bed", "fae_pixie", "The unseen shimmering things in the garden (ch8), seen as they are after the glamour lifts (ch23-24)."),
    ("The Moth Folk at Dusk", "fae_moth", "Lesser faeries of the court (lesser-fae-and-ambient)."),
    ("An Owl-Faerie of the Library", "fae_owl", "Lesser faeries of the court (ch8), here a wise one among the books."),
    ("The Stag-Crowned Fae", "fae_stag", "Lesser faeries of the court; Spring's stags."),
    ("A Satyr Piping", "fae_satyr", "Calanmai revellers are lesser faeries (ch21)."),
    ("A Rose Dryad", "fae_rose", "Lesser faeries of the court (ch8), a spirit of the manor's roses."),
    ("A Birch Dryad", "fae_birch", "The western birch woods (ch13), where Feyre goes to catch the Suriel."),
    ("The Hedgehog Folk", "fae_hedgehog", "Lesser faeries of the court (ch8), small folk of the hedgerows."),
    ("A Mushroom Faerie", "fae_mushroom", "Lesser faeries of the court (ch8), a sprite of the woodland floor."),
    ("A Nymph of the Pools", "fae_nymph", "Lesser faeries of the court; water sprites [X]."),
    ("Revellers of Calanmai", "reveler_1", "Calanmai revellers (ch20-21), dancing toward the bonfires on the night of the Rite."),
    ("A Fox-Folk Wanderer", "fae_fox", "Lesser faeries of the court (ch8); the fox recalls Lucien's mask."),
]
for i, (title, model, ref) in enumerate(FAE_FOLK):
    items = [(P + model + ".gltf", [0, 0, 0], 195, None)]
    if model == "reveler_1":
        items = [(P + "reveler_1.gltf", [-0.7, 0, 0], 170, None), (P + "reveler_2.gltf", [0.4, 0.4, 0], 220, None), (P + "reveler_3.gltf", [1.3, -0.2, 0], 200, None)]
    w("fae_folk_%02d" % (i + 1), title, "animal", ["port", "oval_p", "square"][i % 3], ["gallery", "bedroom", "nursery", "hall"] if i % 2 else ["gallery", "library", "music"], "C",
      ref + " Figure invented [X].", time=["golden", "twilight", "morning", "dusk"][i % 4], season="spring", far="hills", flowers=0.9,
      trees=["blossom", "round"] if i % 2 else ["birch"], fx=["faelights"] if i % 2 else ["petals"],
      tableau=tab(items, [0.3, -4.2, 1.0], [0, 0, 0.9], 50, "soft" if i % 2 else "rim"))

# =================================================================== interiors and festivals

w("masquerade_old", "A Spring Masquerade, Long Ago", "interior", "land", ["mask", "ballroom", "store"], "X",
  "Before the curse the court wore masks only for a night (ch32). Not Amarantha's masquerade.", major=True, age=0.3, masked=True, dancers=16, petals=True)
w("ballroom_spring", "The Ballroom in Spring", "interior", "land", ["ballroom", "music", "gallery"], "X",
  "The manor's ballroom in happier days, before the curse and the blight.", masked=False, dancers=14, wall="#e8f2ea", floor="#f2e8dc")
w("music_salon", "An Evening of Music", "interior", "land", ["music", "bedroom"], "X", "Music in the house [X]: the masked court gathered for an evening's playing.", masked=True, dancers=7, wall="#e8e0f6")
w("tea_in_conservatory", "Tea in the Conservatory", "interior", "land", ["dining", "bedroom", "service"], "X", "A quiet afternoon [X]: masked courtiers taking tea among the conservatory's plants.", masked=True, dancers=5, wall="#e0f2e8", floor="#f6efe6")

# =================================================================== plates (library, stillroom)

PLATES = [
    ("suriel", "The Suriel, a Plate", "C", "Ch13-14: tall and corpse-like, veiled tattered robe, lipless mouth, long teeth, milky eyes; caught near young birches and running water."),
    ("naga", "Naga, a Plate", "C", "Ch15: serpentine males with dark scales, amber almond eyes, silvery forked tongues, black talons."),
    ("bogge", "The Bogge: What Is Not to Be Looked At", "C", "Ch9-10: invisible; it becomes real only if you acknowledge it. The plate shows only a darkness."),
    ("puca", "The Puca, and What It Wears", "C", "Ch10-11: it lures with your own desire; no true form is described. Its shadow is wrong."),
    ("faerie", "Lesser Faerie of the Garden", "C", "Ch8: shimmering unseen things in the garden."),
    ("lamb", "The Spring Lamb", "X", "Spring's emblem, as on the mural of Prythian (ch13)."),
    ("stag", "The Stag of the Estate Woods", "X", "The game of the estate woods, where Tamlin and Lucien hunt."),
    ("fox", "The Red Fox", "X", "Lucien's fox mask echoes it; the fox of the court's woods."),
    ("hare", "The Brown Hare", "X", "The quarry of Feyre's snares, set as she did at home (ch19)."),
    ("swan", "The Mute Swan", "X", "The swans of the court's lakes and still pools."),
    ("butterflies", "Butterflies of the Court", "X", "The butterflies of the manor's gardens, always in spring."),
]
for i, (cr, title, canon, ref) in enumerate(PLATES):
    rooms = ["library", "study", "store"] if canon == "C" else ["library", "nursery", "service", "bedroom"]
    w("plate_%s" % cr, title, "plate", "port", rooms, canon, ref + " Bestiary plate [X].", creature=cr, age=0.35 + 0.05 * (i % 3), eye="human",
      **({"wing": ["#c8d8f8", "#f8d0e8"][i % 2]} if cr == "faerie" else {}))

BOTANICALS = [
    ("rose_red", "Red Rose", ("rose", ["#d0485e", "#e8708f"]), "C"), ("rose_white", "White Rose", ("rose", ["#fbf7f0", "#f4efe6"]), "C"),
    ("wild_hyacinth", "Wild Hyacinth", ("plume", ["#8aa0f0", "#a8b8f8"]), "C"), ("foxglove", "Foxglove", ("plume", ["#e888b8", "#f0a8c8"]), "C"),
    ("lavender", "Lavender", ("plume", ["#a890d8", "#c0a8e8"]), "X"), ("honeysuckle", "Honeysuckle", ("tulip", ["#fff1a8", "#f8c8a0"]), "X"),
    ("elderflower", "Elderflower", ("maiden_lace", ["#fbf7f0"]), "X"), ("wild_strawberry", "Wild Strawberry", ("daisy", ["#fbfbff"]), "X"),
    ("moonflower", "Moonflower", ("morning_glory", ["#f6f2ff", "#e8e8ff"]), "X"), ("faelight_dandelion", "Faelight Dandelion", ("daisy", ["#fff2a0"]), "X"),
    ("woad", "Woad", ("plume", ["#ffe070"]), "X"), ("madder", "Madder Root", ("daisy", ["#fff6c8"]), "X"),
    ("snowdrop", "Snowdrop", ("tulip", ["#fbfbff"]), "X"), ("wisteria", "Wisteria", ("plume", ["#b8a8f2", "#c8b6f2"]), "C"),
    ("lilac", "Lilac", ("plume", ["#c8a8e8", "#d8c0f0"]), "C"), ("crab_apple", "Crab Apple", ("daisy", ["#fde2ea", "#f7c6d6"]), "C"),
    ("buttercup", "Meadow Buttercup", ("daisy", ["#ffe060"]), "C"), ("iris", "Amethyst Iris", ("iris", ["#9a7ae0", "#b8a8f2"]), "C"),
    ("crocus", "Crocus", ("tulip", ["#b8a0f0", "#d8c8ff"]), "C"), ("daffodil", "Daffodil", ("daisy", ["#ffe070", "#fff1a8"]), "C"),
    ("peony", "Peony", ("peony", ["#f7a8c0", "#fbd0dc"]), "C"), ("tulip", "Tulip", ("tulip", ["#f26f86", "#ffd36a"]), "C"),
    ("morning_glory", "Morning Glory", ("morning_glory", ["#8fa0f0", "#b8a8f2"]), "C"), ("goldenrod", "Goldenrod", ("plume", ["#f6c84a"]), "C"),
    ("maidens_lace", "Maiden's Lace", ("maiden_lace", ["#fbf7f0"]), "C"), ("blackberry", "Blackberry", ("daisy", ["#fbfbff"]), "X"),
]
for i, (pid, title, bloom, canon) in enumerate(BOTANICALS):
    extra = {}
    if pid in ("wild_strawberry",):
        extra["berries"] = "#e8506a"
    if pid == "blackberry":
        extra["berries"] = "#3a2440"
    rooms = ["stillroom", "library", "bedroom", "service"] if i % 2 else ["stillroom", "service", "nursery", "library"]
    w("botanical_%s" % pid, "%s, a Botanical Plate" % title, "botanical", "port", rooms, canon,
      "A forage ingredient of the game (lore/05-foraging-chemistry/ingredients.md: ing_%s). Plate [X]." % pid, bloom=bloom, age=0.2 + 0.1 * (i % 3), eye="human", **extra)


# Held back from hanging (still listed, never hung) until they reach the bar
# (quality audit A5: a subject a player can name): bird and small-creature
# studies whose models read as blobs, the crudest plates, near-empty still
# lifes, and the painted interiors.
RESERVE = {
    "animal_05", "animal_06", "animal_07", "animal_08", "animal_10", "animal_12", "animal_13", "animal_14", "animal_15",
    "plate_hare", "plate_puca", "plate_fox", "plate_stag", "plate_lamb", "still_11", "still_27", "still_29",
    "portrait_08", "fae_folk_01", "fae_folk_02", "masquerade_old", "ballroom_spring", "music_salon", "tea_in_conservatory",
}
for _e in WORKS:
    _e["reserve"] = _e["id"] in RESERVE
assert RESERVE <= {_e["id"] for _e in WORKS}
