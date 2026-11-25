"""Monster kit, part 2: the skeleton, the skin weights and the clip author.

A monster's generator describes its bones (names follow bestiary §1.3 and
docs/contracts/creature_motion.md), then writes each clip as a function of
time that returns a Pose: trunk rotations in the creature's own axes, and
world-space targets for feet and hands. The solver here does the rest:

  - two-bone IK with a pole for arms and legs (digitigrade legs get the hock
    from the authored heel angle, so the ball of the foot lands exactly on its
    target);
  - a hip drop when a target is out of reach, so a planted foot never lifts;
  - one key per bone per frame at 30 fps, each clip on its own NLA track (the
    glTF exporter writes one animation per track).

Gaits are authored at a native ground speed: a planted foot moves back at
exactly that speed, so the game can play the clip at speed / native and the
feet do not slide. gait() measures the slide and returns it.

Angles are degrees. rot(pitch, yaw, roll): pitch > 0 bends forward (nose
down), yaw > 0 turns to the creature's left, roll > 0 leans to its right.
Axes: +y forward, +z up, +x the creature's right. Sides are "r" and "l".
"""

import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

import kit

FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


# ------------------------------------------------------------------ curves

def clamp01(x):
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def seg(t, a, b):
    """0 before a, 1 after b, linear between."""
    return clamp01((t - a) / (b - a)) if b > a else float(t >= a)


def smooth(x):
    x = clamp01(x)
    return x * x * (3.0 - 2.0 * x)


def ease_in(x, p=2.0):
    return clamp01(x) ** p


def ease_out(x, p=2.0):
    return 1.0 - (1.0 - clamp01(x)) ** p


def pulse(t, a, peak, b):
    """0 at a, 1 at peak, 0 at b (smooth both ways)."""
    if t <= a or t >= b:
        return 0.0
    return smooth((t - a) / (peak - a)) if t < peak else smooth((b - t) / (b - peak))


def ring(t, t0, amp, freq, damp):
    """A damped wobble starting at t0."""
    if t < t0:
        return 0.0
    return amp * math.exp(-damp * (t - t0)) * math.sin(2 * math.pi * freq * (t - t0))


def lerp(a, b, t):
    return a + (b - a) * t


def wave(t, period, phase=0.0):
    return math.sin(2 * math.pi * (t / period + phase))


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    return (Quaternion(Z, math.radians(yaw)) @ Quaternion(X, math.radians(-pitch))
            @ Quaternion(Y, math.radians(roll)))


def side_sign(side):
    return 1.0 if side == "r" else -1.0


# ------------------------------------------------------------------ skeleton

def build_armature(name, bones):
    """bones: [(name, head, tail, parent, deform)] in parent-first order."""
    arm_data = bpy.data.armatures.new(name + "_rig")
    arm = bpy.data.objects.new(name + "_rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    kit.activate(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent, deform in bones:
        b = arm_data.edit_bones.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.use_deform = deform
        if parent:
            b.parent = arm_data.edit_bones[parent]
        # a steady roll: the bone's z axis leans toward the creature's back,
        # or up for bones that run fore and aft
        d = (b.tail - b.head).normalized()
        b.align_roll(-Y if abs(d.y) < 0.9 else Z)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(mesh, arm, fix=None):
    """Heat weights for the skinned body (call before hard parts are joined),
    then `fix(P, weights)` may overrule regions (jaws, lids): it gets vertex
    positions and a dict name -> weight array and edits it in place."""
    kit.activate(arm, [mesh])
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    n = len(mesh.data.vertices)
    W = {vg.name: np.zeros(n) for vg in mesh.vertex_groups}
    index = {vg.index: vg.name for vg in mesh.vertex_groups}
    for v in mesh.data.vertices:
        for g in v.groups:
            W[index[g.group]][v.index] = g.weight
    total = sum(W.values())
    unweighted = int((total < 1e-4).sum())
    if unweighted:
        raise RuntimeError(f"{mesh.name}: heat weighting left {unweighted} vertices unweighted")
    if fix is not None:
        fix(kit.co(mesh), W)
    # at most four influences, normalised (glTF and Godot's limit)
    names = list(W)
    M = np.stack([W[k] for k in names], axis=1)
    if M.shape[1] > 4:
        cut = np.sort(M, axis=1)[:, -4][:, None]
        M = np.where(M >= cut, M, 0.0)
    M /= np.maximum(M.sum(axis=1, keepdims=True), 1e-9)
    for vg in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(vg)
    for j, k in enumerate(names):
        vg = mesh.vertex_groups.new(name=k)
        col = M[:, j]
        for i in np.nonzero(col > 1e-4)[0]:
            vg.add([int(i)], float(col[i]), "REPLACE")
    return mesh


def bind_rigid(obj, bone):
    """A hard part follows one bone."""
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def bind_chain(obj, arm, bones):
    """A strip of cloth follows a chain of bones: each vertex is shared between
    the two bones nearest its place along the chain."""
    P = kit.co(obj)
    heads = [np.array(arm.data.bones[b].head_local) for b in bones]
    tails = [np.array(arm.data.bones[b].tail_local) for b in bones]
    W = np.zeros((len(P), len(bones)))
    for i in range(len(bones)):
        d, t = kit.seg_dist(P, heads[i], tails[i])
        ab = tails[i] - heads[i]
        s = ((P - heads[i]) @ ab) / max(float(ab @ ab), 1e-12)      # unclamped place along this bone
        w = np.clip(1.0 - np.abs(s - 0.5) / 1.0, 0.0, 1.0)
        if i == 0:
            w = np.where(s < 0.5, 1.0, w)
        if i == len(bones) - 1:
            w = np.where(s > 0.5, 1.0, w)
        W[:, i] = w
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    for i, b in enumerate(bones):
        vg = obj.vertex_groups.new(name=b)
        for j in np.nonzero(W[:, i] > 1e-3)[0]:
            vg.add([int(j)], float(W[j, i]), "REPLACE")


def bind_near(obj, arm, bones, sigma=0.01, weights=None):
    """Bone weights by nearness: each vertex follows the bones it lies along,
    shared smoothly where two meet. `weights(P)` -> {bone: array} overrules."""
    P = kit.co(obj)
    if weights is not None:
        W = weights(P)
        names = list(W)
        M = np.stack([W[k] for k in names], axis=1)
    else:
        names = list(bones)
        M = np.zeros((len(P), len(names)))
        for i, b in enumerate(names):
            d, _ = kit.seg_dist(P, np.array(arm.data.bones[b].head_local), np.array(arm.data.bones[b].tail_local))
            M[:, i] = d
        M = np.exp(-((M - M.min(axis=1, keepdims=True)) / sigma) ** 2)
    if M.shape[1] > 4:
        cut = np.sort(M, axis=1)[:, -4][:, None]
        M = np.where(M >= cut, M, 0.0)
    M /= np.maximum(M.sum(axis=1, keepdims=True), 1e-9)
    for j, k in enumerate(names):
        vg = obj.vertex_groups.new(name=k)
        for i in np.nonzero(M[:, j] > 1e-3)[0]:
            vg.add([int(i)], float(M[i, j]), "REPLACE")


def attach(mesh, arm):
    mesh.parent = arm
    mod = next((m for m in mesh.modifiers if m.type == "ARMATURE"), None) or mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ------------------------------------------------------------------ poses

class Pose:
    """One frame, as the clip's author states it."""

    def __init__(self):
        self.body_loc = Vector((0, 0, 0))
        self.body_rot = Quaternion()
        self.fk = {}             # bone -> Quaternion in creature axes, carried by its parent
        self.offsets = {}        # bone -> Vector, extra translation in creature axes (neck stretch)
        self.feet = {}           # side -> dict(ball, heel, toe, yaw) or None for FK legs
        self.hands = {}          # side -> dict(pos, aim, pole)
        self.curl = {}           # side -> (curl 0..1, spread -1..1)
        self.keys = {}           # shape key -> value
        self.ground = 0.0        # 0..1: settle the body onto the ground
        self.wind = {}           # cloth bone -> Vector, a push on its hang direction (creature axes)

    def body(self, loc=(0, 0, 0), pitch=0.0, yaw=0.0, roll=0.0):
        """Moves and turns everything above the feet (the `body` carrier)."""
        self.body_loc = Vector(loc)
        self.body_rot = rot(pitch, yaw, roll)
        return self

    def turn(self, bone, pitch=0.0, yaw=0.0, roll=0.0):
        self.fk[bone] = rot(pitch, yaw, roll) @ self.fk.get(bone, Quaternion())
        return self

    def spine(self, bones, pitch=0.0, yaw=0.0, roll=0.0):
        """Shares a bend evenly over a chain of bones."""
        n = len(bones)
        for b in bones:
            self.turn(b, pitch / n, yaw / n, roll / n)
        return self

    def stretch(self, bone, vec):
        self.offsets[bone] = Vector(vec)
        return self

    def foot(self, side, ball=None, heel=None, toe=0.0, yaw=0.0, carried=None, space="pelvis", mix=None, knee=None):
        """Plants the ball of a foot at `ball` (creature space). `heel` is the
        metatarsal's angle above the ground (None = the rest angle); `toe` lifts
        the toes; `yaw` turns the foot out. `carried` is a second target, given
        where it would be at rest and carried by the bone `space` (a leg tucked
        under a lying body); `mix` 0..1 blends from planted to carried."""
        if mix is None:
            mix = 0.0 if ball is not None else 1.0
        self.feet[side] = dict(ball=None if ball is None else Vector(ball), heel=heel, toe=toe, yaw=yaw,
                               carried=None if carried is None else Vector(carried), space=space, mix=mix,
                               knee=None if knee is None else Vector(knee))
        return self

    def hand(self, side, pos=None, aim=None, pole=None, space=None, carried=None, mix=None):
        """Puts a wrist at `pos`. `aim` is where the fingers point; `pole` is
        the direction the elbow bends toward. With `space` = a bone name, all
        three are given where they would be at rest and are carried by that
        bone (hands that hang from the chest). `carried` + `mix` blend a fixed
        creature-space `pos` (a hand on the ground, at its own throat) with a
        carried one; aim and pole are then creature-space."""
        if carried is not None:
            self.hands[side] = dict(pos=None if pos is None else Vector(pos), carried=Vector(carried), mix=1.0 if mix is None else mix,
                                    aim=None if aim is None else Vector(aim).normalized(),
                                    pole=None if pole is None else Vector(pole), space=space or "chest", carry_dirs=False)
        else:
            self.hands[side] = dict(pos=Vector(pos), carried=None, mix=0.0, aim=None if aim is None else Vector(aim).normalized(),
                                    pole=None if pole is None else Vector(pole), space=space, carry_dirs=True)
        return self

    def rest_on_ground(self, weight=1.0):
        """Lets the body settle until its lowest part touches the ground
        (lying, kneeling, falling): `weight` 0..1 blends it in."""
        self.ground = weight
        return self

    def fingers(self, side, curl=0.0, spread=0.0):
        self.curl[side] = (curl, spread)
        return self

    def blow(self, bone, vec):
        """Pushes a cloth bone (spec "cloth") off its hang: `vec` is added to
        the direction it would hang in, so 0.3 sideways swings it about 17 degrees."""
        self.wind[bone] = Vector(vec) + self.wind.get(bone, Vector())
        return self

    def key(self, name, value):
        self.keys[name] = value
        return self


def _swing(a, b):
    """Shortest rotation taking direction a to direction b."""
    a, b = a.normalized(), b.normalized()
    d = a.dot(b)
    if d > 0.999999:
        return Quaternion()
    if d < -0.999999:
        axis = a.cross(X if abs(a.x) < 0.9 else Y).normalized()
        return Quaternion(axis, math.pi)
    return Quaternion(a.cross(b).normalized(), math.acos(max(-1.0, min(1.0, d))))


def two_bone(a, target, l1, l2, pole):
    """Where the middle joint goes: root a, end at target, bend toward pole."""
    v = target - a
    d = max(min(v.length, (l1 + l2) * 0.9995), abs(l1 - l2) + 1e-4)
    n = v.normalized()
    along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - along * along, 0.0))
    p = pole - n * pole.dot(n)
    if p.length < 1e-6:
        p = Y - n * Y.dot(n)
    return a + n * along + p.normalized() * h, a + n * d


class Rig:
    """Bone tables and the solver. `spec`:
        legs:  {side: (upper, lower, foot, paw)}   foot may be None (plantigrade)
        pole_space: bone                           what carries the knees' bend direction ("pelvis")
        arms:  {side: (clav, arm, forearm, hand)}
        fingers: {side: [[bone, bone, ...], ...]}  chains that curl
        palm:  {side: Vector}                      toward which the fingers curl (rest, creature axes)
        cloth: [dict(bones=[...], hang=0..1)]      chains that hang: each bone keeps the direction it
                                                   was modelled in (straight down, usually) whatever
                                                   carries it, by `hang`; Pose.blow() swings it, and
                                                   it lies along the ground where it would go under
    """

    def __init__(self, arm, mesh, spec):
        self.arm = arm
        self.mesh = mesh
        self.spec = spec
        self.bones = [b.name for b in arm.data.bones]             # parent-first
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.head = {b.name: b.head_local.copy() for b in arm.data.bones}
        self.tail = {b.name: b.tail_local.copy() for b in arm.data.bones}
        self.length = {b.name: b.length for b in arm.data.bones}
        self.rest_heel = {}
        for side, (up, lo, ft, paw) in spec.get("legs", {}).items():
            if ft:
                d = (self.head[ft] - self.tail[ft]).normalized()      # ball -> hock
                self.rest_heel[side] = math.degrees(math.asin(d.z))
        self.clips = []
        self.report = {}
        self._moves = {}
        self._placed = set()

    # ---- rest facts a clip author needs
    def rest_ball(self, side):
        up, lo, ft, paw = self.spec["legs"][side]
        return self.head[paw].copy()

    def rest_wrist(self, side):
        return self.head[self.spec["arms"][side][3]].copy()

    def hip_height(self):
        return self.head[self.spec["legs"]["r"][0]].z

    # ---- solving one pose into armature-space matrices
    def solve(self, p):
        M = {}
        body_fix = Matrix.Translation(p.body_loc) @ self._about(self.head["body"], p.body_rot)
        drop = 0.0
        settle = 0.0
        for attempt in range(4):
            M.clear()
            lift = Matrix.Translation((0, 0, settle - drop)) @ body_fix
            for b in self.bones:
                par = self.parent[b]
                if b == "root":
                    M[b] = self.rest[b].copy()
                    continue
                base = (M[par] @ self.rest[par].inverted() if par else Matrix.Identity(4))
                if b == "body":
                    base = lift
                local = Matrix.Identity(4)
                if b in p.fk:
                    local = self._about(self.head[b], p.fk[b])
                if b in p.offsets:
                    local = Matrix.Translation(p.offsets[b]) @ local
                M[b] = base @ local @ self.rest[b]
            need = self._legs(p, M, dry=True) if p.ground < 0.5 else 0.0
            self._legs(p, M, dry=False)
            self._arms(p, M)
            self._fingers(p, M)
            self._cloth(p, M)
            if p.ground > 0.0 and attempt < 3:
                low = self._lowest(M)
                if abs(low) > 1e-4:
                    settle -= low * p.ground
                    continue
            if need <= 1e-5 or attempt == 3:
                break
            drop += need
        return M, drop

    def _lowest(self, M):
        """Height of the body's lowest point, from a capsule round each bone."""
        radius = self.spec.get("radius", {})
        low = 1e9
        for entry in self.spec.get("core", self.bones):
            b, _, end = entry.partition(".")
            r = radius.get(entry, radius.get(b, radius.get(b.rsplit("_", 1)[0], None)))
            if r is None:
                continue
            m = M[b]
            if end != "tail":
                low = min(low, m.to_translation().z - r)
            if end != "head":
                low = min(low, (m @ Vector((0, self.length[b], 0))).z - r)
        return low

    def _floor(self, pt, r, g):
        """Keeps a limb point above the ground while the body lies on it."""
        if g > 0.0 and pt.z < r:
            pt = pt.copy()
            pt.z += (r - pt.z) * g
        return pt

    def _bend_clear(self, a, target, l1, l2, pole, r, g):
        """two_bone, turning the bend upward until the middle joint clears the ground."""
        mid, end = two_bone(a, target, l1, l2, pole)
        if g > 0.0:
            for k in (0.5, 1.5, 4.0, 20.0):
                if mid.z >= r * g:
                    break
                mid, end = two_bone(a, target, l1, l2, pole.normalized() + Z * k)
        return mid, end

    @staticmethod
    def _about(pivot, q):
        return Matrix.Translation(pivot) @ q.to_matrix().to_4x4() @ Matrix.Translation(-pivot)

    def _aim(self, M, b, origin, direction, propagate=True, pre=None):
        """Places bone b at origin with its length axis along direction, with
        the least twist away from where its parent carries it."""
        par = self.parent[b]
        carried = (M[par] @ self.rest[par].inverted() @ self.rest[b]) if propagate and par else self.rest[b]
        q = carried.to_quaternion()
        if pre is not None:
            q = pre @ q
        cur = q @ Y
        q = _swing(cur, direction) @ q
        M[b] = Matrix.Translation(origin) @ q.to_matrix().to_4x4()
        return M[b]

    def _children_follow(self, M, b):
        """Re-carries every descendant of b that the solver has not placed."""
        for c in self.bones:
            par = self.parent[c]
            if par is None:
                continue
            # walk up to see whether b is an ancestor
            a = par
            while a is not None and a != b:
                a = self.parent[a]
            if a == b and c not in self._placed:
                M[c] = M[par] @ self.rest[par].inverted() @ self.rest[c]

    def _legs(self, p, M, dry):
        need = 0.0
        self._placed = set()
        for side, (up, lo, ft, paw) in self.spec.get("legs", {}).items():
            f = p.feet.get(side)
            if f is None:
                continue
            hip = M[up].to_translation()
            mix = f["mix"]
            heel = math.radians(self.rest_heel.get(side, 0.0) if f["heel"] is None else f["heel"])
            yaw = math.radians(f["yaw"]) * side_sign(side)
            toe = math.radians(f["toe"])
            back = Quaternion(Z, -yaw) @ Vector((0, -math.cos(heel), math.sin(heel)))
            toe_dir = Quaternion(Z, -yaw) @ Vector((0, math.cos(toe), math.sin(toe)))
            ball = f["ball"]
            toe_flat = toe_dir.copy()
            Rq = Quaternion()
            if f["carried"] is not None and mix > 0.0:
                Rq = Quaternion().slerp((M[f["space"]] @ self.rest[f["space"]].inverted()).to_quaternion(), mix)
                carry = M[f["space"]] @ self.rest[f["space"]].inverted()
                c_ball = carry @ f["carried"]
                R = carry.to_3x3()
                ball = c_ball if ball is None else ball.lerp(c_ball, mix)
                back = back.lerp(R @ back, mix).normalized()
                toe_dir = toe_dir.lerp(R @ toe_dir, mix).normalized()
            g = p.ground
            ball = self._floor(ball, 0.03, g)
            hock = ball + back * self.length[ft] if ft else ball
            hock = self._floor(hock, 0.045, g)
            l1, l2 = self.length[up], self.length[lo]
            reach = (l1 + l2) * 0.992
            v = hock - hip
            if v.length > reach and mix < 0.5:
                horiz = math.hypot(v.x, v.y)
                if horiz < reach:
                    need = max(need, hip.z - math.sqrt(reach * reach - horiz * horiz) - hock.z)
            if dry:
                continue
            core = self.spec.get("pole_space", "pelvis")           # the bone the knees' bend direction rides on
            pole = (M[core] @ self.rest[core].inverted()).to_3x3() @ (f["knee"] or Vector((0.12 * side_sign(side), 1.0, 0.1)))
            knee, hock_ = self._bend_clear(hip, hock, l1, l2, pole, 0.06, g)
            self._aim(M, up, hip, knee - hip)
            self._aim(M, lo, knee, hock_ - knee)
            self._placed.update((up, lo))
            if ft:
                self._aim(M, ft, hock_, ball - hock_)
                self._placed.add(ft)
                ball_pos = hock_ + (ball - hock_).normalized() * self.length[ft]
            else:
                ball_pos = hock_
            # the toes keep the rest pose's slight outward and downward set
            rest_dir = (self.tail[paw] - self.head[paw]).normalized()
            self._aim(M, paw, ball_pos, Rq @ (_swing(Y, toe_flat) @ rest_dir), propagate=False, pre=Rq)
            self._placed.add(paw)
            self._children_follow(M, up)
        return need

    def _arms(self, p, M):
        for side, (clav, arm_b, fore, hand) in self.spec.get("arms", {}).items():
            h = p.hands.get(side)
            if h is None:
                continue
            self._placed = set()
            sh = M[arm_b].to_translation()
            pole = h["pole"] if h["pole"] is not None else Vector((0.6 * side_sign(side), -1.0, -0.3))
            pos, aim = h["pos"], h["aim"]
            if h["space"]:
                carry = M[h["space"]] @ self.rest[h["space"]].inverted()
                if h["carried"] is not None:
                    c = carry @ h["carried"]
                    pos = c if pos is None else pos.lerp(c, h["mix"])
                else:
                    pos = carry @ pos
                if h["carry_dirs"]:
                    pole = carry.to_3x3() @ pole
                    aim = None if aim is None else carry.to_3x3() @ aim
            pos = self._floor(pos, 0.035, p.ground)
            elbow, wrist = self._bend_clear(sh, pos, self.length[arm_b], self.length[fore], pole, 0.05, p.ground)
            self._aim(M, arm_b, sh, elbow - sh)
            self._aim(M, fore, elbow, wrist - elbow)
            self._aim(M, hand, wrist, aim if aim is not None else (wrist - elbow))
            self._placed.update((arm_b, fore, hand))
            self._children_follow(M, hand)

    def _fingers(self, p, M):
        for side, (curl, spread) in p.curl.items():
            hand = self.spec["arms"][side][3]
            carry = M[hand] @ self.rest[hand].inverted()
            palm = self.spec["palm"][side]
            chains = self.spec["fingers"][side]
            for i, chain in enumerate(chains):
                acc = carry
                fan = (i - (len(chains) - 1) / 2.0) / max((len(chains) - 1) / 2.0, 1.0)
                for j, b in enumerate(chain):
                    d = (self.tail[b] - self.head[b]).normalized()
                    axis = d.cross(palm).normalized()
                    q = Quaternion(axis, math.radians((70.0 if j == 0 else 55.0) * curl))
                    if j == 0 and spread:
                        q = Quaternion(palm, math.radians(-16.0 * spread * fan * side_sign(side))) @ q
                    acc = acc @ self._about(self.head[b], q)
                    M[b] = acc @ self.rest[b]
                    last = b
                self._placed = set(chain)
                self._children_follow(M, last)

    def _cloth(self, p, M):
        for chain in self.spec.get("cloth", ()):
            hang = chain.get("hang", 1.0)
            for b in chain["bones"]:
                par = self.parent[b]
                carry = M[par] @ self.rest[par].inverted()
                origin = carry @ self.head[b]
                rest_dir = (self.tail[b] - self.head[b]).normalized()
                carried = carry.to_3x3() @ rest_dir
                d = carried.lerp(rest_dir, hang) + p.wind.get(b, Vector())
                if d.length < 1e-6:
                    d = rest_dir.copy()
                d.normalize()
                # cloth that reaches the ground lies along it
                L = self.length[b]
                floor = 0.012
                if origin.z + d.z * L < floor:
                    dz = max(min((floor - origin.z) / L, 1.0), -1.0)
                    flat = Vector((d.x, d.y, 0.0))
                    if flat.length < 1e-4:
                        flat = Vector((carried.x, carried.y, 0.0))
                    if flat.length < 1e-4:
                        flat = Vector((0.0, -1.0, 0.0))
                    d = flat.normalized() * math.sqrt(max(1.0 - dz * dz, 0.0)) + Z * dz
                self._aim(M, b, origin, d)

    # ---- facts about a solved pose
    def ball_of(self, M, side):
        return M[self.spec["legs"][side][3]].to_translation()

    # ---- keying
    def clip(self, name, duration, fn, loop=False, speed=None, contact=None, travel=None):
        """Samples fn(t) -> Pose at 30 fps and keys it on a new NLA track.
        A looping clip's last frame equals its first. Returns the solved frames."""
        arm = self.arm
        frames = max(int(round(duration * FPS)), 1)
        duration = frames / FPS
        solved, drops, poses = [], [], []
        for f in range(frames + 1):
            t = (f % frames if loop else f) / FPS
            p = fn(t)
            M, drop = self.solve(p)
            solved.append(M)
            drops.append(drop)
            poses.append(p)
        ad = arm.animation_data or arm.animation_data_create()
        act = bpy.data.actions.new(name)
        ad.action = act
        prev = {}
        for f, M in enumerate(solved):
            for b in self.bones:
                par = self.parent[b]
                if par:
                    local = (self.rest[par].inverted() @ self.rest[b]).inverted() @ (M[par].inverted() @ M[b])
                else:
                    local = self.rest[b].inverted() @ M[b]
                loc, q, _ = local.decompose()
                if b in prev and prev[b].dot(q) < 0.0:
                    q = -q
                prev[b] = q
                pb = arm.pose.bones[b]
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if loc.length > 1e-5 or b == "body" or self._moves.get(b):
                    self._moves[b] = True
                    pb.location = loc
                    pb.keyframe_insert("location", frame=f)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act).name = name
        track.mute = True
        self._key_shapes(name, poses)
        self.clips.append(dict(name=name, speed=speed, duration=duration, loop=loop, contact=contact, travel=travel))
        self.report[name] = dict(max_drop=max(drops))
        return solved

    def _key_shapes(self, name, poses):
        keys = self.mesh.data.shape_keys
        used = sorted({k for p in poses for k in p.keys})
        if keys is None or not used:
            return
        ad = keys.animation_data or keys.animation_data_create()
        act = bpy.data.actions.new(name + "_face")
        ad.action = act
        for f, p in enumerate(poses):
            for k in used:
                kb = keys.key_blocks[k]
                kb.value = p.keys.get(k, 0.0)
                kb.keyframe_insert("value", frame=f)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act).name = name
        track.mute = True
        for k in used:
            keys.key_blocks[k].value = 0.0

    def finish(self):
        """Rest pose, every track live, ready to export."""
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
        for owner in (self.arm, self.mesh.data.shape_keys):
            if owner is not None and owner.animation_data:
                for t in owner.animation_data.nla_tracks:
                    t.mute = False

    # ---- gaits
    def gait(self, name, speed, stride, duty, phases, lift, upper, stance_y=0.0, width=None,
             heel=None, heel_off=25.0, swing_heel=20.0, toe_swing=-25.0, yaw=6.0):
        """A looping gait at `speed` m/s with `stride` metres per cycle.
        phases: {side: 0..1} when each foot lands. duty: the share of the cycle
        a foot is planted. stance_y: where the middle of a step falls, one
        number or {side: y} (many legs, each under its own hip). upper(t, phase, pose): the author adds the body.
        Returns the measured slide of planted feet in metres (should be ~0)."""
        T = stride / speed
        frames = max(int(round(T * FPS)), 2)
        T = frames / FPS
        stride = speed * T                      # after snapping to whole frames
        sweep = duty * stride                   # how far a planted foot travels back

        def foot(side, ph):
            ball0 = self.rest_ball(side)
            x = ball0.x if width is None else width * side_sign(side)
            mid_y = stance_y[side] if isinstance(stance_y, dict) else stance_y
            u = (ph - phases[side]) % 1.0
            base_heel = self.rest_heel.get(side, 0.0) if heel is None else heel
            if u < duty:                          # planted: back at ground speed
                k = u / duty
                y = mid_y + sweep / 2 - sweep * k
                return dict(ball=(x, y, ball0.z), heel=base_heel + heel_off * smooth(seg(k, 0.55, 1.0)),
                            toe=0.0, yaw=yaw), True
            s = (u - duty) / (1.0 - duty)
            y = mid_y - sweep / 2 + sweep * (smooth(s) * 0.85 + s * 0.15)
            z = ball0.z + lift * math.sin(math.pi * s) ** 0.8
            h = base_heel + heel_off * (1.0 - smooth(seg(s, 0.0, 0.35))) + swing_heel * math.sin(math.pi * s)
            return dict(ball=(x, y, z), heel=h, toe=toe_swing * math.sin(math.pi * smooth(s)) + 16.0 * pulse(s, 0.55, 0.85, 1.0),
                        yaw=yaw), False

        def fn(t):
            ph = (t / T) % 1.0
            p = Pose()
            for side in phases:
                f, _ = foot(side, ph)
                p.foot(side, **f)
            upper(t, ph, p)
            return p

        solved = self.clip(name, T, fn, loop=True, speed=speed)
        slide = 0.0
        for side in phases:
            last = None
            for f in range(frames + 1):
                ph = ((f % frames) / frames) % 1.0
                _, planted = foot(side, ph)
                pos = self.ball_of(solved[f], side)
                ground = Vector((pos.x, pos.y + speed * f / FPS, pos.z))    # where it is on the moving ground
                if planted and last is not None and last[1]:
                    slide = max(slide, (ground - last[0]).length)
                last = (ground, planted)
        self.report[name]["slide_per_frame"] = slide
        self.report[name]["stride"] = stride
        return slide


# ------------------------------------------------------------------ files

def write_gaits(name, rig, model_path, subdir="creatures"):
    """data/animation/<subdir>/<name>_gaits.txt: one row per clip.
    Columns: name, native speed (m/s, '-' if not a gait), duration (s), loop,
    contact_s ('-' unless an attack: when the blow lands), travel_m ('-'
    unless the clip moves the body: how far the code must carry the creature)."""
    folder = os.path.join(kit.ROOT, "data", "animation", subdir)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{name}_gaits.txt")
    with open(path, "w") as f:
        f.write(f"# {name} clips ({model_path}), 30 fps. Written by tools/blender/monsters/{name}.py.\n")
        f.write("# name native_speed_mps duration_s loop(0/1) contact_s travel_m   ('-' = does not apply)\n")
        for c in rig.clips:
            def col(v):
                return "-" if v is None else f"{v:.3f}"
            f.write(f"{c['name']} {col(c['speed'])} {c['duration']:.3f} {int(c['loop'])} {col(c['contact'])} {col(c['travel'])}\n")
    return path
