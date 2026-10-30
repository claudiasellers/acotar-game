#!/usr/bin/env python3
"""Writes data/phases/spring_court_phases.tres from the Keeper's chapter mapping
(lore/07-story/timeline-overview.md). Run from the repo root:
    python3 tools/story/gen_phases.py data/phases/spring_court_phases.tres
"""
import sys
P = [
 ("p0_winter","Winter and the cottage","Ch 1-3. The wolf in the deep woods, the venison feast, the walk to the village, the pelt sold to the mercenary. food_secured and isaac_met are optional deeds.",
  ["human_realm_winter","cottage","hunting_forest","village","wall_seam","workshop"],["wolf_killed","pelt_sold"]),
 ("p1_wolf_and_crossing","The beast and the crossing","Ch 3-5. The beast at the door (life for a life), the ride on the white horse, the enchanted sleep, waking at the gate.",
  ["border_woods"],["beast_claim_accepted","wall_crossed"]),
 ("p2_grounds","The grounds","Ch 6-11. Arrival, the first dinner (held at the table until she eats), the curtain trap, the hunt with Lucien and the Bogge, the puca at the gate.",
  ["manor_estate","manor_grounds","manor_house"],["first_dinner_eaten","curtain_trap_set","bogge_survived","puca_resisted"]),
 ("p3_house_and_woods","The house and the woods","Ch 12-17. Bandaging Tamlin's hand, mapping the halls, the study mural, the Suriel, the naga, the wingless Summer faerie.",
  ["manor_study","suriel_glade","eastern_woods","blighted_reaches"],["tamlin_wound_dressed","manor_map_drawn","study_mural_seen","suriel_bound","naga_survived","summer_faerie_comforted"]),
 ("p4_wider_court","The wider court","Ch 18-19. The pool of starlight, the gallery and the painting room, the first painting, the Attor in the garden.",
  ["manor_gallery","starlight_glen","rosewild","fae_village","western_fells","blossom_vale"],["starlight_pool_found","gallery_opened","first_painting","attor_evaded"]),
 ("p5_calanmai","Calanmai","Ch 20-22. Fire Night, the cave, the stranger, the bite in the kitchen hall, the paintings shown.",
  ["hill_of_the_rite"],["calanmai_attended","stranger_met","bite_endured","paintings_shown"]),
 ("p6_blight_tightens","The blight tightens","Ch 23-27. The glamour lifted, the head in the fountain, the Summer Solstice, Rhysand's visit, sent home.",
  ["solstice_meadow"],["glamour_lifted","fountain_head_found","solstice_danced","rhysand_faced","sent_home"]),
 ("p7_return_home","Return to the human realm","Ch 28-31. The family's new house, Nesta's truth, the Beddor fire, back across the Wall.",
  ["human_realm_spring","archeron_estate"],["nesta_truth_heard","beddor_fire_learned","wall_recrossed"]),
 ("p8_the_pass","The pass","Ch 32. The ruined manor, Alis tells her everything, she sets out for Under the Mountain. The exit marks the end of this world.",
  ["the_pass"],["alis_truth_heard","departed_for_mountain"]),
]
out = ['[gd_resource type="Resource" script_class="PhaseSet" format=3]','',
 '[ext_resource type="Script" path="res://data/phases/phase_def.gd" id="1_cae22"]',
 '[ext_resource type="Script" path="res://data/phases/exit_condition.gd" id="2_1vgil"]',
 '[ext_resource type="Script" path="res://data/phases/phase_set.gd" id="3_ox3ey"]','']
ids=[]
for i,(pid,name,notes,regions,flags) in enumerate(P):
    nxt = P[i+1][0] if i+1 < len(P) else ""
    q=lambda l: ", ".join('"%s"'%x for x in l)
    out += ['[sub_resource type="Resource" id="Exit_%d"]'%i,'script = ExtResource("2_1vgil")','flags = PackedStringArray(%s)'%q(flags),'',
      '[sub_resource type="Resource" id="Phase_%d"]'%i,'script = ExtResource("1_cae22")','id = &"%s"'%pid,'display_name = "%s"'%name,
      'notes = "%s"'%notes,'unlocked_regions = PackedStringArray(%s)'%q(regions),'locked_regions = PackedStringArray()',
      'exit_condition = SubResource("Exit_%d")'%i]
    if nxt: out.append('next_phase = &"%s"'%nxt)
    out.append('')
    ids.append('SubResource("Phase_%d")'%i)
out += ['[resource]','script = ExtResource("3_ox3ey")','world_id = &"spring_court"','start_phase = &"p0_winter"',
 'phases = Array[ExtResource("1_cae22")]([%s])'%", ".join(ids),'']
open(sys.argv[1],'w').write("\n".join(out))
