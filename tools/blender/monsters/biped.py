"""Monster kit, part 3: key-pose authoring for anything on the biped names
(pelvis, spine.., chest, neck.., head, arms, legs).

A clip is a short table of key poses. Each key is (time, {changes}) and a
posture is a flat dict of numbers and points, so a key only states what
changes; everything else carries over from the key before. Keys(...) blends
them, apply() turns a posture into a rig.Pose. A clip function can then add
motion that is easier to state as a formula (breath, a tremble, a tongue).

Posture fields (degrees, metres; r/l suffix = the creature's right/left):
  lean, drop, sway, fwd, bob     the carriage: forward lean shared over hips and
                                 spine, hips sunk, side and fore-aft shift
  body_pitch/yaw/roll            turns the whole body about the hips (falling, lying)
  bend, spine_yaw, spine_roll    extra spine curl / twist / side bend
  level                          0..1: how much the neck undoes the lean to keep the head level
  neck_up, neck_yaw, neck_roll   the neck, on top of that
  head_up, head_yaw, head_roll   the head alone
  stretch                        0..1: the neck's extension (15% at 1)
  jaw                            degrees open
  hc_r/l                         wrist, where it would be at rest, carried by the chest
  hw_r/l, hmix_r/l               wrist fixed in creature space; hmix 1 = fully fixed
  aim_r/l, pole_r/l              finger direction / elbow direction (creature space), or None
  curl_r/l, spread_r/l           fingers
  f_r/l                          planted ball of the foot, as an offset from its rest spot
  fc_r/l, fmix_r/l               ball carried by the pelvis (offset from rest); fmix 1 = fully carried
  heel_r/l, toe_r/l, foot_yaw    metatarsal angle (None = rest), toe lift, turn-out
  knee_r/l                       knee direction, carried by the pelvis, or None (forward)
  ground                         0..1: settle the body onto the ground
  any other key starting "k_"    a shape key value (k_threat, k_blink...)
"""

from mathutils import Vector

import rig

BASE = dict(
    lean=0.0, drop=0.0, sway=0.0, fwd=0.0, bob=0.0,
    body_pitch=0.0, body_yaw=0.0, body_roll=0.0,
    bend=0.0, spine_yaw=0.0, spine_roll=0.0, pelvis_roll=0.0, chest_roll=0.0,
    level=1.0, neck_up=0.0, neck_yaw=0.0, neck_roll=0.0, head_up=0.0, head_yaw=0.0, head_roll=0.0,
    stretch=0.0, jaw=0.0,
    hw_r=(0, 0, 0), hw_l=(0, 0, 0), hmix_r=0.0, hmix_l=0.0,
    aim_r=None, aim_l=None, pole_r=None, pole_l=None,
    curl_r=0.3, curl_l=0.3, spread_r=0.3, spread_l=0.3,
    f_r=(0, 0, 0), f_l=(0, 0, 0), fc_r=(0, 0, 0), fc_l=(0, 0, 0), fmix_r=0.0, fmix_l=0.0,
    heel_r=None, heel_l=None, knee_r=None, knee_l=None, toe_r=0.0, toe_l=0.0, foot_yaw=8.0,
    ground=0.0,
)

EASES = dict(smooth=rig.smooth, lin=rig.clamp01, out=rig.ease_out, snap=lambda x: rig.ease_out(x, 3.0),
             slow=lambda x: rig.ease_in(x, 2.0), whip=lambda x: rig.ease_in(x, 3.0))


def _mix(a, b, t):
    if a is None or b is None:
        return b if t > 0.5 else a
    if isinstance(a, (tuple, list, Vector)):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    if isinstance(a, str) or isinstance(b, str):
        return b if t > 0.5 else a
    return a + (b - a) * t


class Keys:
    """keys: [(time, {changes}), ...] or (time, {changes}, ease). The ease
    names how the pose is reached: smooth (default), lin, out, snap (fast
    then settling), slow, whip (held, then all at once)."""

    def __init__(self, base, keys):
        self.times, self.full, self.eases = [], [], []
        cur = dict(base)
        for k in keys:
            t, changes = k[0], k[1]
            cur = dict(cur)
            cur.update(changes)
            self.times.append(t)
            self.full.append(cur)
            self.eases.append(k[2] if len(k) > 2 else "smooth")
        self.duration = self.times[-1]

    def __call__(self, t):
        ts = self.times
        if t <= ts[0]:
            return dict(self.full[0])
        if t >= ts[-1]:
            return dict(self.full[-1])
        i = max(j for j in range(len(ts)) if ts[j] <= t)
        a, b = self.full[i], self.full[i + 1]
        u = EASES[self.eases[i + 1]]((t - ts[i]) / (ts[i + 1] - ts[i]))
        return {k: _mix(a[k], b[k], u) for k in b}


def apply(r, d, spine, neck):
    """A posture dict -> rig.Pose. `spine` and `neck` are the bone chains."""
    p = rig.Pose()
    lean = d["lean"]
    p.body(loc=(d["sway"], d["fwd"] + 0.02 * lean / 14.0, -d["drop"] + d["bob"]),
           pitch=lean * 0.45 + d["body_pitch"], yaw=d["body_yaw"], roll=d["body_roll"])
    p.spine(spine, pitch=lean * 0.55 + d["bend"], yaw=d["spine_yaw"], roll=d["spine_roll"])
    if d["pelvis_roll"]:
        p.turn("pelvis", roll=d["pelvis_roll"])
    if d["chest_roll"]:
        p.turn(spine[-1], roll=d["chest_roll"])
    undo = (lean + d["bend"]) * d["level"]
    p.spine(neck, pitch=-undo * 0.55 - d["neck_up"], yaw=d["neck_yaw"], roll=d["neck_roll"])
    p.turn("head", pitch=-undo * 0.45 - d["head_up"], yaw=d["head_yaw"], roll=d["head_roll"])
    if d["stretch"]:
        for b in neck[-1:] + ("head",):
            par = r.parent[b]
            p.stretch(b, (r.tail[par] - r.head[par]) * (0.15 * d["stretch"]))
    if d["jaw"]:
        p.turn("jaw", pitch=d["jaw"])
    for side in ("r", "l"):
        s = rig.side_sign(side)
        mix = d[f"hmix_{side}"]
        aim, pole = d[f"aim_{side}"], d[f"pole_{side}"]
        p.hand(side, pos=d[f"hw_{side}"] if mix > 0.0 else None, carried=d[f"hc_{side}"], mix=1.0 - mix,
               aim=aim, pole=pole if pole is not None else (s * 0.8, -1.0, 0.1))
        p.fingers(side, curl=d[f"curl_{side}"], spread=d[f"spread_{side}"])
        rest = r.rest_ball(side)
        fm = d[f"fmix_{side}"]
        p.foot(side, ball=rest + Vector(d[f"f_{side}"]) if fm < 1.0 else None,
               carried=rest + Vector(d[f"fc_{side}"]) if fm > 0.0 else None, mix=fm,
               heel=d[f"heel_{side}"], toe=d[f"toe_{side}"], yaw=d["foot_yaw"], knee=d[f"knee_{side}"])
    if d["ground"]:
        p.rest_on_ground(d["ground"])
    for k, v in d.items():
        if k.startswith("k_") and v:
            p.key(k[2:], v)
    return p


def mirrored(d):
    """The same posture with left and right swapped."""
    out = {}
    for k, v in d.items():
        k2 = k[:-2] + ("_l" if k.endswith("_r") else "_r") if k.endswith(("_r", "_l")) else k
        if isinstance(v, (tuple, list)) and k.split("_")[0] in ("hc", "hw", "f", "fc", "aim", "pole", "knee"):
            v = (-v[0], v[1], v[2])
        if k in ("sway", "body_yaw", "body_roll", "spine_yaw", "spine_roll", "pelvis_roll", "chest_roll",
                 "neck_yaw", "neck_roll", "head_yaw", "head_roll"):
            v = -v
        out[k2] = v
    return out
