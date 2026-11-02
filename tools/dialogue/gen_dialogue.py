#!/usr/bin/env python3
"""Writes the free-roam dialogue (lane L34) from the tables below:

  data/dialogue/lines/<area>.tres   DialogueBook per area (lines + places)
  data/dialogue/presence.tres       PresenceRoster: who stands where, when
  data/dialogue/sheet/line_sheet.csv  one row per line for the voice tool

Run from the repo root:  python3 tools/dialogue/gen_dialogue.py
Canon tags: V verbatim (book), A adapted, X invented in the book's voice.
Lines are flavour over play (plan §12): no choices, no objective text, and a
line never sets a story flag (R2). Flags read here are the deed flags of
lore/07-story/timeline-overview.md and the story lane's fact.* ActionTriggers.
"""
import csv
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "dialogue")

P = ["p0_winter", "p1_wolf_and_crossing", "p2_grounds", "p3_house_and_woods", "p4_wider_court",
     "p5_calanmai", "p6_blight_tightens", "p7_return_home", "p8_the_pass"]


def ph(a, b=None):
    """Phases a..b inclusive, by number."""
    return P[a:(a if b is None else b) + 1]


HUMAN = ph(0, 1)          # winter, until she's taken
COURT = ph(2, 6)          # her months at the manor
WIDER = ph(4, 6)          # once the wider court opens

WHO = {"feyre": "Feyre", "tamlin": "Tamlin", "lucien": "Lucien", "alis": "Alis", "nesta": "Nesta",
       "elain": "Elain", "father": "Father", "mother": "Mother"}

TRIG = {"region": 0, "room": 1, "place": 2, "near": 3, "deed": 4, "follow": 5}

LINES = []   # (area, dict)
PLACES = {}  # area -> [(id, region, x, z, r)]


def line(area, lid, speaker, text, trig, where="", phases=(), req=(), forbid=(), hours=None, once=True,
         cd=240.0, pr=0, inner=False, follow="", canon="X", deed="", who=None, delivery=""):
    LINES.append((area, dict(id=lid, speaker=speaker, text=text, trig=TRIG[trig], where=where,
                             phases=list(phases), req=list(req), forbid=list(forbid),
                             hours=hours, once=once, cd=cd, pr=pr, inner=inner, follow=follow,
                             canon=canon, deed=deed,
                             who=("" if inner else WHO.get(speaker, "")) if who is None else who,
                             delivery=delivery)))


def think(area, lid, text, trig, where, phases=(), **kw):
    """Feyre's own thought (inner voice)."""
    kw.setdefault("delivery", "inner voice: dry, quiet, close")
    line(area, lid, "feyre", text, trig, where, phases, inner=True, **kw)


def say(area, lid, speaker, text, phases=(), where="", **kw):
    line(area, lid, speaker, text, "near", where, phases, **kw)


def chat(area, lid, speaker, text, phases=(), where="", cd=300.0, **kw):
    """A repeatable remark for when she comes by again."""
    line(area, lid, speaker, text, "near", where, phases, once=False, cd=cd, pr=-10, **kw)


def deed(area, lid, flag, text, phases=(), speaker="feyre", pr=0, **kw):
    inner = kw.pop("inner", speaker == "feyre")
    if inner:
        kw.setdefault("delivery", "inner voice, just after the deed")
    line(area, lid, speaker, text, "deed", "", phases, deed=flag, inner=inner, pr=pr, **kw)


def place(area, pid, region, x, z, r=16.0):
    PLACES.setdefault(area, []).append((pid, region, x, z, r))


def court_places():
    """Court landmark centres and radii from the L32 PlaceTable."""
    path = os.path.join(ROOT, "data", "places", "court_places.tres")
    out = {}
    text = open(path).read()
    for blk in text.split("[sub_resource")[1:]:
        m = re.search(r'\nid = &"([a-z_]+)"', blk)
        c = re.search(r"center = Vector2\(([-\d.]+), ([-\d.]+)\)", blk)
        r = re.search(r"\nradius = ([\d.]+)", blk)
        if m and c:
            out[m.group(1)] = (float(c.group(1)), float(c.group(2)), float(r.group(1)) if r else 14.0)
    return out


CP = court_places()


def cplace(area, pid, region):
    x, z, r = CP[pid]
    place(area, pid, region, x, z, max(r + 8.0, 18.0))


# =============================================================================
# The cottage (ch1-4, and ch29 when she brings money back)
# =============================================================================
A = "cottage"
place(A, "elain_garden", "cottage", -132.0, 2182.0, 6.0)
think(A, "c_home_hungry", "Smoke from our chimney, thin as thread. We're down to the last of the wood.",
      "region", "cottage", ph(0), forbid=["wolf_killed"])
think(A, "c_home_doe", "A doe on my shoulders and a pelt worth silver. We eat this week.",
      "region", "cottage", ph(0), req=["wolf_killed"], forbid=["pelt_sold"])
think(A, "c_home_coin", "Coin in my pocket for once. It still doesn't feel like enough.",
      "region", "cottage", HUMAN, req=["pelt_sold"])
think(A, "c_home_return", "The cottage looks smaller. It always was this small.", "region", "cottage", ph(7))
think(A, "c_snowdrops", "Elain's snowdrops. She coaxes flowers out of frozen dirt and calls it nothing.",
      "place", "elain_garden", HUMAN)
think(A, "c_snowdrops_return", "Her garden came back without her. Snowdrops gone to seed.", "place",
      "elain_garden", ph(7))
# Nesta: cold, cutting, iron underneath.
say(A, "A1_03_nesta_beast", "nesta",
    "You're just a half-wild beast with the nerve to bark orders at all hours of the day and night.",
    HUMAN, req=["wolf_killed"], pr=5, follow="A1_04_nesta_forget", canon="V",
    delivery="cold, quick, cutting; not shouted (Keeper, voice-lines-act1)")
line(A, "A1_04_nesta_forget", "nesta", "Someday, Feyre, you'll have no one left to remember you.", "follow",
     phases=HUMAN, canon="A", delivery="quieter, meaner")
say(A, "n_tomas", "nesta", "Tomas Mandray walked me halfway home. Don't look at me like that.", HUMAN,
    delivery="defensive, chin up")
say(A, "n_cloak", "nesta", "If you're going to the village, the cloak first. Mine's worn through at the hem.",
    ph(0), req=["wolf_killed"], forbid=["pelt_sold"], canon="A")
say(A, "n_hale", "nesta", "Going to see the Hale boy again? Don't pretend you aren't.", HUMAN, canon="A")
say(A, "n_ribbon", "nesta", "You bought the cheap thread. Of course you did.", HUMAN, req=["pelt_sold"])
chat(A, "n_door", "nesta", "Close the door. You're letting the cold in.", HUMAN)
chat(A, "n_hands", "nesta", "Wash the blood off before you touch the bread.", HUMAN, req=["wolf_killed"])
# Elain: gentle, dreamy, flowers.
say(A, "A1_02_elain_cloak", "elain", "I'd love a new cloak.", HUMAN, req=["wolf_killed"], pr=5, canon="V",
    delivery="soft, wistful, almost apologetic")
say(A, "e_doe", "elain", "A whole doe! Feyre, we'll have stew for days.", ph(0), req=["wolf_killed"])
say(A, "e_snowdrops", "elain", "The snowdrops came up again. Even in this cold. Isn't that something?", HUMAN)
say(A, "e_seeds", "elain", "If we ever had a little money, I'd buy seeds. Real ones, from the south.", HUMAN)
say(A, "e_bird", "elain", "Father carved a little bird today. It looks like it's about to sing.", HUMAN)
chat(A, "e_fire", "elain", "You look frozen through. Sit by the fire a moment.", HUMAN)
chat(A, "e_hum", "elain", "I was thinking about summer. Do you remember summer?", HUMAN)
# Father: defeated, soft, carving by the fire.
deed(A, "A1_05_father_hope", "fact.father_hearth_sat", "We need hope, or else we cannot endure.",
     speaker="father", phases=HUMAN, pr=5, canon="V", delivery="tired, then a rare clarity; gentle")
say(A, "f_sorry", "father", "You shouldn't have to do all this, Feyre. I know that.", HUMAN)
say(A, "f_ships", "father", "I had three ships at sea once. I thought that was the worst a man could lose.",
    HUMAN)
say(A, "f_wolf", "father", "A wolf that size, this near the village? Be careful in those woods.", ph(0),
    req=["wolf_killed"])
chat(A, "f_pine", "father", "Hand me that bit of pine, would you? The good piece.", HUMAN)
chat(A, "f_knee", "father", "The damp's in my knee again. It'll pass.", HUMAN, canon="A")
deed(A, "A1_06_mother_vow", "fact.mother_bed_seen", "Stay together, and look after them.", speaker="mother",
     phases=HUMAN, pr=5, canon="V", inner=True, who="Mother",
     delivery="memory: a whisper in her head, feverish and fading")
deed(A, "d_wolf_killed", "wolf_killed", "Done. Don't think about its eyes.", phases=HUMAN)
deed(A, "d_wolf_skinned", "fact.wolf_skinned", "Heavy. Heavier than any pelt has a right to be.",
     phases=HUMAN)

# =============================================================================
# The village (ch3), and the gold she brings back (ch29-30)
# =============================================================================
A = "village"
place(A, "village_square", "village", 380.0, 2250.0, 16.0)
place(A, "tavern", "village", 415.0, 2215.0, 10.0)
place(A, "notice_board", "village", 383.6, 2236.5, 5.0)
place(A, "pillory", "village", 377.0, 2233.3, 5.0)
place(A, "mill", "village", 560.0, 2420.0, 16.0)
place(A, "debt_house", "village", 460.0, 2320.0, 10.0)
place(A, "abandoned_barn", "village", 600.0, 2150.0, 16.0)
place(A, "meeting_hall", "village", 330.0, 2300.0, 12.0)
think(A, "v_market", "Market day. Everyone watching everyone else's purse.", "region", "village", HUMAN,
      forbid=["pelt_sold"])
think(A, "v_silver", "Silver in my pocket. Just once, I could buy something that isn't food.", "region",
      "village", HUMAN, req=["pelt_sold"])
think(A, "v_return", "They don't know me in this dress. Good.", "region", "village", ph(7))
line(A, "A1_07_blessed_greeting", "blessed", "May the Immortal Light shine upon thee, sisters.", "place",
     "village_square", HUMAN, pr=5, canon="V", who="Child of the Blessed",
     delivery="serene, sing-song, over silver bells")
think(A, "v_tavern", "Ale and wet wool. I'd trade a pelt for an hour by that fire.", "place", "tavern", HUMAN)
think(A, "v_notices", "Notices I can't read. Bounties, probably. Or more rules about faeries.", "place",
      "notice_board", HUMAN, canon="A")
think(A, "v_pillory", "Someone stood there all last week for stealing bread. I remember thinking: careless.",
      "place", "pillory", HUMAN)
think(A, "v_mill", "The mill wheel's frozen solid. No grinding till spring.", "place", "mill", HUMAN)
think(A, "v_debt", "That house owes half the village. The shutters haven't opened since autumn.", "place",
      "debt_house", HUMAN)
think(A, "v_barn", "Nobody's kept animals in that barn since the fever winter.", "place", "abandoned_barn",
      HUMAN)
think(A, "v_hall", "Where they read the Treaty out every year. As if any of us could forget it.", "place",
      "meeting_hall", HUMAN)
think(A, "v_gold", "Gold for the poorest doors first. It won't fix anything. It'll fix this winter.", "place",
      "debt_house", ph(7), canon="A")
# Villagers (any of the four), then each by face.
say(A, "vil_wall", "villager", "My cousin swears she heard something at the Wall. Not a wolf. Worse.", HUMAN,
    where="village")
say(A, "vil_hunter", "villager", "You're the Archeron girl. The hunter. Seen you dragging deer up that road.",
    HUMAN, where="village")
say(A, "vil_blessed", "villager", "The Blessed again, telling folk the faeries are holy. Holy!", HUMAN,
    where="village")
say(A, "vil_iron", "villager", "Iron over every doorframe. I don't care what the Blessed say.", HUMAN,
    where="village")
chat(A, "vil_copper", "villager", "Spare a copper? No? Didn't think so.", HUMAN, where="village")
say(A, "vil_rich", "villager", "Is that the youngest Archeron? You look like a lady now.", ph(7),
    where="village")
say(A, "vil_aunt", "villager", "An aunt left you a fortune, they say. Lucky. Some of us got nothing.", ph(7),
    where="village", canon="A")
say(A, "elder_slaves", "human_elder",
    "Before the Treaty, my grandmother's grandmother served them. Don't you forget it.", HUMAN, canon="A")
say(A, "elder_ships", "human_elder", "I remember your father's ships coming in. Whole town turned out.", HUMAN)
say(A, "youth_isaac", "human_youth", "Isaac Hale's been asking after you.", HUMAN)
chat(A, "youth_vane", "human_youth", "Bet you couldn't hit the weathervane from here.", HUMAN)
say(A, "woman_tomas", "human_woman", "The Mandray boy's sweet on your sister. Everyone knows it.", HUMAN)
chat(A, "woman_eggs", "human_woman", "Fresh eggs, if you've the coin. You haven't, have you.", HUMAN)
say(A, "man_ice", "human_man", "Mind the ice by the well. Old Rowan broke his hip on it.", HUMAN)
say(A, "man_wolves", "human_man", "Wolves are bold this year. Took a calf off a farm east of here.", HUMAN)
say(A, "blessed_home", "blessed", "One day they will carry us across the Wall, sister, and we will be home.",
    HUMAN, canon="A")
chat(A, "blessed_bells", "blessed", "Do you hear the bells? Each one is a prayer that they come for us.", HUMAN)
say(A, "peddler_ash", "peddler", "Ash, cut at the border. The one wood they fear, so the stories go.", HUMAN,
    canon="A", delivery="low, a salesman's secret")
say(A, "peddler_border", "peddler", "Border towns are emptying. Folk say things come over the Wall at night.",
    HUMAN)
chat(A, "peddler_trinkets", "peddler", "Ribbons, needles, a mirror that only lies a little. For you, a bargain.",
     HUMAN)
deed(A, "d_pelt_sold", "pelt_sold", "More than the pelt was worth. She paid me for something else.",
     phases=HUMAN)

# =============================================================================
# The human wilds: the hunting forest, the old estate, the Wall
# =============================================================================
A = "human_wilds"
place(A, "waiting_oak", "hunting_forest", -420.0, 1720.0, 10.0)
place(A, "ash_grove", "hunting_forest", -700.0, 1580.0, 20.0)
place(A, "hunting_lodge", "hunting_forest", 480.0, 1650.0, 18.0)
place(A, "lost_estate", "workshop", -640.0, 2330.0, 22.0)
place(A, "fathers_workshop", "workshop", -560.0, 2240.0, 10.0)
think(A, "hf_snow", "The snow's already covering the blood. Good.", "region", "hunting_forest", HUMAN,
      req=["wolf_killed"])
think(A, "hf_oak", "My oak. I've waited out half a winter in those branches.", "place", "waiting_oak", HUMAN,
      req=["wolf_killed"])
think(A, "hf_ash", "Ash trees. If the stories are true, this is all they fear.", "place", "ash_grove", HUMAN,
      canon="A")
think(A, "hf_lodge", "The old lords hunted here for sport. Sport.", "place", "hunting_lodge", HUMAN)
think(A, "ws_enter", "The old estate. I don't come here. I don't know why I came.", "region", "workshop",
      HUMAN)
think(A, "ws_glass", "Our house had glass windows once. I used to count the colours in them.", "place",
      "lost_estate", HUMAN)
think(A, "ws_shed", "Father's workshop. He hasn't carved anything bigger than a bird in eight years.", "place",
      "fathers_workshop", HUMAN)
think(A, "ws_return", "Nothing left to come back for here. I came anyway.", "region", "workshop", ph(7))
think(A, "wall_breath", "The Wall. You can't see it. You feel it, like a held breath.", "region", "wall_seam",
      HUMAN)
think(A, "wall_hush", "Even the crows go quiet this close. They know better than we do.", "region",
      "wall_seam", HUMAN, req=["wolf_killed"], pr=1)
think(A, "wall_back", "The Wall again. This time I'm the one choosing.", "region", "wall_seam", ph(7, 8),
      req=["beddor_fire_learned"])

# =============================================================================
# The manor house, room by room (ch6-28)
# =============================================================================
A = "manor_house"
R = "room"
think(A, "h_entrance", "Marble and gold and flowers on every table. And no one to see any of it.", R,
      "entrance_hall", COURT, forbid=["glamour_lifted"], canon="A")
think(A, "h_entrance_full", "Masks everywhere. The hall was never empty. I just couldn't see.", R,
      "entrance_hall", ph(6), req=["glamour_lifted"], canon="A")
think(A, "h_dining", "That table could seat forty. Three of us rattle around it.", R, "dining_hall", COURT,
      req=["first_dinner_eaten"])
think(A, "h_gallery_shut", "Sheets over the paintings. Who hides paintings?", R, "gallery", COURT,
      forbid=["gallery_opened"], canon="A")
think(A, "h_gallery_open", "I could stand here until I starve. I almost want to.", R, "gallery", COURT,
      req=["gallery_opened"])
think(A, "h_library", "Shelf after shelf, and I can't read a single spine.", R, "library", COURT, canon="A")
think(A, "h_study", "His study smells of leather and candle smoke.", R, "tamlin_study", COURT)
think(A, "h_map_room", "Maps of lands I'll never walk, every border inked in gold.", R, "map_room", COURT)
think(A, "h_armory", "Blades enough for an army. He fights his wars alone.", R, "armory", COURT)
think(A, "h_drawing", "Lucien's favourite room, judging by the wine rings.", R, "drawing_room", COURT)
think(A, "h_music", "A harp with every string in tune, and no one to play it.", R, "music_room", COURT)
think(A, "h_morning", "Light like honey through the glass. I'd paint this, if I could.", R, "morning_room",
      COURT)
think(A, "h_ballroom", "A ballroom, for a court that doesn't dance.", R, "ballroom", ph(2, 5))
think(A, "h_conservatory", "Flowers I have no names for. Elain would weep.", R, "conservatory", COURT)
think(A, "h_flower_room", "Someone arranges these every morning. I've never once seen who.", R, "flower_room",
      COURT, forbid=["glamour_lifted"])
think(A, "h_shrine", "Candles that never burn down. Magic, or someone very patient.", R, "shrine", COURT)
think(A, "h_saloon", "Doors open onto the roses. Nothing is locked here. That's worse, somehow.", R,
      "garden_saloon", COURT)
think(A, "h_bedroom", "A bed I could lose myself in. The knife stays under the pillow.", R, "feyre_bedroom",
      ph(2))
think(A, "h_dressing", "Gowns in every colour of a sunset. I'll take the trousers, thank you.", R,
      "dressing_room", ph(2, 4), canon="A")
think(A, "h_dressing_gown", "Maybe the rose one. Just this once.", R, "dressing_room", ph(5, 6),
      req=["bite_endured"])
think(A, "h_bath", "Hot water whenever I want it. I keep waiting for the price.", R, "feyre_bath", COURT)
think(A, "h_painting_room", "Canvases. Brushes. Paint. All of it mine.", R, "painting_room", COURT,
      req=["gallery_opened"])
think(A, "h_portraits", "Old lords in gilt frames. None of them look kind.", R, "portrait_gallery", COURT,
      canon="A")
think(A, "h_lucien_rooms", "Russet and bronze and far too many mirrors.", R, "lucien_chambers", COURT)
think(A, "h_tamlin_room", "His room. I shouldn't be in here.", R, "tamlin_bedchamber", ph(2, 5))
think(A, "h_nursery", "Dust on the cradle. Nobody's been small in this house for a long time.", R,
      "old_nursery", COURT)
think(A, "h_observatory", "The whole court laid out like a painting. Spring, as far as I can see.", R,
      "observatory", COURT)
think(A, "h_rose_bower", "Roses on the tower top. Of course there are.", R, "rose_bower", COURT)
think(A, "h_attic_loft", "Someone painted up here once. The colours are still in the boards.", R,
      "attic_painting_loft", COURT)
think(A, "h_playroom", "Wooden horses with chipped gilt. I wonder whose they were.", R, "attic_playroom",
      COURT)
think(A, "h_kitchen", "Always warm. Somebody's always just left.", R, "svc_kitchen", COURT,
      forbid=["glamour_lifted"])
think(A, "h_kitchen_full", "So this is who's been cooking. Hello.", R, "svc_kitchen", ph(6),
      req=["glamour_lifted"])
think(A, "h_infirmary", "Clean linen and bitter herbs. My hands remember his blood.", R, "svc_infirmary",
      COURT, req=["tamlin_wound_dressed"])
think(A, "h_wine", "Wine older than my grandmother. Lucien will have opinions.", R, "wine_vault", COURT)
think(A, "h_crypt", "The old High Lords. His father is down here somewhere.", R, "ancestral_crypt", COURT)
think(A, "h_mask_vault", "Masks on every hook. The ones no one can take off aren't here.", R, "mask_vault",
      COURT, canon="A")
think(A, "h_well", "A well under the house. The water's so still it looks solid.", R, "well_chamber", COURT)
think(A, "h_tunnel", "Cold down here. Cold like the woods at night.", R, "old_tunnel", COURT)
think(A, "h_alis_room", "A narrow bed, a mended apron, and two little wooden horses on the sill.", R,
      "svc_alis_room", COURT)
think(A, "h_sewing", "Bolts of silk in every pastel there is. I'm not touching them. Probably.", R,
      "sewing_room", COURT)
think(A, "h_ruined", "Glass on the floors. Claw marks in the panels. Where is everyone?", R, "entrance_hall",
      ph(8), canon="A", delivery="inner voice, frightened, very quiet")

# =============================================================================
# The manor grounds (ch6-27)
# =============================================================================
A = "manor_grounds"
place(A, "rose_garden", "manor_estate", 0.0, -146.0, 40.0)
place(A, "hedge_maze", "manor_estate", -218.0, -208.0, 30.0)
place(A, "glass_houses", "manor_estate", 140.0, -148.0, 28.0)
place(A, "kitchen_garden", "manor_estate", 126.0, -49.0, 24.0)
place(A, "stables", "manor_estate", -130.0, -31.0, 26.0)
place(A, "paddock", "manor_estate", -247.0, -25.0, 40.0)
place(A, "swan_pond", "manor_estate", 190.0, 110.0, 50.0)
place(A, "walled_orchard", "manor_estate", -242.0, 152.0, 40.0)
place(A, "forecourt_fountain", "manor_estate", 0.0, 0.0, 18.0)
place(A, "manor_gate", "manor_estate", 0.0, 295.0, 22.0)
think(A, "g_bloom", "Every flower open at once. Nothing grows like this. Nothing.", "region", "manor_grounds",
      ph(2, 3))
think(A, "g_bloom_later", "I've stopped counting the roses. I've started naming the colours.", "region",
      "manor_grounds", ph(4, 5))
think(A, "g_full", "Wings in the hedges, eyes in the roses. It was always this full.", "region",
      "manor_grounds", ph(6), req=["glamour_lifted"], canon="A")
think(A, "g_roses", "Roses as big as my fists. They smell like a summer I never had.", "place", "rose_garden",
      ph(2, 3))
think(A, "g_roses_gift", "His father planted these for his mother. The one kind thing he did.", "place",
      "rose_garden", ph(4, 6), req=["gallery_opened"], pr=1, canon="A")
think(A, "g_maze", "A maze. Lovely. Exactly where something would wait for me.", "place", "hedge_maze", COURT)
think(A, "g_glass", "Glass houses full of fruit out of season.", "place", "glass_houses", COURT)
think(A, "g_herbs", "Herbs in neat rows. Feverfew, sage. The rest I'll learn.", "place", "kitchen_garden",
      COURT)
think(A, "g_stables", "Horses with coats like poured cream. The white mare remembers me.", "place", "stables",
      COURT)
think(A, "g_paddock", "Room to ride all day without ever seeing a wall.", "place", "paddock", COURT)
think(A, "g_swans", "Swans. Even the birds here look painted on.", "place", "swan_pond", COURT)
think(A, "g_orchard", "Apples and blossom on the same branch. That isn't right. It's lovely.", "place",
      "walled_orchard", COURT)
think(A, "g_fountain", "A fountain that sings when the wind's right.", "place", "forecourt_fountain", COURT,
      forbid=["fountain_head_found"])
think(A, "g_fountain_after", "I can't look at the water. I still see it there.", "place",
      "forecourt_fountain", ph(6), req=["fountain_head_found"],
      delivery="inner voice, flat with shock")
think(A, "g_gate", "The gate's open. He meant it, then. I'm not his prisoner.", "place", "manor_gate", ph(2),
      canon="A")
think(A, "g_unseen", "Something shimmered by the hedge. When I looked, nothing.", "place", "rose_garden", ph(2),
      forbid=["glamour_lifted"], canon="A", pr=2)

# --- Lucien: sharp, sarcastic, wounded under it ------------------------------
A = "lucien"
say(A, "l_still_here", "lucien", "Still here? I'd bet myself you'd be over the wall by now.", ph(2),
    forbid=["bogge_survived"])
say(A, "l_andras", "lucien", "I hunted with Andras, you know. Most mornings. Before.", ph(2), canon="A",
    delivery="light, then the light goes out")
say(A, "l_knife", "lucien", "Do keep the dinner knife. We've hundreds.", ph(2, 3), req=["first_dinner_eaten"],
    canon="A")
say(A, "l_mask", "lucien", "Don't stare. It's rude, and it isn't coming off.", COURT, canon="A")
say(A, "l_treaty", "lucien", "There's no loophole in the Treaty, if that's what you're hoping. We've looked.",
    ph(2, 3), canon="A")
say(A, "l_walls", "lucien", "Admiring the roses, or measuring the walls? Both, I expect.", ph(2, 3),
    where="manor_grounds")
say(A, "l_eye", "lucien", "It sees well enough. Better than the old one, some days.", COURT)
say(A, "l_didnt_look", "lucien", "You didn't look. Most people look.", ph(2, 3), req=["bogge_survived"])
say(A, "l_mood", "lucien", "He's in a mood. He's always in a mood. Today it's a worse one.", ph(3))
say(A, "l_time", "lucien", "Some of us have run out of time to be polite.", ph(3), canon="A")
say(A, "l_autumn", "lucien", "Autumn's lovely this time of year, I hear. I'm not welcome there to see it.",
    ph(4, 6), req=["starlight_pool_found"], canon="A")
say(A, "l_paint_nose", "lucien", "You've paint on your nose. No, leave it. It's an improvement.", WIDER,
    req=["first_painting"])
say(A, "l_fire_night", "lucien", "Fire Night's coming. Lock your door. I mean it.", ph(5),
    forbid=["calanmai_attended"], canon="A")
say(A, "l_pigs", "lucien", "Faerie pigs. I'll treasure that until I die.", ph(5, 6), req=["bite_endured"],
    canon="A", delivery="delighted, barely holding a laugh")
say(A, "l_wine", "lucien", "If anyone offers you faerie wine, say no. Then say no again.", ph(6),
    forbid=["solstice_danced"], canon="A")
say(A, "l_gardeners", "lucien", "So you can see us now. Try not to scream at the gardeners. They're sensitive.",
    ph(6), req=["glamour_lifted"])
chat(A, "l_alis", "lucien", "Alis is looking for you. That's never good.", COURT)
chat(A, "l_nursemaid", "lucien", "Walk with me or don't. I'm not your nursemaid.", COURT)
chat(A, "l_glare", "lucien", "If you're going to glare, at least do it from the shade.", COURT)
deed(A, "d_bogge_lucien", "bogge_survived", "Breathe. It's gone. You did well.", speaker="lucien",
     phases=COURT, pr=5)

# --- Tamlin: terse, gruff, gentle under it -----------------------------------
A = "tamlin"
say(A, "t_grounds", "tamlin", "Go where you like on the grounds. Not the woods after dark.", ph(2), canon="A")
say(A, "t_eating", "tamlin", "You're eating more. Good.", ph(2, 3), req=["first_dinner_eaten"])
say(A, "t_border", "tamlin", "I'll be at the border tonight. Lucien stays.", ph(2, 3), canon="A")
say(A, "t_bogge", "tamlin", "It won't come near the house. I'll see to it.", ph(2, 3), req=["bogge_survived"],
    forbid=["tamlin_wound_dressed"])
say(A, "t_hand", "tamlin", "It's healing. You've steady hands.", ph(3), req=["tamlin_wound_dressed"])
say(A, "t_letters", "tamlin", "If you want help with your letters, ask. Or don't. The offer stands.", ph(3, 4),
    req=["study_mural_seen"], canon="A")
say(A, "t_naga", "tamlin", "Four naga, and you went at them with a boot knife.", ph(3, 4),
    req=["naga_survived"], canon="A")
say(A, "t_faerie", "tamlin", "You held his hand. Most wouldn't have.", ph(3, 4), req=["summer_faerie_comforted"])
say(A, "t_paint", "tamlin", "Paint whatever you like. Paint the walls, if the canvases run out.", WIDER,
    req=["gallery_opened"])
say(A, "t_pool", "tamlin", "That pool was mine when I was a boy. It's yours too, now.", WIDER,
    req=["starlight_pool_found"], canon="A")
say(A, "t_father", "tamlin", "My father planted those roses. It's the only kind thing I know of him.", WIDER,
    where="manor_grounds", req=["gallery_opened"], canon="A")
say(A, "t_calanmai", "tamlin", "Calanmai. Stay inside tonight. Please.", ph(5), forbid=["calanmai_attended"],
    canon="A")
say(A, "t_sorry", "tamlin", "The kitchen. I'm sorry. For what I was that night.", ph(5, 6),
    req=["bite_endured"], canon="A", delivery="ashamed, low")
say(A, "t_blight", "tamlin", "The blight's spreading. I'll be gone a few days.", ph(6), canon="A")
say(A, "t_fiddle", "tamlin", "You laughed at my fiddling. I'll have you know it's famous.", ph(6),
    req=["solstice_danced"])
chat(A, "t_hungry", "tamlin", "Are you hungry? You're always hungry. Come and eat.", COURT)
chat(A, "t_thorns", "tamlin", "Mind the thorns.", COURT, where="manor_grounds")
chat(A, "t_light", "tamlin", "The light's good today. For painting, I mean.", WIDER, req=["first_painting"])
deed(A, "d_naga_tamlin", "naga_survived", "You're safe. I've got you.", speaker="tamlin", phases=COURT, pr=5)

# --- Alis: brisk, practical, sly ---------------------------------------------
A = "alis"
say(A, "a_trousers", "alis", "Trousers again? Fine. One day you'll wear a gown and like it.", ph(2, 4),
    canon="A")
say(A, "a_curtain", "alis", "Next time you string up a curtain to catch me, use the ugly ones.", ph(2, 3),
    req=["curtain_trap_set"], canon="A")
say(A, "a_lucien", "alis", "Don't let Lucien bully you. Bite back. He likes it better.", ph(2, 3), canon="A")
say(A, "a_suriel", "alis", "A chicken? You offered it a chicken? I'd have given it a new cloak.", ph(3, 4),
    req=["suriel_bound"], canon="A", delivery="scandalised, then fond")
say(A, "a_nephews", "alis", "My sister's boys are far from here. Two of them. Little terrors.", ph(3, 4),
    canon="A")
say(A, "a_glass", "alis", "There. Look in the glass. That's a girl worth looking at.", ph(5, 6),
    req=["bite_endured"], where="dressing_room")
say(A, "a_solstice", "alis", "Hold still. Flowers in your hair, and the blue. He won't be able to breathe.",
    ph(6), forbid=["solstice_danced"], canon="A")
say(A, "a_face", "alis", "Yes, this is my face. Close your mouth, child.", ph(6), req=["glamour_lifted"])
say(A, "a_fountain", "alis", "Stay away from the fountain. Please. Just for a while.", ph(6),
    req=["fountain_head_found"])
chat(A, "a_elbows", "alis", "Eat something. You're all elbows.", COURT)
chat(A, "a_mud", "alis", "Mud on the floor again. I'll have it out of the rugs by supper.", COURT)
chat(A, "a_bath", "alis", "The bath's drawn whenever you want it. Hot as you like.", COURT)

# --- The household, the sentries and the gardeners ---------------------------
A = "household"
say(A, "s_lady", "sentry", "The grounds are safe, lady. It's past them you should worry about.", COURT)
say(A, "s_andras", "sentry", "Andras stood this watch with me. Before.", COURT, req=["first_dinner_eaten"],
    delivery="flat, not forgiving, not cruel")
say(A, "s_double", "sentry", "The border's restless. We've doubled the watch.", ph(6))
say(A, "gd_buds", "gardener", "Mind the buds, mind the buds! Those are for the Solstice.", ph(6),
    forbid=["solstice_danced"])
say(A, "gd_peonies", "gardener", "You trampled my peonies in the spring. I forgave you. Mostly.", ph(6))
say(A, "sv_place", "servant", "We've set your place at table since the very first night, miss.", ph(6))
say(A, "sv_see", "servant", "You really couldn't see us? Not even a little?", ph(6))
say(A, "cook_torte", "servant_cook", "You ate like a starved fox that first week. I took it as a compliment.",
    ph(6))
chat(A, "cook_hands", "servant_cook", "Torte's for after supper. Hands off.", ph(6))
say(A, "maid_flowers", "servant_maid", "I'm the one who leaves flowers on your pillow. You're welcome.", ph(6))
say(A, "foot_doors", "servant_footman", "The front doors open themselves. I like to pretend I help.", ph(6),
    canon="A")
say(A, "seam_blue", "seamstress", "Your blue gown's nearly done. Arms out. Higher.", ph(6),
    forbid=["solstice_danced"])
chat(A, "seam_pins", "seamstress", "Pins in my mouth, don't make me laugh.", ph(6))
say(A, "potion_green", "potion_maker", "Don't touch the green bottle. Don't touch any bottle, actually.", ph(6))

# =============================================================================
# The woods (ch9-17): border woods, eastern woods, the Suriel's glade
# =============================================================================
A = "woods"
think(A, "w_border_quiet", "These woods are too quiet. Even the birds keep their voices down.", "region",
      "border_woods", ph(2), forbid=["bogge_survived"])
think(A, "w_border_after", "I don't look between the trees anymore. I just don't.", "region", "border_woods",
      COURT, req=["bogge_survived"], delivery="inner voice, tight, not looking")
think(A, "w_border_thin", "The woods feel thinner. Like something's been eating the light.", "region",
      "border_woods", ph(6), req=["bogge_survived"], pr=1)
think(A, "w_east_moss", "Old trees thick with moss. The deeper I go, the colder it gets.", "region",
      "eastern_woods", ph(3, 4))
think(A, "w_east_bait", "Light in coloured ribbons through the leaves. It doesn't feel safe. It feels like bait.",
      "region", "eastern_woods", ph(4, 5))
think(A, "w_east_ferns", "Something's watching from the ferns. Probably nothing. Probably.", "region",
      "eastern_woods", ph(6))
think(A, "w_glade_birch", "Young birches and running water. My skin is crawling.", "region", "suriel_glade",
      ph(3), forbid=["suriel_bound"], canon="A")
think(A, "w_glade_teeth", "The snare's still on the branch. I can't stop seeing their teeth.", "region",
      "suriel_glade", ph(3, 6), req=["naga_survived"], delivery="inner voice, frightened")
think(A, "w_glade_truth", "It told me the truth here. I wish it hadn't.", "region", "suriel_glade", ph(4, 6),
      req=["suriel_bound"], pr=-1)

# =============================================================================
# The wider court (ch18-27)
# =============================================================================
A = "wider_court"
for pid in ["starlight_pool", "glimmerfall", "looking_lake_isle"]:
    cplace(A, pid, "starlight_glen")
for pid in ["sealed_pass", "ember_crown", "thornwater_spring", "border_markers"]:
    cplace(A, pid, "autumn_foothills")
for pid in ["rose_spire", "briar_gate", "gardeners_folly"]:
    cplace(A, pid, "rosewild")
for pid in ["musicians_bower", "arch_avenue", "crown_oak", "long_tables"]:
    cplace(A, pid, "solstice_meadow")
for pid in ["stone_ring", "cave_of_the_rite", "bonfire_terraces", "drum_field"]:
    cplace(A, pid, "hill_of_the_rite")
for pid in ["hollow_steading", "dead_sentinel", "grey_briar_wall", "blight_heart"]:
    cplace(A, pid, "blighted_reaches")
for pid in ["blossom_cathedral", "cider_mill", "bee_tower", "vale_weir"]:
    cplace(A, pid, "blossom_vale")
# Starlight glen
think(A, "sg_silver", "The light here comes up from the ground, silver and slow.", "region", "starlight_glen",
      WIDER, forbid=["starlight_pool_found"])
think(A, "sg_boy", "His favourite place, when he was a boy. I can see why.", "region", "starlight_glen", WIDER,
      req=["starlight_pool_found"], canon="A")
think(A, "sg_grey", "Even here the edges are going grey.", "region", "starlight_glen", ph(6), pr=1)
think(A, "sg_pool", "I swam in starlight. No one at home would ever believe it.", "place", "starlight_pool",
      WIDER, req=["starlight_pool_found"])
think(A, "sg_falls", "A waterfall that sparkles as it falls. Of course it does.", "place", "glimmerfall", WIDER)
think(A, "sg_isle", "An island in a lake as still as a mirror. The trees on it lean to look.", "place",
      "looking_lake_isle", WIDER)
# Western fells
think(A, "wf_velvet", "Hills like rumpled green velvet, and wind that smells of heather.", "region",
      "western_fells", ph(3, 4))
think(A, "wf_sheep", "Sheep with gold-tipped wool. I've stopped asking.", "region", "western_fells", ph(4, 5),
      pr=-1)
think(A, "wf_grey", "Grey patches on the slopes. The blight, he said.", "region", "western_fells", ph(6),
      canon="A")
# Autumn foothills
think(A, "af_red", "Red leaves in the middle of spring. That's Autumn, past those hills.", "region",
      "autumn_foothills", WIDER, canon="A")
think(A, "af_lucien", "Lucien never comes this far. I don't ask him why.", "region", "autumn_foothills", WIDER,
      req=["starlight_pool_found"], pr=1, canon="A")
think(A, "af_smoke", "Smoke on the far ridges. Autumn burns differently.", "region", "autumn_foothills", ph(6),
      pr=2)
think(A, "af_pass", "The pass to Autumn, sealed. His family is on the other side.", "place", "sealed_pass",
      WIDER, canon="A")
think(A, "af_embers", "Leaves like embers that never burn out.", "place", "ember_crown", WIDER)
think(A, "af_spring", "Water through thorns, cold enough to ache.", "place", "thornwater_spring", WIDER)
think(A, "af_markers", "Stones carved with leaves. One court ends here, and another begins.", "place",
      "border_markers", WIDER, canon="A")
# Rosewild
think(A, "rw_blush", "Roses gone wild, taller than me, pink as a blush.", "region", "rosewild", WIDER)
think(A, "rw_from_manor", "I've watched that spire from my window for weeks.", "region", "rosewild", ph(5, 6),
      pr=1)
think(A, "rw_spire", "A tower of roses, petals falling like slow snow.", "place", "rose_spire", WIDER)
think(A, "rw_briar", "A gate of briars. The thorns lean away from me.", "place", "briar_gate", WIDER)
think(A, "rw_folly", "A little folly with no door. Somebody's idea of a joke.", "place", "gardeners_folly",
      WIDER)
# Solstice meadow
think(A, "sm_ribbons", "Long tables, ribbons in the trees. They're dressing the meadow for something.",
      "region", "solstice_meadow", WIDER, forbid=["solstice_danced"])
think(A, "sm_dawn", "I danced here until dawn. Me.", "region", "solstice_meadow", ph(6), req=["solstice_danced"],
      pr=1)
think(A, "sm_bower", "Fiddles hung in the branches, waiting for hands.", "place", "musicians_bower", WIDER)
think(A, "sm_arches", "Arches of flowers all the way down, like a procession waiting to start.", "place",
      "arch_avenue", WIDER)
think(A, "sm_oak", "An oak wearing a crown of blossom. They dress the trees here.", "place", "crown_oak", WIDER)
think(A, "sm_tables", "Food enough for a thousand. My stomach still clenches at the sight.", "place",
      "long_tables", WIDER)
# Hill of the Rite
think(A, "hr_building", "They're building the fires already. Wood piled taller than houses.", "region",
      "hill_of_the_rite", ph(4, 5), forbid=["calanmai_attended"], canon="A")
think(A, "hr_drums", "Drums. I can feel them in my teeth.", "region", "hill_of_the_rite", ph(5),
      hours=(19.0, 5.0), pr=2, canon="A")
think(A, "hr_ash", "Ash on the hill still. I don't like it here.", "region", "hill_of_the_rite", ph(6),
      req=["calanmai_attended"])
think(A, "hr_stones", "Standing stones, warm to the touch even at night.", "place", "stone_ring", WIDER)
think(A, "hr_cave", "Flowers round the cave mouth, as if someone dressed a doorway for a wedding.", "place",
      "cave_of_the_rite", WIDER, forbid=["calanmai_attended"], canon="A")
think(A, "hr_cave_after", "I won't go near that cave again.", "place", "cave_of_the_rite", ph(5, 6),
      req=["calanmai_attended"], delivery="inner voice, cold")
think(A, "hr_field", "The ground's beaten flat from dancing.", "place", "drum_field", WIDER)
think(A, "hr_terraces", "Terraces cut for fires. Hundreds of them.", "place", "bonfire_terraces", WIDER)
# Blighted reaches (horror register: never softened)
think(A, "br_silent", "Nothing sings here. Not a bird, not the wind.", "region", "blighted_reaches", WIDER,
      delivery="inner voice, whispered, afraid to be heard")
think(A, "br_crumble", "The grass crumbles when I step on it. Grey all the way down.", "region",
      "blighted_reaches", ph(5, 6), pr=1)
think(A, "br_coming", "This is what's coming for the rest of it. I know it is.", "region", "blighted_reaches",
      ph(6), req=["fountain_head_found"], pr=2)
think(A, "br_steading", "A farmhouse with the door open and the table set. No one's coming back.", "place",
      "hollow_steading", WIDER, delivery="inner voice, very quiet")
think(A, "br_sentinel", "A tree like a man standing guard, dead on his feet.", "place", "dead_sentinel", WIDER)
think(A, "br_briars", "The briars here are grey, and they move when I'm not looking.", "place",
      "grey_briar_wall", WIDER, delivery="inner voice, breath held")
think(A, "br_heart", "It's colder at the centre. Something here is listening.", "place", "blight_heart", WIDER,
      delivery="inner voice, barely there")
# Blossom vale
think(A, "bv_pink", "Blossom so thick the air itself is pink.", "region", "blossom_vale", ph(4, 5))
think(A, "bv_bees", "Bees the size of my thumb, drunk on nectar.", "region", "blossom_vale", WIDER, pr=-1)
think(A, "bv_afraid", "Petals still falling. Some things here don't know to be afraid.", "region",
      "blossom_vale", ph(6), pr=1)
think(A, "bv_cathedral", "Trees grown into arches like a temple. I'm whispering without meaning to.", "place",
      "blossom_cathedral", WIDER)
think(A, "bv_cider", "Cider and blossom. The whole valley smells like a feast day.", "place", "cider_mill",
      WIDER)
think(A, "bv_bee_tower", "A tower humming like a held note. Bees, thousands of them.", "place", "bee_tower",
      WIDER)
think(A, "bv_weir", "Water over the weir like spun glass.", "place", "vale_weir", WIDER)

# --- The fae village: candy-bright, a little dangerous -----------------------
A = "fae_village"
for pid in ["great_lantern_tree", "lantern_bridge", "village_mill", "seamstress", "potion_house", "market",
            "cottages"]:
    cplace(A, pid, "fae_village")
think(A, "fv_lanterns", "Music and lanterns, and a dozen faces turning to look at me.", "region",
      "fae_village", ph(4))
think(A, "fv_fires", "Everyone here is talking about the fires.", "region", "fae_village", ph(5), pr=1)
think(A, "fv_more", "More of them than I ever saw before. So many more.", "region", "fae_village", ph(6),
      req=["glamour_lifted"], pr=2)
think(A, "fv_tree", "A tree full of lanterns, every one a different pink.", "place", "great_lantern_tree", WIDER)
think(A, "fv_bridge", "The bridge glows under my feet. I'm trying not to like it.", "place", "lantern_bridge",
      WIDER)
think(A, "fv_market", "A market where nobody shouts the prices. They sing them.", "place", "market", WIDER)
think(A, "fv_mill", "A mill grinding petals into something that smells like honey.", "place", "village_mill",
      WIDER)
think(A, "fv_silks", "Silks hung out like flags, every colour I've ever wanted.", "place", "seamstress", WIDER)
think(A, "fv_bottles", "Bottles bubbling in the window. I'm not touching anything.", "place", "potion_house",
      WIDER)
think(A, "fv_roofs", "Toadstool roofs. Actual toadstool roofs.", "place", "cottages", WIDER)
say(A, "rvv_human", "reveler", "A human girl in the village? Don't eat anything unless you're sure of it.",
    ph(4, 5), hours=(8.0, 19.0), canon="A")
say(A, "rvv_lord", "reveler", "The High Lord's mortal. We've all heard about you. Mostly good things.", ph(4, 5),
    hours=(8.0, 19.0))
say(A, "cf_human", "court_fae", "So you can see us now. We could always see you.", ph(6),
    req=["glamour_lifted"], where="fae_village")
say(A, "cf_welcome", "court_fae", "The High Lord's mortal! Welcome, welcome. Mind your step.", ph(6),
    req=["glamour_lifted"], where="fae_village")
say(A, "fm_cousins", "fae_mushroom", "Don't step on my cousins. They're the small ones.", ph(6), req=["glamour_lifted"])
say(A, "fmo_lantern", "fae_moth", "Your lantern's lovely. May I just sit near it? A moment?", ph(6), req=["glamour_lifted"])
say(A, "ff_metal", "fae_fox", "Is it true magic used to smell like metal to you? Poor thing.", ph(6),
    req=["glamour_lifted"], canon="A")
say(A, "fh_prick", "fae_hedgehog", "Pricked you? Sorry. It happens when I'm happy.", ph(6), req=["glamour_lifted"])
say(A, "fp_braids", "fae_pixie", "Ooh, braids! Can I? I'll put flowers in. Tiny ones.", ph(6), req=["glamour_lifted"])
say(A, "fs_hill", "fae_satyr", "Fire Night's coming. Stay far from the hill, little mortal.", ph(4, 5),
    forbid=["calanmai_attended"])
say(A, "fr_smell", "fae_rose", "Smell me. Go on. Best roses in the court, and I'm not being modest.", ph(6), req=["glamour_lifted"])
say(A, "fo_andras", "fae_owl", "Who? Oh. You. The one who shot Andras. We remember.", ph(6), req=["glamour_lifted"],
    delivery="soft, unblinking")
say(A, "fst_thin", "fae_stag", "The woods are thinner than they were. The blight eats the edges.", ph(6), req=["glamour_lifted"],
    canon="A")
say(A, "fn_warm", "fae_nymph", "The water's warm today. It's always warm for friends.", ph(6), req=["glamour_lifted"])
say(A, "fb_trees", "fae_birch", "Shh. I'm listening to the trees. They're worried.", ph(6), req=["glamour_lifted"])
say(A, "fd_roots", "fae_dryad", "Nearly fifty years the roots have tasted it. Something sour.", ph(6), req=["glamour_lifted"],
    canon="A")
# Revellers: Calanmai and the Solstice.
say(A, "rv_fire", "reveler", "Drink, mortal! It's Fire Night!", ph(5), hours=(19.0, 5.0))
say(A, "rv_cave", "reveler", "The High Lord leads the Rite tonight. You'll want to be well away from the cave.",
    ph(5), hours=(19.0, 5.0), canon="A")
chat(A, "rv_drums", "reveler", "Can you feel it? The drums? Dance!", ph(5), hours=(19.0, 5.0))
say(A, "rv_solstice", "reveler", "Longest day of the year! Dance, or get out of the meadow!", ph(6),
    hours=(5.0, 19.0))
say(A, "rv_wine", "reveler", "Have you tried the wine? No? Clever girl.", ph(6), hours=(5.0, 19.0),
    canon="A")
chat(A, "rv_flowers", "reveler", "Flowers in your hair! Now you look like one of us.", ph(6),
     hours=(5.0, 19.0))

# =============================================================================
# After her deeds (spoken once she is free again)
# =============================================================================
A = "deeds"
deed(A, "d_first_dinner", "first_dinner_eaten", "I ate their food. I'm still me. I think.", COURT)
deed(A, "d_curtain", "curtain_trap_set", "Anything that comes through that door gets a faceful of velvet.",
     COURT)
deed(A, "d_bogge", "bogge_survived", "My hands won't stop shaking. I didn't look. I didn't look.", COURT,
     delivery="inner voice, shaking")
deed(A, "d_puca", "puca_resisted", "It wore Father's face. It knew his face.", COURT,
     delivery="inner voice, sick")
deed(A, "d_wound", "tamlin_wound_dressed", "His blood on my hands, and he thanked me for it.", COURT)
deed(A, "d_map", "manor_map_drawn", "Every hall on one page. Now I know every way out.", COURT)
deed(A, "d_mural", "study_mural_seen", "Seven courts, a war, a mountain in the middle. And us, at the edge of it.",
     COURT, canon="A")
deed(A, "d_suriel", "suriel_bound", "It told me the truth. I wish it hadn't.", COURT)
deed(A, "d_naga", "naga_survived", "I'm alive. I'm alive. Stop shaking.", COURT)
deed(A, "d_faerie", "summer_faerie_comforted", "I told him he'd fly again. I lied to a dying man.", COURT,
     delivery="inner voice, hollow")
deed(A, "d_pool", "starlight_pool_found", "I'll remember the cold of that water my whole life.", COURT)
deed(A, "d_gallery", "gallery_opened", "All of it. He opened all of it for me.", COURT)
deed(A, "d_painting", "first_painting", "My first painting in years. It's terrible. I love it.", COURT)
deed(A, "d_attor", "attor_evaded", "That voice. Like nails drawn slow down my spine.", COURT,
     delivery="inner voice, frozen")
deed(A, "d_calanmai", "calanmai_attended", "I should have stayed in my room.", COURT)
deed(A, "d_bite", "bite_endured", "He bit me. I'm going to show everyone the bruise.", COURT, canon="A",
     delivery="inner voice, furious, a little proud")
deed(A, "d_shown", "paintings_shown", "He chose the winter one. Cold and melancholy, and he wanted it anyway.", COURT, canon="A")
deed(A, "d_glamour", "glamour_lifted", "Magic smells like flowers now. Not metal. Flowers.", COURT, canon="A")
deed(A, "d_fountain", "fountain_head_found", "A head in the fountain. A mark on its brow. Don't scream.", COURT,
     delivery="inner voice, a breath from screaming")
deed(A, "d_solstice", "solstice_danced", "I watched the sun come up in his arms. I didn't want it to.", COURT)
deed(A, "d_rhysand", "rhysand_faced", "See you Under the Mountain, he said. As if I'd ever go.", COURT, canon="A")
deed(A, "d_sent_home", "sent_home", "He's sending me home. I should be glad.", COURT)
deed(A, "d_nesta_truth", "nesta_truth_heard", "Nesta went to the Wall for me. Nesta.", ph(7))
deed(A, "d_beddor", "beddor_fire_learned", "Clare Beddor. I gave him her name.", ph(7), canon="A",
     delivery="inner voice, the floor dropping away")


# =============================================================================
# Keeper review (2026-11-02): corrections against the book. Applied last so the
# tables above stay readable; the Keeper signed off on lines and roster with these.
# =============================================================================
KEEPER = {
    "n_cloak": ("I'll get the cloak for Elain first. Nobody's buying me the boots I need.", "A"),
    "c_snowdrops": ("Elain's garden, asleep under the snow. She'll be out here the first mild day.", "A"),
    "e_snowdrops": ("When it's warm again I'll have the garden back. You'll see.", "X"),
    "e_seeds": (None, "A"),
    "c_home_return": ("So small. The cottage had been so small.", "V"),
    "c_snowdrops_return": ("Her old garden's a wild tangle of weeds and blooms now.", "A"),
    "d_pelt_sold": ("She paid more than it was worth. Someone did the same for her once, she said.", "A"),
    "a_suriel": ("The next time that fool Lucien gives you advice on how to trap the Suriel, you come to me. "
                 "Dead chickens! All you needed to do was offer it a new robe.", "V"),
    "a_nephews": ("My sister and her mate were killed. Her boys are why I'm here.", "A"),
    "d_faerie": ("\"It will be all right,\" I told him. I hope he couldn't smell the lie.", "A"),
    "d_pool": ("Warm as silk, that water. Like floating in light.", "A"),
    "g_roses_gift": ("His father had this garden planted for his mother. A mating present.", "A"),
    "t_father": ("My father had this garden planted for my mother. It was a mating present.", "V"),
    "sg_boy": ("\"My favorite haunt as a boy,\" he said. I can see why.", "A"),
    "t_pool": (None, "X"),
    "t_fiddle": ("I can play a mean fiddle, you know.", "A"),
    "f_ships": (None, "A"),
    "f_knee": ("The damp's in my leg again. It'll pass.", "A"),
    "w_glade_truth": ("The birches look ordinary in daylight. They weren't.", "X"),
    "d_bite": ("He bit me. I can still feel it.", "X"),
}
KEEPER_PHASES = {"a_nephews": ph(5, 6)}
for _area, _l in LINES:
    if _l["id"] in KEEPER:
        _text, _canon = KEEPER[_l["id"]]
        if _text:
            _l["text"] = _text
        _l["canon"] = _canon
    if _l["id"] in KEEPER_PHASES:
        _l["phases"] = list(KEEPER_PHASES[_l["id"]])


# =============================================================================
# Who stands where (CastPresence). House spots are in house space (x, z) on the
# room's storey; cottage spots are relative to the act1_cottage_interior anchor.
# =============================================================================
SPOTS = []
CAST = "res://characters/%s/%s_model.tscn"
FAMILY = "res://creatures/family/%s.tscn"
PEOPLE = "res://creatures/people/scenes/%s.tscn"


def spot(sid, speaker, scene, region, x, z, phases, room="", anchor="", yaw=0.0, req=(), forbid=(), hours=None,
         wander=0.0, canon="X", notes=""):
    SPOTS.append(dict(id=sid, speaker=speaker, scene=scene, region=region, x=x, z=z, room=room, anchor=anchor,
                      yaw=yaw, phases=list(phases), req=list(req), forbid=list(forbid), hours=hours,
                      wander=wander, canon=canon, notes=notes))


# The family, in the cottage only while she lives there (ch1-4) [C].
spot("father_hearth", "father", FAMILY % "father", "cottage", 2.25, 0.95, HUMAN, anchor="act1_cottage_interior",
     yaw=-100.0, canon="C", notes="by his chair and carving stool, his leg toward the fire")
# In the sisters' room behind the partition (L38-2): the dresser is at interior
# (-3.35, -0.29) against the partition, the anchor at interior (-0.5, 0). She
# stands in front of it, 1.45 m clear of the bedroom door at (-2.65, -0.69).
spot("nesta_dresser", "nesta", FAMILY % "nesta", "cottage", -3.05, 0.45, HUMAN, anchor="act1_cottage_interior",
     yaw=0.0, canon="C", notes="by the dresser with her ribbon and comb, in the sisters' room")
spot("elain_table", "elain", FAMILY % "elain", "cottage", 1.8, -1.0, HUMAN, anchor="act1_cottage_interior",
     yaw=30.0, canon="C", notes="indoors all winter; she tends her garden in the milder months (Keeper)")
# The village at market (ch3) [C]: the Blessed, villagers, a peddler.
spot("blessed_square", "blessed", PEOPLE % "blessed", "village", 372.0, 2244.0, HUMAN, canon="C", wander=3.0,
     hours=(8.0, 18.0),
     notes="Children of the Blessed accost the sisters in the square")
spot("woman_stall", "human_woman", PEOPLE % "human_woman", "village", 387.5, 2265.3, HUMAN, wander=1.5,
     hours=(8.0, 17.0), notes="market stalls by day")
spot("man_well", "human_man", PEOPLE % "human_man", "village", 384.0, 2252.0, HUMAN, wander=2.0)
spot("elder_board", "human_elder", PEOPLE % "human_elder", "village", 386.0, 2240.0, HUMAN)
spot("youth_tavern", "human_youth", PEOPLE % "human_youth", "village", 408.0, 2222.0, HUMAN, wander=3.0)
spot("peddler_stall", "peddler", PEOPLE % "peddler", "village", 363.7, 2254.7, HUMAN, canon="C", hours=(8.0, 17.0),
     notes="peddlers bring border-town stories; one sold her the ash arrow")
spot("woman_return", "human_woman", PEOPLE % "human_woman", "village", 387.5, 2265.3, ph(7), wander=1.5)
spot("elder_return", "human_elder", PEOPLE % "human_elder", "village", 386.0, 2240.0, ph(7))
# The manor (ch6-28). Tamlin patrols and is often away [C]; Lucien is about by day.
spot("alis_dressing", "alis", PEOPLE % "alis", "manor_estate", 36.0, -66.5, COURT, room="dressing_room",
     hours=(7.0, 11.0), canon="C", notes="she dresses and bathes Feyre")
spot("alis_kitchen", "alis", PEOPLE % "alis", "manor_estate", 48.0, -62.0, COURT, room="svc_kitchen",
     hours=(11.0, 21.0), canon="X")
spot("lucien_stables", "lucien", CAST % ("lucien", "lucien"), "manor_estate", -112.0, -24.0, ph(2, 3),
     hours=(8.0, 13.0), canon="A", notes="hunts and patrols with her by day (ch9-11)")
spot("lucien_roses", "lucien", CAST % ("lucien", "lucien"), "manor_estate", -34.0, -118.0, ph(2, 6),
     hours=(13.0, 18.0), canon="X")
spot("lucien_drawing", "lucien", CAST % ("lucien", "lucien"), "manor_estate", -18.0, -40.0, COURT,
     room="drawing_room", hours=(18.0, 23.0), canon="X")
spot("tamlin_armory", "tamlin", CAST % ("tamlin", "tamlin"), "manor_estate", -36.0, -34.5, ph(2, 3),
     room="armory", hours=(7.0, 10.0), canon="A", notes="a warrior; arms before he rides out")
spot("tamlin_study", "tamlin", CAST % ("tamlin", "tamlin"), "manor_estate", -15.0, -66.0, COURT,
     room="tamlin_study", hours=(17.0, 21.0), canon="X")
spot("tamlin_garden", "tamlin", CAST % ("tamlin", "tamlin"), "manor_estate", 18.0, -160.0, WIDER,
     hours=(9.0, 13.0), canon="A", notes="the rose garden his father planted (ch19)")
spot("sentry_gate_w", "sentry", PEOPLE % "sentry_1", "manor_estate", -7.0, 292.0, COURT, yaw=0.0, canon="C",
     notes="High Fae sentries")
spot("sentry_gate_e", "sentry", PEOPLE % "sentry_2", "manor_estate", 7.0, 292.0, COURT, yaw=0.0, canon="C")
# The household, seen only once the glamour lifts (ch24) [C]: masked servants.
GL = ["glamour_lifted"]
spot("gardener_roses", "gardener", PEOPLE % "gardener_1", "manor_estate", -40.0, -130.0, ph(6), req=GL,
     wander=4.0, canon="C", notes="insect masks, iridescent wings, prune the hedges")
spot("gardener_hedge", "gardener", PEOPLE % "gardener_2", "manor_estate", 42.0, -165.0, ph(6), req=GL,
     wander=4.0, canon="C")
spot("cook_kitchen", "servant_cook", PEOPLE % "servant_cook", "manor_estate", 45.0, -58.0, ph(6),
     room="svc_kitchen", req=GL, canon="C")
spot("maid_upper", "servant_maid", PEOPLE % "servant_maid", "manor_estate", 3.0, -55.0, ph(6), room="upper_hall",
     req=GL, wander=2.0, canon="C")
spot("footman_hall", "servant_footman", PEOPLE % "servant_footman", "manor_estate", 6.0, -42.0, ph(6),
     room="entrance_hall", req=GL, canon="C")
spot("greenbrown_gallery", "fae_greenbrown", PEOPLE % "fae_greenbrown", "manor_estate", 26.0, -56.5, ph(6),
     room="gallery", req=GL, wander=3.0, canon="C", notes="green-and-brown skin, long limbs")
spot("longlimb_library", "fae_longlimb", PEOPLE % "fae_longlimb", "manor_estate", -31.0, -61.0, ph(6),
     room="library", req=GL, wander=2.0, canon="C")
spot("seamstress_sewing", "seamstress", PEOPLE % "seamstress", "manor_estate", 68.5, -37.5, ph(6),
     room="svc_sewing_room", req=GL)
spot("potion_stillroom", "potion_maker", PEOPLE % "potion_maker", "manor_estate", 69.0, -44.5, ph(6),
     room="svc_stillroom", req=GL)
# The fae village (wider court, [X] region).
FV = [("fae_mushroom", "cottages", -6, 4), ("fae_moth", "great_lantern_tree", 5, -3),
      ("fae_fox", "market", -5, 2), ("fae_hedgehog", "market", 4, 5), ("fae_pixie", "seamstress", 4, 3),
      ("fae_satyr", "village_mill", 6, 0), ("fae_rose", "market", 1, -6), ("fae_owl", "great_lantern_tree", -4, 4),
      ("fae_stag", "lantern_bridge", 0, 6), ("fae_nymph", "lantern_bridge", 3, -5),
      ("fae_birch", "cottages", 5, -4), ("fae_dryad", "potion_house", -5, -3)]
# Keeper (ch24): Tamlin's glamour covers his court, so before the lift only
# humanoid, glamoured folk are seen (the satyr, the High Fae revellers); the
# non-humanoid village fae appear once it lifts.
HUMANOID = ["fae_satyr"]
for fid, near, dx, dz in FV:
    x, z, _r = CP[near]
    if fid in HUMANOID:
        spot("%s_%s" % (fid, near), fid, PEOPLE % fid, "fae_village", x + dx, z + dz, WIDER, wander=2.5)
    else:
        spot("%s_%s" % (fid, near), fid, PEOPLE % fid, "fae_village", x + dx, z + dz, ph(6), req=GL, wander=2.5,
             notes="unseen (glamoured) before the lift, Keeper ch24")
for i, (near, dx, dz) in enumerate([("market", 6, -3), ("great_lantern_tree", -6, -2), ("lantern_bridge", -3, 4)]):
    x, z, _r = CP[near]
    spot("reveler_village_%d" % (i + 1), "reveler", PEOPLE % ("reveler_%d" % (i + 1)), "fae_village", x + dx,
         z + dz, ph(4, 5), hours=(8.0, 19.0), wander=2.5, notes="glamoured High Fae villagers before the lift")
# Revellers: Calanmai night on the hill [C], the Solstice meadow [C].
for i, (near, dx, dz) in enumerate([("drum_field", -8, 4), ("drum_field", 7, -5), ("stone_ring", 6, 6)]):
    x, z, _r = CP[near]
    spot("reveler_rite_%d" % (i + 1), "reveler", PEOPLE % ("reveler_%d" % (i + 1)), "hill_of_the_rite",
         x + dx, z + dz, ph(5), hours=(19.0, 5.0), wander=3.0, canon="C")
for i, (near, dx, dz) in enumerate([("long_tables", -6, 3), ("long_tables", 6, -2), ("musicians_bower", 5, 5)]):
    x, z, _r = CP[near]
    spot("reveler_solstice_%d" % (i + 1), "reveler", PEOPLE % ("reveler_%d" % (i + 1)), "solstice_meadow",
         x + dx, z + dz, ph(6), wander=3.0, canon="C")


# =============================================================================
# Writing
# =============================================================================
def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def psa(items):
    return "PackedStringArray(%s)" % ", ".join(q(i) for i in items)


def f(v):
    return repr(float(v))


EMOTION_WORDS = [("laugh", "laugh"), ("delighted", "laugh"), ("cutting", "contempt"), ("cold", "contempt"),
                 ("mean", "contempt"), ("ashamed", "pained"), ("scandalised", "surprise"), ("wistful", "tender"),
                 ("gentle", "tender"), ("tired", "weary"), ("defensive", "guarded"), ("flat", "guarded"),
                 ("afraid", "afraid"), ("frightened", "afraid"), ("shaking", "afraid"), ("serene", "happy"),
                 ("salesman", "smirk"), ("unblinking", "guarded")]
SPEAKER_EMOTION = {"lucien": "smirk", "tamlin": "guarded", "nesta": "contempt", "elain": "tender",
                   "father": "weary", "alis": "neutral", "blessed": "happy", "reveler": "laugh",
                   "court_fae": "happy", "gardener": "happy"}


def emotion_of(d):
    if d["inner"]:
        return "guarded" if "afraid" not in d["delivery"] and "frighten" not in d["delivery"] else "afraid"
    low = d["delivery"].lower()
    for word, emo in EMOTION_WORDS:
        if word in low:
            return emo
    return SPEAKER_EMOTION.get(d["speaker"], "neutral")


def line_block(i, d):
    hours = d["hours"] or (-1.0, -1.0)
    out = ['[sub_resource type="Resource" id="L%d"]' % i, 'script = ExtResource("1")',
           'id = &%s' % q(d["id"]), 'speaker = &%s' % q(d["speaker"]), 'who = %s' % q(d["who"]),
           'text = %s' % q(d["text"]), 'canon = %s' % q(d["canon"]), 'trigger = %d' % d["trig"],
           'where = &%s' % q(d["where"]), 'deed = &%s' % q(d["deed"]), 'phases = %s' % psa(d["phases"]),
           'require_flags = %s' % psa(d["req"]), 'forbid_flags = %s' % psa(d["forbid"]),
           'hour_from = %s' % f(hours[0]), 'hour_to = %s' % f(hours[1]),
           'once = %s' % ("true" if d["once"] else "false"), 'cooldown = %s' % f(d["cd"]),
           'priority = %d' % d["pr"], 'inner = %s' % ("true" if d["inner"] else "false"),
           'follow_up = &%s' % q(d["follow"]), 'delivery = %s' % q(d["delivery"]),
           'emotion = &%s' % q(emotion_of(d))]
    return "\n".join(out) + "\n"


def place_block(i, p):
    pid, region, x, z, r = p
    return "\n".join(['[sub_resource type="Resource" id="P%d"]' % i, 'script = ExtResource("2")',
                      'id = &%s' % q(pid), 'region = &%s' % q(region), 'at = Vector2(%s, %s)' % (f(x), f(z)),
                      'radius = %s' % f(r)]) + "\n"


def write_books():
    d = os.path.join(OUT, "lines")
    os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        if old.endswith(".tres"):
            os.remove(os.path.join(d, old))
    areas = []
    for area, _ in LINES:
        if area not in areas:
            areas.append(area)
    for area in PLACES:
        if area not in areas:
            areas.append(area)
    for area in areas:
        ls = [l for a, l in LINES if a == area]
        ps = PLACES.get(area, [])
        body = ['[gd_resource type="Resource" script_class="DialogueBook" format=3]', "",
                '[ext_resource type="Script" path="res://systems/dialogue/dialogue_line.gd" id="1"]',
                '[ext_resource type="Script" path="res://systems/dialogue/dialogue_place.gd" id="2"]',
                '[ext_resource type="Script" path="res://systems/dialogue/dialogue_book.gd" id="3"]', ""]
        for i, l in enumerate(ls):
            body.append(line_block(i, l))
        for i, p in enumerate(ps):
            body.append(place_block(i, p))
        body += ["[resource]", 'script = ExtResource("3")', "area = &%s" % q(area),
                 'lines = Array[ExtResource("1")]([%s])' % ", ".join('SubResource("L%d")' % i for i in range(len(ls))),
                 'places = Array[ExtResource("2")]([%s])' % ", ".join('SubResource("P%d")' % i for i in range(len(ps))),
                 ""]
        open(os.path.join(d, "%s.tres" % area), "w").write("\n".join(body))


def write_roster():
    body = ['[gd_resource type="Resource" script_class="PresenceRoster" format=3]', "",
            '[ext_resource type="Script" path="res://systems/dialogue/presence_spot.gd" id="1"]',
            '[ext_resource type="Script" path="res://systems/dialogue/presence_roster.gd" id="2"]', ""]
    for i, s in enumerate(SPOTS):
        hours = s["hours"] or (-1.0, -1.0)
        body.append("\n".join([
            '[sub_resource type="Resource" id="S%d"]' % i, 'script = ExtResource("1")', 'id = &%s' % q(s["id"]),
            'speaker = &%s' % q(s["speaker"]), 'scene = %s' % q(s["scene"]), 'region = &%s' % q(s["region"]),
            'at = Vector2(%s, %s)' % (f(s["x"]), f(s["z"])), 'room = &%s' % q(s["room"]),
            'yaw_deg = %s' % f(s["yaw"]), 'anchor = &%s' % q(s["anchor"]), 'phases = %s' % psa(s["phases"]),
            'require_flags = %s' % psa(s["req"]), 'forbid_flags = %s' % psa(s["forbid"]),
            'hour_from = %s' % f(hours[0]), 'hour_to = %s' % f(hours[1]), 'wander = %s' % f(s["wander"]),
            'canon = %s' % q(s["canon"]), 'notes = %s' % q(s["notes"])]) + "\n")
    body += ["[resource]", 'script = ExtResource("2")',
             'spots = Array[ExtResource("1")]([%s])' % ", ".join('SubResource("S%d")' % i for i in range(len(SPOTS))),
             ""]
    open(os.path.join(OUT, "presence.tres"), "w").write("\n".join(body))


def _sheet_dir():
    """The sheet lives beside a .gdignore so Godot doesn't import the CSV as a translation."""
    d = os.path.join(OUT, "sheet")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, ".gdignore"), "w").write("")
    return open(os.path.join(d, "line_sheet.csv"), "w", newline="")


def write_sheet():
    with _sheet_dir() as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["line_id", "speaker", "who", "text", "canon", "inner", "trigger", "where", "deed", "phases",
                    "delivery", "audio_file"])
        names = {v: k for k, v in TRIG.items()}
        for area, l in LINES:
            w.writerow([l["id"], l["speaker"], l["who"], l["text"], l["canon"], "yes" if l["inner"] else "",
                        names[l["trig"]], l["where"], l["deed"], " ".join(l["phases"]), l["delivery"],
                        "audio/voice/%s.ogg" % l["id"]])


def check():
    ids = [l["id"] for _, l in LINES]
    dup = {i for i in ids if ids.count(i) > 1}
    assert not dup, "duplicate line ids: %s" % sorted(dup)
    for _, l in LINES:
        if l["follow"]:
            assert l["follow"] in ids, l["id"]
    for k in list(KEEPER) + list(KEEPER_PHASES):
        assert k in ids, "Keeper correction for unknown line %s" % k
    sids = [s["id"] for s in SPOTS]
    assert len(sids) == len(set(sids)), "duplicate spot ids"


if __name__ == "__main__":
    check()
    write_books()
    write_roster()
    write_sheet()
    speakers = sorted({l["speaker"] for _, l in LINES})
    print("lines %d, places %d, spots %d, speakers %d" % (len(LINES), sum(len(v) for v in PLACES.values()),
                                                         len(SPOTS), len(speakers)))
