"""Small collectibles and notice-moment ("look") subjects for the cottage and
workshop regions. Origin at the base centre. Writes
world/human_realm/cottage/assets/small/ (the workshop reuses the looks)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cottage_lib as L  # noqa: E402

OUT = "world/human_realm/cottage/assets/small/"
BRASS = (0.68, 0.55, 0.3)
COPPER = (0.62, 0.38, 0.22)
PAPER = (0.82, 0.78, 0.66)


def flake_ring(r=0.25):
    """A small trodden ring of snow so the eye finds the item."""
    L.cyl(r, 0.02, at=(0, -0.01, 0), seg=10, col=(0.78, 0.82, 0.9))


# --- Collectibles ------------------------------------------------------------

def lost_button():
    flake_ring(0.15)
    L.cyl(0.03, 0.01, at=(0, 0.01, 0), seg=10, col=BRASS)
    for x in (-0.008, 0.008):
        L.cyl(0.004, 0.012, at=(x, 0.012, 0), seg=4, col=L.SOOT)
    L.export(OUT + "lost_button.glb")


def bone_token():
    flake_ring(0.15)
    L.cyl(0.035, 0.012, at=(0, 0.01, 0), seg=6, col=L.BONE)
    L.box((0.04, 0.014, 0.004), at=(0, 0.016, 0), rot=(0, 45, 0), col=(0.5, 0.42, 0.3))
    L.box((0.04, 0.014, 0.004), at=(0, 0.016, 0), rot=(0, -45, 0), col=(0.5, 0.42, 0.3))
    L.export(OUT + "bone_token.glb")


def blessed_pamphlet():
    """A Children of the Blessed tract, half buried, a pale sun printed on it."""
    flake_ring(0.25)
    L.box((0.15, 0.006, 0.21), at=(0, 0.01, 0), rot=(4, 20, 0), col=PAPER)
    L.cyl(0.03, 0.004, at=(0.0, 0.016, -0.03), rot=(4, 20, 0), seg=10, col=(0.82, 0.68, 0.38))
    L.box((0.1, 0.004, 0.006), at=(0.0, 0.016, 0.04), rot=(4, 20, 0), col=(0.35, 0.32, 0.3))
    L.box((0.08, 0.004, 0.006), at=(0.0, 0.016, 0.06), rot=(4, 20, 0), col=(0.35, 0.32, 0.3))
    L.export(OUT + "blessed_pamphlet.glb")


def frozen_ribbon():
    flake_ring(0.2)
    for i in range(8):
        L.box((0.05, 0.004, 0.02), at=(-0.15 + i * 0.04, 0.012, 0.03 * math.sin(i * 0.9)), rot=(0, i * 20, 0), col=(0.55, 0.62, 0.72))
    L.export(OUT + "frozen_ribbon.glb")


def clay_pipe():
    flake_ring(0.15)
    L.cyl(0.006, 0.16, at=(-0.08, 0.012, 0), rot=(0, 0, -90), seg=5, col=(0.85, 0.82, 0.76))
    L.cyl(0.016, 0.035, at=(0.08, 0.005, 0), r2=0.02, seg=8, col=(0.85, 0.82, 0.76))
    L.export(OUT + "clay_pipe.glb")


def horseshoe():
    flake_ring(0.18)
    for i in range(9):
        a = math.pi * (-0.15 + 1.3 * i / 8)
        L.box((0.03, 0.012, 0.016), at=(0.055 * math.cos(a), 0.008, 0.055 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 0), col=(0.36, 0.3, 0.27))
    L.export(OUT + "horseshoe.glb")


def lost_mitten():
    flake_ring(0.2)
    L.ball(0.06, at=(0, 0.02, 0), scale=(1, 0.35, 1.5), col=(0.48, 0.32, 0.3), sub=1)
    L.ball(0.025, at=(0.05, 0.02, -0.03), scale=(1, 0.5, 1.2), col=(0.48, 0.32, 0.3), sub=1)
    L.cyl(0.05, 0.02, at=(0, 0.01, 0.09), rot=(90, 0, 0), seg=8, col=L.WOOL)
    L.export(OUT + "lost_mitten.glb")


def copper_coin():
    flake_ring(0.12)
    L.cyl(0.014, 0.003, at=(0, 0.004, 0), seg=10, col=COPPER)
    L.cyl(0.014, 0.003, at=(0.02, 0.006, 0.01), rot=(10, 0, 0), seg=10, col=COPPER)
    L.export(OUT + "copper_coin.glb")


def tin_soldier():
    flake_ring(0.15)
    L.cyl(0.012, 0.004, at=(0.0, 0.006, 0), seg=8, col=(0.55, 0.56, 0.58))
    L.box((0.06, 0.016, 0.012), at=(0.0, 0.012, 0), col=(0.55, 0.56, 0.58))
    L.ball(0.008, at=(0.035, 0.012, 0), col=(0.55, 0.56, 0.58), sub=0)
    L.export(OUT + "tin_soldier.glb")


def paint_tin_empty():
    """One of Feyre's old paint tins, scraped out, a rim of dried red."""
    flake_ring(0.15)
    L.cyl(0.04, 0.06, at=(0, 0.0, 0), rot=(0, 0, 80), seg=8, col=(0.5, 0.5, 0.52))
    L.cyl(0.036, 0.004, at=(0.062, 0.04, 0), rot=(0, 0, 80), seg=8, col=(0.6, 0.2, 0.2))
    L.export(OUT + "paint_tin_empty.glb")


# --- Look subjects -----------------------------------------------------------

def tracks(name, n, step, shape, col=(0.62, 0.68, 0.8), wander=0.05):
    L.seed(sum(ord(c) for c in name))
    for i in range(n):
        side = 1 if i % 2 else -1
        x, z = side * wander + L.rnd(-0.01, 0.01), -i * step
        shape(x, z)
    L.export(OUT + name + ".glb")


def fox_tracks():
    def paw(x, z):
        L.cyl(0.025, 0.012, at=(x, -0.004, z), seg=6, col=(0.6, 0.66, 0.78))
        for k in range(4):
            a = math.pi * (1.2 + 0.2 * k)
            L.cyl(0.009, 0.012, at=(x + 0.03 * math.cos(a) * 0.6, -0.004, z + 0.035 * math.sin(a)), seg=5, col=(0.6, 0.66, 0.78))
    tracks("fox_tracks", 16, 0.32, paw, wander=0.02)


def deer_tracks():
    def hoof(x, z):
        for dx in (-0.015, 0.015):
            L.ball(0.022, at=(x + dx, -0.004, z), scale=(0.6, 0.3, 1.4), col=(0.58, 0.63, 0.76), sub=0)
    tracks("deer_tracks", 14, 0.55, hoof, wander=0.08)


def hare_tracks():
    def hop(x, z):
        for dx, dz, s in ((-0.04, 0.0, 1.6), (0.04, 0.0, 1.6), (0.0, 0.12, 0.8), (0.01, 0.2, 0.8)):
            L.ball(0.02, at=(dx, -0.004, z + dz), scale=(0.8, 0.3, s), col=(0.6, 0.66, 0.78), sub=0)
    tracks("hare_tracks", 10, 0.6, hop, wander=0.0)


def frozen_bird():
    """A small bird frozen where it fell, frost on its feathers."""
    flake_ring(0.22)
    L.ball(0.04, at=(0, 0.03, 0), scale=(1.5, 0.8, 1), rot=(0, 0, 80), col=(0.45, 0.4, 0.36))
    L.ball(0.022, at=(0.055, 0.03, 0), col=(0.4, 0.36, 0.33), sub=1)
    L.cyl(0.008, 0.02, at=(0.075, 0.03, 0), rot=(0, 0, -90), r2=0.0, seg=4, col=(0.3, 0.28, 0.2))
    L.ball(0.03, at=(-0.01, 0.055, 0), scale=(1.4, 0.3, 1), col=L.FROST, sub=1)
    L.export(OUT + "frozen_bird.glb")


def robin_post():
    """A fence post with a robin on it: the realm's one bright red breast."""
    L.cyl(0.07, 1.1, seg=7, col=L.TIMBER, jitter=0.005)
    L.cyl(0.08, 0.06, at=(0, 1.1, 0), seg=7, col=L.SNOW)
    L.ball(0.045, at=(0, 1.2, 0), scale=(1.2, 1, 1), col=(0.42, 0.34, 0.27))
    L.ball(0.03, at=(-0.03, 1.19, 0), scale=(0.6, 1, 0.9), col=(0.86, 0.36, 0.16))
    L.ball(0.026, at=(-0.03, 1.25, 0), col=(0.42, 0.34, 0.27), sub=1)
    L.cyl(0.006, 0.02, at=(-0.055, 1.25, 0), rot=(0, 0, 90), r2=0.0, seg=4, col=L.SOOT)
    L.box((0.06, 0.01, 0.025), at=(0.05, 1.2, 0), rot=(0, 0, 20), col=(0.3, 0.25, 0.2))
    L.export(OUT + "robin_post.glb")


def crow_flock():
    """Crows picking at a frozen furrow."""
    L.seed(41)
    for i in range(6):
        x, z, yaw = L.rnd(-1.2, 1.2), L.rnd(-1.2, 1.2), L.rnd(0, 360)
        L.ball(0.09, at=(x, 0.1, z), scale=(1.6, 0.9, 1), rot=(0, yaw, 0), col=L.SOOT)
        dx, dz = math.cos(math.radians(yaw)) * 0.14, -math.sin(math.radians(yaw)) * 0.14
        L.ball(0.055, at=(x + dx, 0.17, z + dz), col=L.SOOT, sub=1)
        L.cyl(0.02, 0.07, at=(x + dx * 1.3, 0.16, z + dz * 1.3), rot=(0, yaw, -90), r2=0.0, seg=4, col=(0.2, 0.2, 0.22))
    L.export(OUT + "crow_flock.glb")


def hare_crouched():
    L.ball(0.12, at=(0, 0.1, 0), scale=(1.4, 1, 1), col=(0.62, 0.58, 0.52))
    L.ball(0.07, at=(0.15, 0.17, 0), col=(0.62, 0.58, 0.52))
    for z in (-0.02, 0.02):
        L.ball(0.025, at=(0.12, 0.3, z), scale=(0.6, 2.4, 0.6), rot=(0, 0, 20), col=(0.58, 0.52, 0.46), sub=0)
    L.ball(0.03, at=(-0.17, 0.12, 0), col=(0.9, 0.9, 0.88), sub=0)
    L.export(OUT + "hare_crouched.glb")


def owl_perched():
    """A barn owl on a broken beam end (estate ruin, shepherd's hut)."""
    L.box((0.6, 0.14, 0.14), at=(0, 0.07, 0), col=L.CHAR)
    L.ball(0.12, at=(0, 0.3, 0), scale=(1, 1.4, 0.9), col=(0.82, 0.72, 0.56))
    L.ball(0.09, at=(0, 0.5, -0.01), col=(0.88, 0.82, 0.7))
    L.ball(0.07, at=(0, 0.5, -0.05), scale=(1, 1, 0.4), col=(0.96, 0.94, 0.9))
    for x in (-0.03, 0.03):
        L.ball(0.012, at=(x, 0.51, -0.09), col=L.SOOT, sub=0)
    L.export(OUT + "owl_perched.glb")


def crow_on_post():
    L.cyl(0.06, 1.3, seg=6, col=L.CHAR)
    L.ball(0.09, at=(0, 1.42, 0), scale=(1.6, 0.9, 1), col=L.SOOT)
    L.ball(0.055, at=(0.13, 1.5, 0), col=L.SOOT, sub=1)
    L.cyl(0.02, 0.07, at=(0.18, 1.49, 0), rot=(0, 0, -90), r2=0.0, seg=4, col=(0.2, 0.2, 0.22))
    L.export(OUT + "crow_on_post.glb")


if __name__ == "__main__":
    L.reset()
    for fn in (lost_button, bone_token, blessed_pamphlet, frozen_ribbon, clay_pipe, horseshoe, lost_mitten,
               copper_coin, tin_soldier, paint_tin_empty, fox_tracks, deer_tracks, hare_tracks, frozen_bird,
               robin_post, crow_flock, hare_crouched, owl_perched, crow_on_post):
        fn()
