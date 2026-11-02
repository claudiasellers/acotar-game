"""Expression shape keys for any head built on Feyre's face kit (lane L36).

    import face_keys; face_keys.add_expression_keys(body_obj)

Feyre's body build (tools/blender/feyre/build_feyre.py) gives every cast head
17 base keys: nourished, blink_L/R, jaw_open, smile, frown, brow_up,
brow_down, squint, cheek_puff, lips_pucker and the visemes.  This module adds
the expression set on top, without touching build_feyre or a cast member's
sculpt: it reads each face's own landmarks from the base keys (the eyes from
blink_L/R, the mouth line and lip sides from vis_MBP, the mouth corners from
smile, the brows from brow_up), so the same code fits Tamlin's long jaw and
Alis's small mouth, and it re-runs cleanly after a face is re-sculpted.

Conventions are the kit's: Blender Z up, the face looks down -Y, and _L is the
character's own left (+X).  Shape-key values are 0..1 and sum with the base
keys; the neutral face (all keys 0) never changes.

The key names are the contract (docs/contracts/faces.md) and are listed in
EXPRESSION_KEYS in order.  Deterministic.
"""

import numpy as np

BASE_KEYS = ("nourished", "blink_L", "blink_R", "jaw_open", "smile", "frown", "brow_up", "brow_down", "squint",
             "cheek_puff", "lips_pucker", "vis_AA", "vis_E", "vis_O", "vis_U", "vis_MBP", "vis_FV")

EXPRESSION_KEYS = (
    "smile_L", "smile_R",            # one-sided smile: the smirk
    "frown_L", "frown_R",            # one mouth corner turned down
    "sneer_L", "sneer_R",            # upper lip and nose wing lift on one side
    "lip_press",                     # lips thinned into a tight line
    "jaw_clench",                    # jaw shut hard, masseters bulge
    "mouth_stretch",                 # fear grimace: corners pulled wide and down
    "eyes_wide_L", "eyes_wide_R",    # lids open past rest
    "squint_L", "squint_R",          # one-sided narrowing
    "brow_down_L", "brow_down_R",
    "brow_up_L", "brow_up_R",
    "brow_inner_up",                 # worry / pleading
    "cheek_raise",                   # the cheeks of a real smile
    "mouth_side_L", "mouth_side_R",  # whole mouth shifted to one side
    "chin_raise",                    # chin bunched up, lower lip pushed up: holding back tears
    "lips_part",                     # lips apart, jaw still (awe, fear, breath); shows teeth once the mouth is cut
)

# Feyre's reference proportions (tools/blender/feyre/feyre_shape.py): the
# offsets below are authored on her face and scaled per head.
REF_EYE_X = 0.0365
REF_EYE_TO_MOUTH = 0.0615


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _gauss(P, c, sig):
    d = (P - np.asarray(c, float)) / np.asarray(sig, float)
    return np.exp(-np.sum(d * d, axis=1))


def _co(me, kb):
    a = np.empty(len(me.vertices) * 3)
    kb.data.foreach_get("co", a)
    return a.reshape(-1, 3)


def _centroid(P, w):
    w = np.asarray(w, float)
    return (P * w[:, None]).sum(0) / max(w.sum(), 1e-9)


def _vnormals(me):
    a = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", a)
    return a.reshape(-1, 3)


def _group_weights(obj, names):
    """Per-vertex summed weight of the named vertex groups."""
    idx = {obj.vertex_groups[n].index for n in names if n in obj.vertex_groups}
    w = np.zeros(len(obj.data.vertices))
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in idx:
                w[v.index] += g.weight
    return np.clip(w, 0.0, 1.0)


class Face:
    """Landmarks of one head, measured from its base shape keys."""

    def __init__(self, obj):
        me = obj.data
        kb = me.shape_keys.key_blocks
        missing = [k for k in ("blink_L", "blink_R", "smile", "vis_MBP", "brow_up", "jaw_open", "squint",
                               "brow_down") if k not in kb]
        if missing:
            raise RuntimeError("%s lacks base keys %s" % (obj.name, missing))
        self.P = _co(me, kb["Basis"])
        self.N = _vnormals(me)
        self.d = {k: _co(me, kb[k]) - self.P for k in BASE_KEYS if k in kb}
        P = self.P
        mag = {k: np.linalg.norm(v, axis=1) for k, v in self.d.items()}
        self.eye = {}
        for side, k in ((1, "blink_L"), (-1, "blink_R")):
            m = mag[k]
            self.eye[side] = _centroid(P, m * (m > 0.2 * m.max()))
        mb = mag["vis_MBP"]
        lip_w = mb * (mb > 0.15 * mb.max())
        self.mouth = _centroid(P, lip_w)
        sm = mag["smile"]
        sw = sm * (sm > 0.5 * sm.max())
        self.corner_x = float(_centroid(np.abs(P), sw)[0])
        bu = mag["brow_up"]
        self.brow = _centroid(P, bu * (bu > 0.5 * bu.max()))
        self.sh = (self.eye[1][0] - self.eye[-1][0]) / (2.0 * REF_EYE_X)
        eye_z = 0.5 * (self.eye[1][2] + self.eye[-1][2])
        self.sv = (eye_z - self.mouth[2]) / REF_EYE_TO_MOUTH
        self.eye_z = eye_z
        # The head: everything the base face keys touch, plus the Head/Jaw-weighted skin.
        self.head = _group_weights(obj, ("Head", "Jaw")) * (P[:, 2] > self.mouth[2] - 0.09 * self.sv)
        # Front of the face: ahead of the eyes' depth, fading to the ears.
        face_y = 0.5 * (self.eye[1][1] + self.eye[-1][1])
        self.front = _smooth(face_y + 0.045 * self.sh, face_y + 0.01 * self.sh, P[:, 1]) * self.head
        # Lip sides from vis_MBP: it pulls the upper lip down and the lower lip up.
        dz = self.d["vis_MBP"][:, 2]
        self.lip = (mb / max(mb.max(), 1e-9))
        self.upper_lip = self.lip * (dz < 0)
        self.lower_lip = self.lip * (dz > 0)
        # Head half-width at the mouth (for the masseters).
        band = (np.abs(P[:, 2] - self.mouth[2]) < 0.012 * self.sv) & (self.head > 0.5)
        self.cheek_x = float(np.abs(P[band, 0]).max()) if band.any() else 0.07 * self.sh
        # Once mouth.cut() has opened the lips, everything below the cut (the lower lip's own edge too)
        # is the jaw side, so lip moves can part the lips.
        z_cut = obj.get("mouth_z")
        self.below = (P[:, 2] < z_cut - 1e-4) if z_cut is not None else (P[:, 2] < self.mouth[2])
        att = obj.data.attributes.get("mouth_side")
        if z_cut is not None and att is not None and len(att.data) == len(P):
            side = np.empty(len(P), dtype=np.int32)
            att.data.foreach_get("value", side)
            self.below = (P[:, 2] < z_cut - 1e-4) | (side == -1)
            # the lips by side of the cut, not by vis_MBP's own split (which sits a hair off the groove)
            near = self.lip > 0
            self.upper_lip = self.lip * near * ~self.below
            self.lower_lip = self.lip * near * self.below
        side_band = band & (np.abs(P[:, 0]) > 0.85 * self.cheek_x)
        self.cheek_y = float(P[side_band, 1].mean()) if side_band.any() else face_y + 0.06

    def side(self, s):
        """Soft left (+1) / right (-1) split across the midline."""
        w = _smooth(-0.006 * self.sh, 0.006 * self.sh, self.P[:, 0])
        return w if s > 0 else 1.0 - w

    def g(self, c, sig, front=True):
        w = _gauss(self.P, c, sig)
        return w * (self.front if front else self.head)


def deltas(f):
    """Name -> (n, 3) delta array for every expression key."""
    P, sh, sv = f.P, f.sh, f.sv
    mz, my = f.mouth[2], f.mouth[1]
    hw = f.corner_x
    out = {}
    for s, suf in ((1, "L"), (-1, "R")):
        side = f.side(s)[:, None]
        # one-sided smile, built on the face's own corner (the base "smile" is too shy to read at
        # game distance): the corner rides up, out and back round the teeth, the upper lip stretches
        # thin, and the skin beside the corner bunches forward (the nasolabial fold).
        d = 1.2 * f.d["smile"] * side
        c = f.g((s * hw, 0, mz), (0.011 * sh, 1, 0.009 * sv))
        d[:, 0] += 0.0040 * sh * s * c
        d[:, 2] += 0.0055 * sv * c
        d[:, 1] += 0.0025 * sh * c
        ul = f.upper_lip * side[:, 0]
        d[:, 2] += 0.0012 * sv * ul
        fold = f.g((s * (hw + 0.010 * sh), 0, mz + 0.008 * sv), (0.008 * sh, 1, 0.012 * sv))
        d += f.N * (0.0022 * sh * fold)[:, None]
        out["smile_" + suf] = d
        # one corner down: the corner drops and tucks, the lip below it pushes out a little
        d = 1.3 * f.d["frown"] * side
        c = f.g((s * hw, 0, mz - 0.002 * sv), (0.010 * sh, 1, 0.009 * sv))
        d[:, 2] -= 0.0055 * sv * c
        d[:, 0] -= 0.0012 * sh * s * c
        d[:, 1] += 0.0010 * sh * c
        jowl = f.g((s * (hw + 0.006 * sh), 0, mz - 0.012 * sv), (0.009 * sh, 1, 0.008 * sv))
        d += f.N * (0.0014 * sh * jowl)[:, None]
        out["frown_" + suf] = d
        out["squint_" + suf] = 1.5 * f.d["squint"] * side
        out["brow_down_" + suf] = 1.6 * f.d["brow_down"] * side
        out["brow_up_" + suf] = 1.5 * f.d["brow_up"] * side
        # eyes wide: the blink rotation run backwards, a third of the way (upper lid lifts, lower drops)
        out["eyes_wide_" + suf] = -0.38 * f.d["blink_" + suf]
        # sneer: upper lip lifts beside the philtrum, nose wing hikes up and in
        d = np.zeros_like(P)
        lip = f.g((s * 0.55 * hw, 0, mz + 0.0055 * sv), (0.0085 * sh, 1, 0.006 * sv)) * (1.0 - f.below)
        d[:, 2] += 0.0070 * sv * lip
        d[:, 1] -= 0.0016 * sh * lip
        wing = f.g((s * 0.017 * sh, 0, mz + 0.021 * sv), (0.008 * sh, 1, 0.008 * sv))
        d[:, 2] += 0.0045 * sv * wing
        d[:, 0] -= 0.0010 * sh * s * wing
        crn = f.g((s * hw, 0, mz), (0.008 * sh, 1, 0.007 * sv))
        d[:, 2] += 0.0012 * sv * crn
        out["sneer_" + suf] = d
        # whole mouth shifted toward this side
        d = np.zeros_like(P)
        d[:, 0] += 0.0055 * sh * s * f.g((0, 0, mz), (1.7 * hw, 1, 0.014 * sv))
        out["mouth_side_" + suf] = d
    # lip press: the lips' own M/B/P closure, harder, rolled in and narrowed
    d = 1.6 * f.d["vis_MBP"]
    band = f.g((0, 0, mz), (1.3 * hw, 1, 0.010 * sv))
    d[:, 1] += 0.0024 * sh * band
    d[:, 0] -= 0.12 * (P[:, 0]) * f.g((0, 0, mz), (1.4 * hw, 1, 0.009 * sv))
    out["lip_press"] = d
    # jaw clench: jaw shut past rest, masseters swell, lips set
    d = -0.10 * f.d["jaw_open"] + 0.35 * f.d["vis_MBP"]
    for s in (1, -1):
        m = _gauss(P, (s * f.cheek_x, f.cheek_y - 0.006 * sh, mz - 0.006 * sv), (0.013 * sh, 0.02 * sh, 0.016 * sv))
        d += f.N * (0.0034 * sh * m * f.head)[:, None]
    out["jaw_clench"] = d
    # mouth stretch: fear; corners pulled wide, back and down, lower lip drawn down
    d = np.zeros_like(P)
    for s in (1, -1):
        c = f.g((s * hw, 0, mz), (0.011 * sh, 1, 0.010 * sv))
        d[:, 0] += 0.0060 * sh * s * c
        d[:, 2] -= 0.0045 * sv * c
        d[:, 1] += 0.0010 * sh * c
    d[:, 2] -= 0.0025 * sv * f.lower_lip
    out["mouth_stretch"] = d
    # inner brows up and together
    d = np.zeros_like(P)
    for s in (1, -1):
        b = f.g((s * 0.012 * sh, 0, f.brow[2] - 0.002 * sv), (0.012 * sh, 1, 0.011 * sv))
        d[:, 2] += 0.0070 * sv * b
        d[:, 0] -= 0.0016 * sh * s * b
    out["brow_inner_up"] = d
    # cheeks lift under the eyes
    d = np.zeros_like(P)
    for s in (1, -1):
        c = f.g((s * 0.042 * sh, 0, f.eye_z - 0.030 * sv), (0.016 * sh, 1, 0.013 * sv))
        d[:, 2] += 0.0040 * sv * c
        d[:, 1] -= 0.0018 * sh * c
    out["cheek_raise"] = d
    # chin raise: the mentalis bunches, the lower lip pushes up and out
    d = np.zeros_like(P)
    c = f.g((0, 0, mz - 0.022 * sv), (0.014 * sh, 1, 0.010 * sv))
    d[:, 2] += 0.0036 * sv * c
    d[:, 1] -= 0.0024 * sh * c
    d[:, 2] += 0.0020 * sv * f.lower_lip
    d[:, 1] -= 0.0020 * sh * f.lower_lip
    out["chin_raise"] = d
    # lips part: upper lip up, lower lip down, the jaw stays
    d = np.zeros_like(P)
    d[:, 2] += 0.0026 * sv * f.upper_lip * (1.0 - f.below)
    d[:, 2] -= 0.0032 * sv * f.lower_lip * f.below
    d[:, 1] += 0.0006 * sh * f.lip
    out["lips_part"] = d
    return {k: out[k] for k in EXPRESSION_KEYS}


def _set_key(obj, name, co):
    kb = obj.data.shape_keys.key_blocks
    sk = kb.get(name) or obj.shape_key_add(name=name, from_mix=False)
    sk.data.foreach_set("co", np.ascontiguousarray(co, dtype=np.float64).ravel())
    sk.value = 0.0
    sk.slider_min, sk.slider_max = 0.0, 1.0
    return sk


def add_expression_keys(body):
    """Append (or refresh) EXPRESSION_KEYS on the body mesh.  Returns {name: max displacement (m)}."""
    f = Face(body)
    report = {}
    for name, d in deltas(f).items():
        _set_key(body, name, f.P + d)
        report[name] = float(np.linalg.norm(d, axis=1).max())
    return f, report


FACE_BASE_KEYS = tuple(k for k in BASE_KEYS if k != "nourished")


def transfer_keys(body, f, other, names=EXPRESSION_KEYS, force=False):
    """Copy face keys onto a mesh that rides the face: each vertex takes the delta of the nearest body
    vertex.  By default only meshes that already carry the base face keys are touched (Lucien's scar);
    force=True gives a rider such as the father's beard the base face keys too (names + FACE_BASE_KEYS)."""
    sk = other.data.shape_keys
    if not force and (sk is None or ("jaw_open" not in sk.key_blocks and "blink_L" not in sk.key_blocks)):
        return 0
    if sk is None:
        other.shape_key_add(name="Basis", from_mix=False)
    if force:
        names = tuple(FACE_BASE_KEYS) + tuple(n for n in names if n not in FACE_BASE_KEYS)
    from mathutils.kdtree import KDTree
    tree = KDTree(len(f.P))
    for i, p in enumerate(f.P):
        tree.insert(p, i)
    tree.balance()
    kb = other.data.shape_keys.key_blocks
    Q = _co(other.data, kb["Basis"])
    near = np.array([tree.find(q)[1] for q in Q])
    D = deltas(f)
    D.update(f.d)
    for n in names:
        _set_key(other, n, Q + D[n][near])
    return len(names)
