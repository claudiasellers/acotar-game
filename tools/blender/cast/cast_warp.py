"""Proportion warp: Feyre's space -> a character's height and build.

One smooth map W(p) moves every skinned mesh, shape key and bone of a
character built in Feyre's space, so the rig, weights and garments stay in
register.  It changes:

* height: legs and torso scale separately (`legs` = leg length relative to
  torso), the head scales on its own (`head`) about the top of the neck;
* widths: `wx` and `wy` are (z, factor) knots in Feyre's z, applied to x
  (side to side) and y (front to back) of the torso and legs;
* arms: in the T-pose they leave the torso at the shoulder joint and scale in
  length (`arm_len`) and thickness (`arm_thick`) from there.

Every blend uses smoothstep so the surface stays smooth (no creases).
"""

import numpy as np

FEYRE_H = 1.66
NECK_TOP_Z = 1.43
CROTCH_Z = 0.835
SHOULDER_X = 0.158
SHOULDER_Z = 1.285


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _knots(table, z):
    """Cosine-eased interpolation through (z, value) knots: C1, flat at each knot."""
    zs = np.array([k[0] for k in table], float)
    vs = np.array([k[1] for k in table], float)
    z = np.clip(z, zs[0], zs[-1])
    i = np.clip(np.searchsorted(zs, z) - 1, 0, len(zs) - 2)
    t = (z - zs[i]) / np.maximum(zs[i + 1] - zs[i], 1e-9)
    t = t * t * (3.0 - 2.0 * t)
    return vs[i] * (1.0 - t) + vs[i + 1] * t


class Warp:
    def __init__(self, height, head=1.0, legs=1.0, wx=((0.0, 1.0), (1.7, 1.0)), wy=((0.0, 1.0), (1.7, 1.0)),
                 arm_len=1.0, arm_thick=1.0):
        self.head = head
        self.legs = legs
        self.wx, self.wy = tuple(wx), tuple(wy)
        self.arm_len, self.arm_thick = arm_len, arm_thick
        hh = FEYRE_H - NECK_TOP_Z
        self.ts = (height - hh * head) / (CROTCH_Z * legs + NECK_TOP_Z - CROTCH_Z)
        self.height = height

    def fz(self, z):
        """Body z map: legs scale by legs*ts below the crotch, torso by ts above (soft knee)."""
        k = 0.04
        c = CROTCH_Z
        softmin = c - k * np.logaddexp(0.0, (c - z) / k)
        return self.ts * (z + (self.legs - 1.0) * softmin)

    def __call__(self, P):
        P = np.asarray(P, float)
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ts = self.ts
        # torso and legs
        bx = x * ts * _knots(self.wx, z)
        by = y * ts * _knots(self.wy, z)
        bz = self.fz(z)
        # arms, from the shoulder joint outward
        ax_ = np.abs(x)
        sgn = np.where(x >= 0, 1.0, -1.0)
        sh_x = SHOULDER_X * ts * float(_knots(self.wx, np.array([SHOULDER_Z]))[0])
        sh_z = float(self.fz(np.array([SHOULDER_Z]))[0])
        arm_x = sgn * (sh_x + (ax_ - SHOULDER_X) * ts * self.arm_len)
        arm_y = y * ts * self.arm_thick
        arm_z = sh_z + (z - SHOULDER_Z) * ts * self.arm_thick
        a = _smooth(0.12, 0.20, ax_) * _smooth(1.08, 1.18, z)
        bx = bx * (1 - a) + arm_x * a
        by = by * (1 - a) + arm_y * a
        bz = bz * (1 - a) + arm_z * a
        # head: uniform scale about the neck top
        nt = np.array([0.0, 0.006, NECK_TOP_Z])
        nt2 = np.array([0.0, 0.006 * ts * float(_knots(self.wy, np.array([NECK_TOP_Z]))[0]),
                        float(self.fz(np.array([NECK_TOP_Z]))[0])])
        H = (P - nt) * self.head + nt2
        h = _smooth(1.39, 1.47, z)[:, None]
        out = np.stack([bx, by, bz], 1) * (1 - h) + H * h
        return out
