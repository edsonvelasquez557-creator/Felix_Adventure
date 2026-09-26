#!/usr/bin/env python3
"""Genera el arte PROVISIONAL (placeholder) de Felix con el layout definitivo.

Todo se dibuja por código sobre una rejilla de "roles" (contorno, base, sombra,
luz, rayas...) que luego se colorea con una paleta. Así:
  * Las skins de la tienda son solo paletas distintas sobre la misma silueta.
  * Las hojas tienen EXACTAMENTE el layout que documenta docs/05_Sprites_y_Animaciones.md:
    al sustituirlas por el arte final (IA o artista) el juego no cambia.
  * Los normal maps se generan con generate_normal_map.py (mismo pipeline que
    usarás con el arte definitivo).

Uso (desde la raíz del proyecto):
    pip install pillow numpy
    python tools/art/generate_placeholder_art.py

Sobrescribe los PNG de assets/. No lo ejecutes si ya sustituiste el arte.
"""

from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_normal_map import generate_normal_map  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"

# --------------------------------------------------------------------------
# Roles de color
# --------------------------------------------------------------------------
EMPTY, OUTLINE, BASE, SHADE, LIGHT, STRIPE, BELLY, EYE, PUPIL, PINK, GLINT, CLAW, POINTS, MOUTH = range(14)

Color = tuple[int, int, int]


def rgb(hex_color: str) -> Color:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


class Canvas:
    """Rejilla de roles con primitivas de dibujo (PIL en modo 'L')."""

    def __init__(self, width: int, height: int) -> None:
        self.image = Image.new("L", (width, height), EMPTY)
        self.draw = ImageDraw.Draw(self.image)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, role: int) -> None:
        self.draw.ellipse([round(cx - rx), round(cy - ry), round(cx + rx), round(cy + ry)], fill=role)

    def rect(self, x0: float, y0: float, x1: float, y1: float, role: int) -> None:
        self.draw.rectangle([round(x0), round(y0), round(x1), round(y1)], fill=role)

    def line(self, points: list[tuple[float, float]], role: int, width: int = 1) -> None:
        self.draw.line([(round(x), round(y)) for x, y in points], fill=role, width=width)

    def poly(self, points: list[tuple[float, float]], role: int) -> None:
        self.draw.polygon([(round(x), round(y)) for x, y in points], fill=role)

    def point(self, x: float, y: float, role: int) -> None:
        self.draw.point((round(x), round(y)), fill=role)

    def array(self) -> np.ndarray:
        return np.asarray(self.image).copy()


def add_outline(roles: np.ndarray) -> np.ndarray:
    """Contorno de 1 px alrededor de la silueta (4-vecinos)."""
    filled = roles != EMPTY
    neighbor = np.zeros_like(filled)
    neighbor[1:, :] |= filled[:-1, :]
    neighbor[:-1, :] |= filled[1:, :]
    neighbor[:, 1:] |= filled[:, :-1]
    neighbor[:, :-1] |= filled[:, 1:]
    out = roles.copy()
    out[(~filled) & neighbor] = OUTLINE
    return out


def add_shading(roles: np.ndarray, base: int = BASE, shade: int = SHADE, light: int = LIGHT) -> np.ndarray:
    """Luz arriba/izquierda y sombra abajo/derecha sobre el color base."""
    out = roles.copy()
    edge = (roles == EMPTY) | (roles == OUTLINE)
    above = np.ones_like(edge)
    above[1:, :] = edge[:-1, :]
    below = np.ones_like(edge)
    below[:-1, :] = edge[1:, :]
    right = np.ones_like(edge)
    right[:, :-1] = edge[:, 1:]
    left = np.ones_like(edge)
    left[:, 1:] = edge[:, :-1]
    is_base = roles == base
    out[is_base & (below | right)] = shade
    out[is_base & (above | left) & ~(below | right)] = light
    return out


def colorize(roles: np.ndarray, palette: dict[int, Color]) -> np.ndarray:
    h, w = roles.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    for role, color in palette.items():
        mask = roles == role
        out[mask, :3] = color
        out[mask, 3] = 255
    out[roles == EMPTY] = 0
    return out


def save_png(array: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array, "RGBA").save(path)
    print("  ", path.relative_to(ROOT))


def save_normal(diffuse_path: Path, normal_path: Path, cell: tuple[int, int] | None, **kwargs) -> None:
    image = Image.open(diffuse_path)
    generate_normal_map(image, cell=cell, **kwargs).save(normal_path)
    print("  ", normal_path.relative_to(ROOT), "(normal map)")


# --------------------------------------------------------------------------
# FELIX
# --------------------------------------------------------------------------
FELIX_CELL = 48
FELIX_COLUMNS = 10
FELIX_ROWS = 13
# Fila: (nombre, frames) - debe coincidir con las animaciones de Player.tscn.
FELIX_LAYOUT = [
    ("idle", 6), ("run", 8), ("jump", 4), ("fall", 3), ("land", 3),
    ("howl", 8), ("scratch", 10), ("fury", 8), ("slam", 4),
    ("slam_impact", 6), ("hurt", 3), ("death", 8), ("victory", 6),
]

FELIX_SKINS: dict[str, dict[int, Color]] = {
    "classic": {
        OUTLINE: rgb("2b1820"), BASE: rgb("f2963a"), SHADE: rgb("c96628"), LIGHT: rgb("ffc46e"),
        STRIPE: rgb("b05022"), BELLY: rgb("ffe9c4"), EYE: rgb("8fd65a"), PUPIL: rgb("1e141e"),
        PINK: rgb("f08c96"), GLINT: rgb("ffffff"), CLAW: rgb("fffbe8"), POINTS: rgb("e0843a"), MOUTH: rgb("5a1e2a"),
    },
    "midnight": {
        OUTLINE: rgb("0c0a12"), BASE: rgb("34304a"), SHADE: rgb("242034"), LIGHT: rgb("565270"),
        STRIPE: rgb("2a263c"), BELLY: rgb("3e3a56"), EYE: rgb("ffd63c"), PUPIL: rgb("140f18"),
        PINK: rgb("b46e82"), GLINT: rgb("ffffff"), CLAW: rgb("f4f0ff"), POINTS: rgb("2c2840"), MOUTH: rgb("3a1224"),
    },
    "siamese": {
        OUTLINE: rgb("2a1c16"), BASE: rgb("f0e2c8"), SHADE: rgb("d6c4a6"), LIGHT: rgb("fff6e4"),
        STRIPE: rgb("e2d0b0"), BELLY: rgb("fff4de"), EYE: rgb("6eb4ff"), PUPIL: rgb("141824"),
        PINK: rgb("e89aa4"), GLINT: rgb("ffffff"), CLAW: rgb("ffffff"), POINTS: rgb("6a4632"), MOUTH: rgb("4a2020"),
    },
    "snow": {
        OUTLINE: rgb("3a3c52"), BASE: rgb("f4f4fa"), SHADE: rgb("cfd2e4"), LIGHT: rgb("ffffff"),
        STRIPE: rgb("dfe2f0"), BELLY: rgb("ffffff"), EYE: rgb("7ab8ff"), PUPIL: rgb("1c2030"),
        PINK: rgb("f4a6b8"), GLINT: rgb("ffffff"), CLAW: rgb("ffffff"), POINTS: rgb("e6e8f4"), MOUTH: rgb("6a2a3a"),
    },
    "cyber": {
        OUTLINE: rgb("0a0c1c"), BASE: rgb("3a4478"), SHADE: rgb("262c58"), LIGHT: rgb("5a6cb4"),
        STRIPE: rgb("00ffe0"), BELLY: rgb("4a5690"), EYE: rgb("ff3cc8"), PUPIL: rgb("12081c"),
        PINK: rgb("ff50c8"), GLINT: rgb("ffffff"), CLAW: rgb("9ffcff"), POINTS: rgb("00d8ff"), MOUTH: rgb("2a0830"),
    },
}


@dataclass
class CatPose:
    body: tuple[float, float, float, float] = (20, 36, 11, 6)
    head: tuple[float, float, float] = (32, 26, 7)
    # Patas: (x_arriba, y_arriba, x_abajo, y_abajo)
    legs: list[tuple[float, float, float, float]] = field(default_factory=lambda: [
        (12, 38, 12, 45), (15, 38, 15, 45), (27, 38, 27, 45), (30, 38, 30, 45)])
    tail: list[tuple[float, float]] = field(default_factory=lambda: [(10, 34), (6, 31), (4, 26), (5, 21), (7, 18)])
    tail_width: int = 3
    ears_back: int = 0
    eyes: str = "open"  # open, closed, x, glow, happy, angry
    mouth: str = ""  # "", open, hiss
    spikes: bool = False
    arch: float = 0.0
    claws: list[tuple[float, float]] = field(default_factory=list)
    paw: tuple[float, float, float, float] | None = None
    speed_lines: bool = False
    curled: bool = False
    lying: bool = False
    sitting: bool = False


def draw_cat(pose: CatPose) -> np.ndarray:
    c = Canvas(FELIX_CELL, FELIX_CELL)
    bx, by, brx, bry = pose.body
    hx, hy, hr = pose.head

    if pose.curled:
        # Bola compacta (Golpe Sísmico): cuerpo redondo con patas hacia abajo.
        c.ellipse(bx, by, brx, bry, BASE)
        c.ellipse(bx + 1, by + 2, brx - 4, bry - 4, BELLY)
        for x in (bx - 5, bx - 1, bx + 3, bx + 7):
            c.line([(x, by + bry - 2), (x, by + bry + 3)], POINTS, 2)
        c.ellipse(hx, hy, hr, hr, BASE)
        _ears(c, hx, hy, hr, pose.ears_back)
        _face(c, hx, hy, hr, pose)
        _stripes_head(c, hx, hy, hr)
    elif pose.lying:
        # Tumbado de lado (muerte): patas hacia arriba.
        c.ellipse(bx, by, brx, bry, BASE)
        c.ellipse(bx, by + 2, brx - 3, bry - 3, BELLY)
        for (x0, y0, x1, y1) in pose.legs:
            c.line([(x0, y0), (x1, y1)], POINTS, 2)
        c.line(pose.tail, BASE, pose.tail_width)
        c.ellipse(hx, hy, hr, hr, BASE)
        _ears(c, hx, hy, hr, 1)
        _face(c, hx, hy, hr, pose)
    else:
        # Cola detrás del cuerpo.
        c.line(pose.tail, BASE, pose.tail_width + (1 if pose.spikes else 0))
        tail_tip = pose.tail[-1]
        c.ellipse(tail_tip[0], tail_tip[1], 1.5, 1.5, POINTS)
        # Patas traseras primero (quedan detrás).
        for (x0, y0, x1, y1) in pose.legs[:2]:
            c.line([(x0, y0), (x1, y1)], SHADE, 2)
            c.point(x1, y1, POINTS)
            c.point(x1 + 1, y1, POINTS)
        if pose.sitting:
            c.ellipse(bx, by, brx, bry, BASE)
            c.ellipse(bx + 2, by + 1, brx - 4, bry - 2, BELLY)
        else:
            c.ellipse(bx, by, brx, bry, BASE)
            if pose.arch > 0:
                c.ellipse(bx, by - pose.arch, brx - 3, bry, BASE)
            c.ellipse(bx + 2, by + bry - 3, brx - 4, 2.5, BELLY)
        # Rayas de atigrado en el lomo.
        for i in range(3):
            sx = bx - brx * 0.5 + i * brx * 0.45
            top = by - bry - pose.arch + 1
            c.line([(sx, top), (sx + 1, top + 3)], STRIPE, 1)
        if pose.spikes:
            top = by - bry - pose.arch
            for i in range(5):
                sx = bx - brx + 3 + i * (2 * brx - 6) / 4
                c.poly([(sx - 2, top + 2), (sx, top - 3), (sx + 2, top + 2)], BASE)
        for (x0, y0, x1, y1) in pose.legs[2:]:
            c.line([(x0, y0), (x1, y1)], BASE, 2)
            c.point(x1, y1, POINTS)
            c.point(x1 + 1, y1, POINTS)
        # Cuello: une cabeza y cuerpo aunque la pose estire la cabeza (aullido).
        c.line([(hx - 2, hy + hr - 2), (bx + brx - 5, by - bry + 3)], BASE, 5)
        # Cabeza.
        c.ellipse(hx, hy, hr, hr, BASE)
        c.ellipse(hx + hr * 0.45, hy + hr * 0.45, hr * 0.45, hr * 0.32, BELLY)
        _ears(c, hx, hy, hr, pose.ears_back)
        _stripes_head(c, hx, hy, hr)
        _face(c, hx, hy, hr, pose)
        # La pata del zarpazo va delante de la cabeza para que se lea bien.
        if pose.paw is not None:
            x0, y0, x1, y1 = pose.paw
            c.line([(x0, y0), (x1, y1)], BASE, 3)
            c.ellipse(x1, y1, 2, 2, POINTS)

    roles = c.array()
    roles = add_shading(roles)
    roles = add_outline(roles)
    # Garras y líneas de velocidad van por encima del contorno.
    over = Canvas(FELIX_CELL, FELIX_CELL)
    for (x, y) in pose.claws:
        over.line([(x, y), (x + 3, y - 2)], CLAW, 1)
    if pose.speed_lines:
        for x in (bx - 8, bx - 2, bx + 5, bx + 10):
            over.line([(x, 2), (x, 8 + (int(x) % 3) * 3)], CLAW, 1)
    over_arr = over.array()
    roles[over_arr != EMPTY] = over_arr[over_arr != EMPTY]
    return roles


def _ears(c: Canvas, hx: float, hy: float, hr: float, ears_back: int) -> None:
    lean = 2 * ears_back
    for side in (-1, 1):
        base_x = hx + side * hr * 0.55
        tip = (base_x + side * 1 - lean, hy - hr - 5 + abs(ears_back))
        c.poly([(base_x - 3, hy - hr + 3), tip, (base_x + 3, hy - hr + 2)], POINTS)
        c.poly([(base_x - 1, hy - hr + 2), (tip[0], tip[1] + 2), (base_x + 1, hy - hr + 2)], PINK)


def _stripes_head(c: Canvas, hx: float, hy: float, hr: float) -> None:
    for dx in (-2, 0, 2):
        c.line([(hx + dx, hy - hr + 1), (hx + dx, hy - hr + 3)], STRIPE, 1)


def _face(c: Canvas, hx: float, hy: float, hr: float, pose: CatPose) -> None:
    eye_y = hy - 1
    for ex in (hx - 1, hx + 4):
        if pose.eyes in ("open", "glow", "angry"):
            iris = GLINT if pose.eyes == "glow" else EYE
            c.rect(ex, eye_y - 1, ex + 1, eye_y + 1, iris)
            c.point(ex + 1, eye_y, PUPIL)
            c.point(ex + 1, eye_y + 1, PUPIL)
            c.point(ex, eye_y - 1, GLINT)
            if pose.eyes == "angry":
                c.line([(ex - 1, eye_y - 3), (ex + 2, eye_y - 2)], PUPIL, 1)
        elif pose.eyes == "closed":
            c.line([(ex, eye_y + 1), (ex + 1, eye_y + 1)], PUPIL, 1)
        elif pose.eyes == "happy":
            c.point(ex, eye_y, PUPIL)
            c.point(ex + 1, eye_y - 1, PUPIL)
            c.point(ex + 2, eye_y, PUPIL)
        elif pose.eyes == "x":
            c.line([(ex, eye_y - 1), (ex + 2, eye_y + 1)], PUPIL, 1)
            c.line([(ex, eye_y + 1), (ex + 2, eye_y - 1)], PUPIL, 1)
    c.point(hx + 6, hy + 2, PINK)
    c.point(hx + 5, hy + 2, PINK)
    if pose.mouth == "open":
        c.ellipse(hx + 5, hy + 3, 2, 2.5, MOUTH)
        c.point(hx + 5, hy + 4, PINK)
    elif pose.mouth == "hiss":
        c.rect(hx + 3, hy + 3, hx + 6, hy + 5, MOUTH)
        c.point(hx + 3, hy + 3, CLAW)
        c.point(hx + 6, hy + 3, CLAW)


def _legs(front: float, back: float, lift_f: float = 0, lift_b: float = 0, y_top: float = 38,
          spread: float = 0) -> list[tuple[float, float, float, float]]:
    """Cuatro patas con desplazamiento de pasos (front/back) y elevación."""
    return [
        (12, y_top, 12 + back - spread, 45 - lift_b),
        (15, y_top, 15 - back - spread, 45 - lift_b * 0.5),
        (27, y_top, 27 + front + spread, 45 - lift_f),
        (30, y_top, 30 - front + spread, 45 - lift_f * 0.5),
    ]


def felix_frames() -> dict[str, list[CatPose]]:
    base = CatPose()
    frames: dict[str, list[CatPose]] = {}

    # IDLE: respiración + cola que se balancea + parpadeo.
    idle = []
    for i in range(6):
        breath = [0, 0, 1, 1, 0, 0][i]
        sway = [0, 1, 2, 2, 1, 0][i]
        idle.append(replace(
            base,
            body=(20, 36 + breath * 0.5, 11, 6 + breath * 0.5),
            head=(32, 26 + breath, 7),
            tail=[(10, 34), (6, 31), (4 - sway, 26), (4 - sway, 21), (6 - sway, 18)],
            eyes="closed" if i == 4 else "open",
        ))
    frames["idle"] = idle

    # RUN: galope de 8 frames.
    run = []
    cycle = [(4, -4, 2, 0, -1), (5, -5, 1, 2, -2), (2, -2, 0, 3, -2), (-2, 3, 0, 2, -1),
             (-4, 4, 0, 0, 0), (-5, 5, 2, 0, 1), (-2, 2, 3, 0, 1), (2, -3, 2, 0, 0)]
    for (front, back, lift_f, lift_b, bob) in cycle:
        run.append(replace(
            base,
            body=(20, 35 + bob, 12, 5.5),
            head=(33, 25 + bob, 7),
            legs=_legs(front, back, lift_f, lift_b, 37 + bob),
            tail=[(9, 33 + bob), (5, 31 + bob), (2, 30 + bob), (0, 28 + bob)],
            ears_back=1,
        ))
    frames["run"] = run

    # JUMP: agacharse, impulso, subida.
    frames["jump"] = [
        replace(base, body=(20, 38, 12, 5), head=(32, 29, 7), legs=_legs(1, -1, 0, 0, 40)),
        replace(base, body=(21, 32, 11, 6), head=(33, 22, 7), legs=_legs(4, 6, 0, 0, 36),
                tail=[(10, 32), (5, 33), (1, 35)]),
        replace(base, body=(21, 30, 11, 6), head=(33, 21, 7), legs=_legs(3, 3, 6, 4, 34),
                tail=[(10, 31), (5, 33), (2, 36)]),
        replace(base, body=(21, 29, 11, 6), head=(33, 20, 7), legs=_legs(2, 2, 8, 6, 33),
                tail=[(10, 30), (6, 33), (3, 37)]),
    ]

    # FALL: patas estiradas hacia abajo, cola arriba.
    fall = []
    for i in range(3):
        flap = [0, 1, 2][i]
        fall.append(replace(
            base, body=(21, 31, 11, 6), head=(33, 22, 7), legs=_legs(-1, 1, -1, 0, 35),
            tail=[(10, 30), (7, 25), (6 + flap, 20), (8 + flap, 15)], ears_back=-1 if i == 1 else 0,
        ))
    frames["fall"] = fall

    # LAND: aplastamiento y recuperación.
    frames["land"] = [
        replace(base, body=(20, 39, 13, 4), head=(32, 31, 7), legs=_legs(2, -2, 0, 0, 41, 1)),
        replace(base, body=(20, 37, 12, 5), head=(32, 28, 7), legs=_legs(1, -1, 0, 0, 39)),
        replace(base, body=(20, 36, 11, 6), head=(32, 26, 7)),
    ]

    # HOWL: inhalar (0-2), soltar (3), sostener (4-6), recuperar (7).
    howl = []
    for i in range(8):
        if i < 3:
            howl.append(replace(base, body=(20, 36 + i * 0.5, 11 + i * 0.3, 6), head=(31, 28 + i, 7),
                                eyes="closed", ears_back=1))
        elif i < 7:
            rise = 3 if i == 3 else 4
            howl.append(replace(base, body=(20, 35, 11, 6.5), head=(34, 22 - rise + 2, 7),
                                eyes="closed", mouth="open", spikes=i in (3, 4),
                                tail=[(10, 34), (6, 30), (5, 24), (7, 19), (9, 16)]))
        else:
            howl.append(replace(base, head=(32, 25, 7)))
    frames["howl"] = howl

    # SCRATCH: 10 frames a 24 FPS, zarpazos en frames impares (1,3,5,7,9).
    scratch = []
    for i in range(10):
        lean = (21, 36, 11, 6)
        if i % 2 == 1:
            up = i % 4 == 1
            tip_y = 30 if up else 36
            paw = (31, 35, 43, tip_y)
            claws = [(44, tip_y - 2), (45, tip_y), (44, tip_y + 2)]
            scratch.append(replace(base, body=lean, head=(33, 26, 7), paw=paw, claws=claws,
                                   eyes="angry", legs=_legs(3, -3, 0, 0), ears_back=1))
        else:
            scratch.append(replace(base, body=lean, head=(32, 26, 7), paw=(30, 35, 35, 33),
                                   eyes="angry", legs=_legs(2, -2, 0, 0), ears_back=1))
    frames["scratch"] = scratch

    # FURY: lomo arqueado estilo "gato de Halloween", pelo erizado, ojos brillantes.
    fury = []
    for i in range(8):
        arch = min(i, 4) * 1.5
        fury.append(replace(
            base, body=(20, 36 - arch * 0.3, 11, 6), head=(33, 27, 7), arch=arch,
            spikes=i >= 2, eyes="glow" if i >= 3 else "angry", mouth="hiss" if i >= 5 else "",
            tail=[(10, 33), (8, 27), (8, 21), (9, 15), (10, 11)], ears_back=1,
            legs=_legs(0, 0, 0, 0, 38, -1),
        ))
    frames["fury"] = fury

    # SLAM: 0-1 anticipación (bola), 2-3 picado con líneas de velocidad.
    frames["slam"] = [
        replace(base, curled=True, body=(24, 27, 9, 8), head=(30, 22, 6), eyes="angry", ears_back=1),
        replace(base, curled=True, body=(24, 26, 9, 8), head=(30, 21, 6), eyes="angry", ears_back=1),
        replace(base, curled=True, body=(24, 30, 8, 9), head=(29, 24, 6), eyes="angry",
                ears_back=1, speed_lines=True),
        replace(base, curled=True, body=(24, 31, 8, 9), head=(29, 25, 6), eyes="angry",
                ears_back=1, speed_lines=True),
    ]

    # SLAM IMPACT: aplastado con patas abiertas y recuperación.
    impact = []
    for i in range(6):
        squash = [3, 2.5, 2, 1, 0.5, 0][i]
        impact.append(replace(
            base, body=(20, 37 + squash * 0.7, 11 + squash, 6 - squash * 0.6),
            head=(32, 27 + squash, 7), legs=_legs(squash, -squash, 0, 0, 39, squash),
            eyes="angry" if i < 4 else "open", ears_back=1 if i < 3 else 0, spikes=i < 2,
        ))
    frames["slam_impact"] = impact

    # HURT: retroceso con ojos cerrados y pelo erizado.
    frames["hurt"] = [
        replace(base, body=(19, 35, 11, 6), head=(30, 24, 7), eyes="closed", spikes=True, ears_back=1),
        replace(base, body=(18, 34, 11, 6), head=(29, 23, 7), eyes="x", spikes=True, ears_back=1),
        replace(base, body=(19, 35, 11, 6), head=(30, 25, 7), eyes="closed", ears_back=1),
    ]

    # DEATH: tambaleo y caída de lado (8 frames).
    death = []
    for i in range(8):
        if i < 3:
            death.append(replace(base, body=(20, 36 + i, 11, 6), head=(31, 27 + i * 2, 7),
                                 eyes="x", ears_back=1))
        else:
            death.append(replace(
                base, lying=True, body=(22, 41, 12, 5), head=(34, 39, 6.5), eyes="x",
                legs=[(16, 38, 15, 33 - (i == 3)), (19, 38, 19, 32), (26, 38, 27, 33), (29, 38, 30, 34)],
                tail=[(10, 42), (6, 43), (3, 43)],
            ))
    frames["death"] = death

    # VICTORY: sentado, feliz, cola que se enrosca.
    victory = []
    for i in range(6):
        bob = [0, 0, 1, 1, 0, 0][i]
        victory.append(replace(
            base, sitting=True, body=(24, 37 + bob * 0.5, 8, 8), head=(27, 24 + bob, 7), eyes="happy",
            legs=[(20, 41, 19, 45), (23, 41, 23, 45), (27, 40, 27, 45), (29, 40, 30, 45)],
            tail=[(17, 43), (13, 43), (10, 41), (9 + (i % 3), 38)],
        ))
    frames["victory"] = victory
    return frames


def build_felix() -> None:
    print("Felix")
    frames = felix_frames()
    sheet_roles = np.zeros((FELIX_ROWS * FELIX_CELL, FELIX_COLUMNS * FELIX_CELL), dtype=np.uint8)
    for row, (name, count) in enumerate(FELIX_LAYOUT):
        poses = frames[name]
        assert len(poses) == count, (name, len(poses), count)
        for col, pose in enumerate(poses):
            y, x = row * FELIX_CELL, col * FELIX_CELL
            sheet_roles[y:y + FELIX_CELL, x:x + FELIX_CELL] = draw_cat(pose)
    for skin, palette in FELIX_SKINS.items():
        save_png(colorize(sheet_roles, palette), ASSETS / "sprites/player" / f"felix_{skin}.png")
    save_normal(ASSETS / "sprites/player/felix_classic.png", ASSETS / "sprites/player/felix_normal.png",
                (FELIX_CELL, FELIX_CELL), bevel=4, strength=2.4, detail=0.3)


# --------------------------------------------------------------------------
# ENEMIGOS
# --------------------------------------------------------------------------
DOG_PALETTE = {
    OUTLINE: rgb("1c1418"), BASE: rgb("8a6446"), SHADE: rgb("64462e"), LIGHT: rgb("b08a62"),
    STRIPE: rgb("5a3e2a"), BELLY: rgb("c8a680"), EYE: rgb("ffe04a"), PUPIL: rgb("140c10"),
    PINK: rgb("d0707a"), GLINT: rgb("ffffff"), CLAW: rgb("fff4d0"), POINTS: rgb("4a3222"), MOUTH: rgb("4a1418"),
}


def draw_dog(frame: int, anim: str) -> np.ndarray:
    c = Canvas(48, 32)
    bob = 0
    legs_f = legs_b = 0
    head_y = 14
    mouth = False
    tail_up = 2
    eyes_red = anim in ("alert", "charge")
    body_x = 22
    if anim == "idle":
        bob = [0, 0, 1, 1][frame]
        tail_up = [2, 3, 2, 1][frame]
    elif anim == "walk":
        legs_f, legs_b = [(2, -2), (1, -1), (-1, 1), (-2, 2), (-1, 1), (1, -1)][frame]
        bob = [0, 1, 0, 0, 1, 0][frame]
    elif anim == "alert":
        head_y = 16
        bob = 1
        mouth = frame % 2 == 1
        tail_up = -2
        body_x = 21 - (frame % 2)
    elif anim == "charge":
        legs_f, legs_b = [(4, -4), (2, -1), (-3, 3), (-4, 4), (-1, 2), (3, -3)][frame]
        bob = [0, -1, -1, 0, 1, 0][frame]
        head_y = 16
        mouth = True
        tail_up = -1
    elif anim == "recover":
        head_y = 17 + (frame % 2)
        bob = 1
        tail_up = -3
    elif anim == "hurt":
        head_y = 12
        bob = -1
    elif anim == "death":
        head_y = 18 + frame * 2
        bob = frame * 2
    c.line([(10, 18 + bob), (6, 15 + bob - tail_up), (5, 11 + bob - tail_up)], BASE, 3)
    for (x, dx) in ((13, legs_b), (17, -legs_b)):
        c.line([(x, 22 + bob), (x + dx, 29)], SHADE, 3)
    c.ellipse(body_x, 20 + bob, 12, 6, BASE)
    c.ellipse(body_x + 3, 23 + bob, 7, 2, BELLY)
    c.ellipse(body_x - 4, 17 + bob, 3, 2, STRIPE)
    for (x, dx) in ((28, legs_f), (31, -legs_f)):
        c.line([(x, 22 + bob), (x + dx, 29)], BASE, 3)
    hx = body_x + 13
    c.ellipse(hx, head_y + bob, 6, 5, BASE)
    c.rect(hx + 3, head_y + bob + 1, hx + 9, head_y + bob + 5, BELLY)
    c.point(hx + 9, head_y + bob + 1, PUPIL)
    c.point(hx + 8, head_y + bob + 1, PUPIL)
    c.poly([(hx - 5, head_y + bob - 3), (hx - 1, head_y + bob - 5), (hx - 3, head_y + bob + 3)], POINTS)
    eye_role = EYE if not eyes_red else PINK
    c.rect(hx + 1, head_y + bob - 2, hx + 2, head_y + bob - 1, eye_role)
    c.point(hx + 2, head_y + bob - 1, PUPIL)
    if eyes_red:
        c.line([(hx, head_y + bob - 4), (hx + 3, head_y + bob - 3)], PUPIL, 1)
    if mouth:
        c.rect(hx + 4, head_y + bob + 4, hx + 8, head_y + bob + 6, MOUTH)
        c.point(hx + 5, head_y + bob + 4, CLAW)
        c.point(hx + 7, head_y + bob + 4, CLAW)
    c.rect(hx - 4, head_y + bob + 3, hx - 2, head_y + bob + 5, PINK)
    roles = add_outline(add_shading(c.array()))
    if anim == "recover":
        over = Canvas(48, 32)
        for i in range(3):
            angle = frame * 1.2 + i * 2.1
            over.point(hx + math.cos(angle) * 6, head_y - 8 + math.sin(angle) * 2, CLAW)
        arr = over.array()
        roles[arr != EMPTY] = arr[arr != EMPTY]
    return roles


CROW_PALETTE = {
    OUTLINE: rgb("08070e"), BASE: rgb("262436"), SHADE: rgb("16141f"), LIGHT: rgb("4a3f6a"),
    STRIPE: rgb("3a3558"), BELLY: rgb("2e2b42"), EYE: rgb("ff4a3a"), PUPIL: rgb("08070e"),
    PINK: rgb("c8a040"), GLINT: rgb("ffffff"), CLAW: rgb("e8e0c0"), POINTS: rgb("1c1a2a"), MOUTH: rgb("c8a040"),
}


def draw_crow(frame: int, anim: str) -> np.ndarray:
    c = Canvas(32, 32)
    wing = {"fly": [-6, -3, 0, 3, 1, -3], "swoop": [4, 5, 4], "hurt": [-5, 5], "death": [5, 6, 7, 8]}[anim][frame]
    dive = 3 if anim == "swoop" else 0
    fall = frame * 3 if anim == "death" else 0
    cy = 17 + fall // 2
    c.poly([(9, cy + 1), (3, cy + 3 + dive), (5, cy + 5 + dive), (10, cy + 3)], POINTS)
    c.poly([(12, cy - 1), (17, cy - 1), (15 - dive, cy + wing), (9, cy + wing + 1)], SHADE)
    c.ellipse(15, cy + 1, 7, 4, BASE)
    c.ellipse(22, cy - 2 + dive, 4, 3.5, BASE)
    c.poly([(25, cy - 3 + dive), (30, cy - 1 + dive), (25, cy + dive)], PINK)
    if anim in ("hurt", "death"):
        c.line([(22, cy - 4 + dive), (24, cy - 2 + dive)], PUPIL, 1)
        c.line([(22, cy - 2 + dive), (24, cy - 4 + dive)], PUPIL, 1)
    else:
        c.point(23, cy - 3 + dive, EYE)
    c.poly([(13, cy), (19, cy), (18 + dive, cy + wing - 2), (10, cy + wing - 3)], LIGHT)
    c.line([(14, cy + 5), (14, cy + 7)], PINK, 1)
    c.line([(17, cy + 5), (17, cy + 7)], PINK, 1)
    return add_outline(c.array())


VACUUM_PALETTE = {
    OUTLINE: rgb("0e1016"), BASE: rgb("5a6070"), SHADE: rgb("3a3e4a"), LIGHT: rgb("8a92a6"),
    STRIPE: rgb("2a2d36"), BELLY: rgb("c8ccd8"), EYE: rgb("3ae8ff"), PUPIL: rgb("121418"),
    PINK: rgb("ff4040"), GLINT: rgb("ffffff"), CLAW: rgb("d0d4e0"), POINTS: rgb("202228"), MOUTH: rgb("202228"),
}


def draw_vacuum(frame: int, anim: str) -> np.ndarray:
    c = Canvas(32, 24)
    squash = 1 if (anim == "bump" and frame == 0) else 0
    c.ellipse(16, 15 + squash, 13 + squash, 5 - squash, BASE)
    c.rect(4, 15 + squash, 28, 19, SHADE)
    c.ellipse(16, 12 + squash, 9, 3, BELLY)
    c.rect(26, 13 + squash, 29, 18, STRIPE)
    led = EYE if (anim == "move" and frame % 2 == 0) or anim == "bump" else PUPIL
    if anim == "bump":
        led = PINK
    c.rect(15, 9 + squash, 17, 10 + squash, led)
    c.ellipse(9, 20, 2, 2, POINTS)
    c.ellipse(23, 20, 2, 2, POINTS)
    angle = frame * math.pi / 4
    bx, by = 29, 20
    c.line([(bx - math.cos(angle) * 3, by - math.sin(angle) * 1),
            (bx + math.cos(angle) * 3, by + math.sin(angle) * 1)], CLAW, 1)
    roles = add_outline(add_shading(c.array()))
    return roles


def build_enemies() -> None:
    print("Enemigos")
    # Perro: celdas 48x32, 6 columnas x 7 filas.
    dog_layout = [("idle", 4), ("walk", 6), ("alert", 4), ("charge", 6), ("recover", 4), ("hurt", 2), ("death", 4)]
    sheet = np.zeros((7 * 32, 6 * 48), dtype=np.uint8)
    for row, (anim, count) in enumerate(dog_layout):
        for col in range(count):
            sheet[row * 32:(row + 1) * 32, col * 48:(col + 1) * 48] = draw_dog(col, anim)
    save_png(colorize(sheet, DOG_PALETTE), ASSETS / "sprites/enemies/stray_dog.png")
    save_normal(ASSETS / "sprites/enemies/stray_dog.png", ASSETS / "sprites/enemies/stray_dog_n.png", (48, 32))

    # Cuervo: celdas 32x32, 6 columnas x 4 filas.
    crow_layout = [("fly", 6), ("swoop", 3), ("hurt", 2), ("death", 4)]
    sheet = np.zeros((4 * 32, 6 * 32), dtype=np.uint8)
    for row, (anim, count) in enumerate(crow_layout):
        for col in range(count):
            sheet[row * 32:(row + 1) * 32, col * 32:(col + 1) * 32] = draw_crow(col, anim)
    save_png(colorize(sheet, CROW_PALETTE), ASSETS / "sprites/enemies/crow.png")
    save_normal(ASSETS / "sprites/enemies/crow.png", ASSETS / "sprites/enemies/crow_n.png", (32, 32), bevel=2)

    # Aspiradora: celdas 32x24, 4 columnas x 2 filas.
    vac_layout = [("move", 4), ("bump", 3)]
    sheet = np.zeros((2 * 24, 4 * 32), dtype=np.uint8)
    for row, (anim, count) in enumerate(vac_layout):
        for col in range(count):
            sheet[row * 24:(row + 1) * 24, col * 32:(col + 1) * 32] = draw_vacuum(col, anim)
    save_png(colorize(sheet, VACUUM_PALETTE), ASSETS / "sprites/enemies/robot_vacuum.png")
    save_normal(ASSETS / "sprites/enemies/robot_vacuum.png", ASSETS / "sprites/enemies/robot_vacuum_n.png",
                (32, 24), bevel=3, strength=2.8)


# --------------------------------------------------------------------------
# OBSTÁCULOS Y MUNDO
# --------------------------------------------------------------------------
def build_obstacles() -> None:
    print("Obstáculos")
    # Ovillo: 8 frames de 32x32 (rotación dibujada, no rotada en el motor).
    yarn_palette = {OUTLINE: rgb("3a1030"), BASE: rgb("e05aa0"), SHADE: rgb("b03a7c"), LIGHT: rgb("ff9ccc"),
                    STRIPE: rgb("8a2862"), GLINT: rgb("ffe0f0")}
    sheet = np.zeros((32, 8 * 32), dtype=np.uint8)
    for f in range(8):
        c = Canvas(32, 32)
        c.ellipse(16, 17, 13, 13, BASE)
        base_angle = f * math.pi / 4
        for k in range(4):
            a = base_angle + k * math.pi / 4
            pts = []
            for t in np.linspace(-1.0, 1.0, 9):
                x = 16 + math.cos(a) * t * 11 + math.sin(a) * (1 - t * t) * 4
                y = 17 + math.sin(a) * t * 11 - math.cos(a) * (1 - t * t) * 4
                pts.append((x, y))
            c.line(pts, STRIPE, 1)
        c.point(10, 10, GLINT)
        c.point(11, 10, GLINT)
        roles = add_outline(add_shading(c.array()))
        sheet[:, f * 32:(f + 1) * 32] = roles
    save_png(colorize(sheet, yarn_palette), ASSETS / "sprites/obstacles/yarn_ball.png")
    save_normal(ASSETS / "sprites/obstacles/yarn_ball.png", ASSETS / "sprites/obstacles/yarn_ball_n.png",
                (32, 32), bevel=6, strength=2.6)

    # Caja de madera 24x24.
    crate_palette = {OUTLINE: rgb("24140c"), BASE: rgb("b07a44"), SHADE: rgb("7c5230"), LIGHT: rgb("d8a466"),
                     STRIPE: rgb("5e3c22"), BELLY: rgb("9aa0aa")}
    c = Canvas(24, 24)
    c.rect(1, 1, 22, 22, BASE)
    for y in (7, 15):
        c.line([(1, y), (22, y)], STRIPE, 1)
    c.line([(2, 2), (21, 21)], SHADE, 2)
    c.line([(2, 21), (21, 2)], SHADE, 2)
    for (x, y) in ((1, 1), (19, 1), (1, 19), (19, 19)):
        c.rect(x, y, x + 3, y + 3, BELLY)
    save_png(colorize(add_outline(add_shading(c.array())), crate_palette), ASSETS / "sprites/obstacles/crate.png")
    save_normal(ASSETS / "sprites/obstacles/crate.png", ASSETS / "sprites/obstacles/crate_n.png", None,
                bevel=3, strength=2.0, detail=0.6)

    # Charco: textura de 48x10 para NinePatchRect (bordes de 8 px) + normal/especular.
    water = np.zeros((10, 48, 4), dtype=np.uint8)
    img = Image.new("RGBA", (48, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 1, 16, 9], fill=(52, 70, 110, 230))
    d.ellipse([31, 1, 47, 9], fill=(52, 70, 110, 230))
    d.rectangle([8, 1, 39, 9], fill=(52, 70, 110, 230))
    water = np.asarray(img).copy()
    water[2, 6:42][water[2, 6:42, 3] > 0] = (150, 190, 240, 255)
    water[4, 12:20][water[4, 12:20, 3] > 0] = (110, 150, 210, 240)
    save_png(water, ASSETS / "sprites/obstacles/puddle.png")
    flat = np.zeros_like(water)
    flat[..., :3] = (128, 128, 255)
    flat[..., 3] = 255
    save_png(flat, ASSETS / "sprites/obstacles/puddle_n.png")
    spec = np.zeros_like(water)
    spec[..., :3] = 235
    spec[..., 3] = 255
    save_png(spec, ASSETS / "sprites/obstacles/puddle_specular.png")


def build_world_props() -> None:
    print("Mundo")
    # Moneda: 6 frames de 12x12.
    coin_palette = {OUTLINE: rgb("4a2a08"), BASE: rgb("ffc83a"), SHADE: rgb("d88a18"), LIGHT: rgb("fff08a"),
                    GLINT: rgb("ffffff"), STRIPE: rgb("c07010")}
    widths = [5, 4, 2.5, 1, 2.5, 4]
    sheet = np.zeros((12, 72), dtype=np.uint8)
    for f, w in enumerate(widths):
        c = Canvas(12, 12)
        c.ellipse(6, 6, w, 4.5, BASE)
        if w >= 4:
            c.point(6, 5, STRIPE)
            c.point(5, 6, STRIPE)
            c.point(7, 6, STRIPE)
            c.point(6, 7, STRIPE)
        if w >= 2.5:
            c.point(6 - w + 1.5, 4, GLINT)
        sheet[:, f * 12:(f + 1) * 12] = add_outline(add_shading(c.array()))
    save_png(colorize(sheet, coin_palette), ASSETS / "sprites/world/coin.png")

    # Refugio de Gatos 96x80.
    shelter_palette = {
        OUTLINE: rgb("241418"), BASE: rgb("c88a58"), SHADE: rgb("96603a"), LIGHT: rgb("e8b07a"),
        STRIPE: rgb("a0302c"), BELLY: rgb("ffd27a"), EYE: rgb("fff2b0"), PUPIL: rgb("3a1c14"),
        PINK: rgb("ff7a8a"), GLINT: rgb("ffffff"), POINTS: rgb("7a2622"), MOUTH: rgb("5a4a44"), CLAW: rgb("6ab04c"),
    }
    c = Canvas(96, 80)
    c.rect(66, 8, 74, 26, MOUTH)
    c.rect(65, 6, 75, 9, PUPIL)
    c.rect(12, 34, 84, 77, BASE)
    for y in range(40, 77, 6):
        c.line([(13, y), (83, y)], SHADE, 1)
    c.poly([(4, 36), (48, 6), (92, 36)], STRIPE)
    for i in range(6):
        y = 12 + i * 4
        c.line([(48 - (y - 6) * 1.45, y), (48 + (y - 6) * 1.45, y)], POINTS, 1)
    c.ellipse(48, 24, 6, 6, BELLY)
    c.ellipse(48, 24, 4, 4, EYE)
    c.line([(48, 18), (48, 30)], PUPIL, 1)
    c.line([(42, 24), (54, 24)], PUPIL, 1)
    c.rect(38, 50, 58, 77, PUPIL)
    c.ellipse(48, 50, 10, 8, PUPIL)
    c.rect(40, 52, 56, 77, SHADE)
    c.ellipse(48, 52, 8, 6, SHADE)
    c.ellipse(48, 60, 5, 4, BELLY)
    c.poly([(44, 58), (45, 54), (47, 57)], BELLY)
    c.poly([(49, 57), (51, 54), (52, 58)], BELLY)
    c.point(54, 66, EYE)
    for wx in (20, 66):
        c.rect(wx, 46, wx + 11, 58, PUPIL)
        c.rect(wx + 1, 47, wx + 10, 57, BELLY)
        c.line([(wx + 5, 47), (wx + 5, 57)], PUPIL, 1)
        c.line([(wx + 1, 52), (wx + 10, 52)], PUPIL, 1)
        c.rect(wx - 1, 58, wx + 12, 60, SHADE)
    c.ellipse(48, 42, 4, 3, PINK)
    c.poly([(44, 42), (48, 47), (52, 42)], PINK)
    for fx in (16, 78):
        c.rect(fx, 70, fx + 4, 76, STRIPE)
        c.ellipse(fx + 2, 68, 3, 2, CLAW)
    roles = add_outline(add_shading(c.array()))
    save_png(colorize(roles, shelter_palette), ASSETS / "sprites/world/cat_shelter.png")
    save_normal(ASSETS / "sprites/world/cat_shelter.png", ASSETS / "sprites/world/cat_shelter_n.png", None,
                bevel=3, strength=2.0, detail=0.5)

    # Farola 16x64.
    lamp_palette = {OUTLINE: rgb("0e0c14"), BASE: rgb("3c3a4e"), SHADE: rgb("26243a"), LIGHT: rgb("5c5a74"),
                    BELLY: rgb("fff0b0"), EYE: rgb("ffd060")}
    c = Canvas(16, 64)
    c.rect(7, 12, 8, 63, BASE)
    c.rect(5, 58, 10, 63, BASE)
    c.rect(3, 8, 12, 10, BASE)
    c.poly([(4, 10), (11, 10), (10, 15), (5, 15)], EYE)
    c.rect(6, 11, 9, 13, BELLY)
    c.rect(6, 4, 9, 7, BASE)
    save_png(colorize(add_outline(add_shading(c.array())), lamp_palette), ASSETS / "sprites/world/street_lamp.png")
    save_normal(ASSETS / "sprites/world/street_lamp.png", ASSETS / "sprites/world/street_lamp_n.png", None,
                bevel=2, strength=2.0)

    # Cartel de tutorial 40x28.
    sign_palette = {OUTLINE: rgb("24140c"), BASE: rgb("c09058"), SHADE: rgb("8a6038"), LIGHT: rgb("e0b47a"),
                    STRIPE: rgb("5e3c22")}
    c = Canvas(40, 28)
    c.rect(18, 14, 21, 27, SHADE)
    c.rect(2, 2, 37, 17, BASE)
    for y in (7, 12):
        c.line([(3, y), (36, y)], STRIPE, 1)
    save_png(colorize(add_outline(add_shading(c.array())), sign_palette), ASSETS / "sprites/world/sign.png")


def build_fx() -> None:
    print("Efectos")
    # Zarpazo: 4 frames de 32x32.
    frames = []
    for f in range(4):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        alpha = [200, 255, 170, 80][f]
        length = [0.55, 1.0, 1.0, 1.0][f]
        for k in range(3):
            y0 = 8 + k * 6
            pts = []
            for t in np.linspace(0, length, 8):
                pts.append((4 + t * 24, y0 + math.sin(t * math.pi) * -5 + t * 4))
            color = (230, 250, 255, alpha) if k != 1 else (170, 235, 255, alpha)
            d.line(pts, fill=color, width=2 if f < 2 else 1)
        frames.append(np.asarray(img))
    save_png(np.concatenate(frames, axis=1), ASSETS / "sprites/fx/slash.png")

    # Grieta del Golpe Sísmico: 3 variantes de 64x16.
    rng = random.Random(7)
    variants = []
    for v in range(3):
        c = Canvas(64, 16)
        for side in (-1, 1):
            x, y = 32, 3
            for _ in range(5 + v):
                nx = x + side * rng.randint(3, 7)
                ny = min(max(y + rng.randint(-1, 2), 1), 13)
                c.line([(x, y), (nx, ny)], PUPIL, 2 if abs(nx - 32) < 16 else 1)
                if rng.random() < 0.5:
                    c.line([(nx, ny), (nx + side * 2, ny + rng.randint(2, 4))], PUPIL, 1)
                x, y = nx, ny
        for _ in range(8):
            c.point(rng.randint(12, 52), rng.randint(0, 4), SHADE)
        variants.append(c.array())
    crack = colorize(np.concatenate(variants, axis=1), {PUPIL: rgb("1a1014"), SHADE: rgb("6a5a5a")})
    save_png(crack, ASSETS / "sprites/fx/crack.png")

    def small(size: tuple[int, int], pixels: list[str], color: Color, name: str) -> None:
        img = np.zeros((size[1], size[0], 4), dtype=np.uint8)
        for y, row in enumerate(pixels):
            for x, ch in enumerate(row):
                if ch == "#":
                    img[y, x] = (*color, 255)
        save_png(img, ASSETS / "sprites/fx" / name)

    small((2, 2), ["##", "##"], (255, 255, 255), "particle_pixel.png")
    small((3, 3), [".#.", "###", ".#."], (255, 255, 255), "particle_spark.png")
    small((4, 4), [".##.", "####", "####", ".##."], (255, 255, 255), "particle_dust.png")
    small((7, 6), [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."], (255, 120, 150),
          "particle_heart.png")

    # Textura de luz "por bandas": degradado radial escalonado (look Pixel Art).
    size = 128
    yy, xx = np.mgrid[0:size, 0:size]
    dist = np.sqrt((xx - size / 2 + 0.5) ** 2 + (yy - size / 2 + 0.5) ** 2) / (size / 2)
    intensity = np.clip(1.0 - dist, 0.0, 1.0) ** 1.4
    banded = np.floor(intensity * 5.0) / 5.0
    light = np.zeros((size, size, 4), dtype=np.uint8)
    light[..., :3] = 255
    light[..., 3] = (banded * 255).astype(np.uint8)
    save_png(light, ASSETS / "sprites/fx/light_banded.png")


# --------------------------------------------------------------------------
# TILESET (16x16) - 8 columnas x 4 filas
# --------------------------------------------------------------------------
def build_tiles() -> None:
    print("Tileset")
    T = 16
    atlas = np.zeros((4 * T, 8 * T, 4), dtype=np.uint8)
    rng = random.Random(3)

    def put(col: int, row: int, tile: np.ndarray) -> None:
        atlas[row * T:(row + 1) * T, col * T:(col + 1) * T] = tile

    def solid(color: Color) -> np.ndarray:
        tile = np.zeros((T, T, 4), dtype=np.uint8)
        tile[..., :3] = color
        tile[..., 3] = 255
        return tile

    def speckle(tile: np.ndarray, colors: list[Color], count: int, y_min: int = 0) -> None:
        for _ in range(count):
            x, y = rng.randrange(T), rng.randrange(y_min, T)
            tile[y, x, :3] = rng.choice(colors)

    # Suelo (acera): top con bordillo + relleno de tierra/hormigón.
    for i in range(3):
        top = solid(rgb("4a4058"))
        top[0:2, :, :3] = rgb("a8a0b8")
        top[2:4, :, :3] = rgb("7a7090")
        top[4, :, :3] = rgb("2e2838")
        speckle(top, [rgb("3a3248"), rgb("5a5068")], 14, 5)
        if i == 1:
            top[0:2, 5:7, :3] = rgb("7a7090")
        if i == 2:
            top[6:9, 10:12, :3] = rgb("2e2838")
        put(i, 0, top)
        fill = solid(rgb("3a3246"))
        speckle(fill, [rgb("2e2838"), rgb("4a4058"), rgb("282230")], 26)
        if i == 1:
            fill[7:9, 3:7, :3] = rgb("5a5068")
        put(i, 1, fill)

    # Ladrillo (muros/pilares sólidos).
    def brick(top: bool) -> np.ndarray:
        tile = solid(rgb("8a3a36"))
        for y in range(0, T, 4):
            tile[y, :, :3] = rgb("3a1c1e")
            offset = 0 if (y // 4) % 2 == 0 else 4
            for x in range(offset, T, 8):
                tile[y:y + 4, x, :3] = rgb("3a1c1e")
            tile[y + 1, :, :3] = np.where(tile[y + 1, :, :3] == rgb("8a3a36"), rgb("a44c44"), tile[y + 1, :, :3])
        if top:
            tile[0:2, :, :3] = rgb("c86a5a")
        return tile

    put(3, 0, brick(True))
    put(3, 1, brick(False))

    # Tejado (niveles de azotea).
    roof = solid(rgb("5a4a6a"))
    roof[0:2, :, :3] = rgb("9a8ab0")
    for x in range(0, T, 4):
        roof[2:, x, :3] = rgb("3a3048")
    put(4, 0, roof)
    roof_fill = solid(rgb("46384e"))
    speckle(roof_fill, [rgb("3a3048"), rgb("56466a")], 20)
    put(4, 1, roof_fill)

    # Plataforma de madera de un solo sentido (izquierda, centro, derecha).
    for i in range(3):
        tile = np.zeros((T, T, 4), dtype=np.uint8)
        tile[0:5, :, :3] = rgb("a07048")
        tile[0:5, :, 3] = 255
        tile[0, :, :3] = rgb("d0a070")
        tile[4, :, :3] = rgb("4a2e1c")
        tile[1:4, 7, :3] = rgb("6a4630")
        if i == 0:
            tile[0:5, 0, :3] = rgb("4a2e1c")
            tile[5:10, 2:4, :3] = rgb("4a2e1c")
            tile[5:10, 2:4, 3] = 255
        if i == 2:
            tile[0:5, 15, :3] = rgb("4a2e1c")
            tile[5:10, 12:14, :3] = rgb("4a2e1c")
            tile[5:10, 12:14, 3] = 255
        put(i, 2, tile)

    # Bloque metálico (fábrica).
    metal = solid(rgb("5a6272"))
    metal[0, :, :3] = rgb("9aa4b8")
    metal[:, 0, :3] = rgb("8a94a8")
    metal[15, :, :3] = rgb("30343e")
    metal[:, 15, :3] = rgb("30343e")
    for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
        metal[y, x, :3] = rgb("c8d0e0")
    put(3, 2, metal)

    # Pared de fondo (decorativa, sin colisión): ladrillo oscuro y ventanas.
    for i in range(2):
        wall = brick(False)
        wall[..., :3] = (wall[..., :3].astype(np.float32) * 0.45).astype(np.uint8)
        put(5, i, wall)
    win_dark = solid(rgb("1c1824"))
    win_dark[1:15, 1:15, :3] = rgb("2a3a5a")
    win_dark[8, 1:15, :3] = rgb("1c1824")
    win_dark[1:15, 8, :3] = rgb("1c1824")
    put(6, 0, win_dark)
    win_lit = win_dark.copy()
    win_lit[1:15, 1:15, :3] = rgb("ffcc66")
    win_lit[8, 1:15, :3] = rgb("5a3a24")
    win_lit[1:15, 8, :3] = rgb("5a3a24")
    win_lit[2:4, 2:4, :3] = rgb("fff2c0")
    put(6, 1, win_lit)

    # Hierba / maleza de primer plano (sin colisión).
    grass = np.zeros((T, T, 4), dtype=np.uint8)
    for x in range(0, T, 2):
        h = rng.randint(3, 7)
        grass[T - h:T, x, :3] = rgb("4a8a4a") if x % 4 else rgb("6ab06a")
        grass[T - h:T, x, 3] = 255
    put(7, 0, grass)

    save_png(atlas, ASSETS / "tilesets/city_tiles.png")
    # Normal map: tiles opacos con modo "tile" (sin costuras) y plataformas con bisel.
    normal_tile = np.asarray(generate_normal_map(Image.fromarray(atlas), cell=(T, T), mode="tile", strength=1.6))
    normal_sprite = np.asarray(generate_normal_map(Image.fromarray(atlas), cell=(T, T), mode="sprite", bevel=2))
    normal = normal_tile.copy()
    normal[2 * T:3 * T, 0:3 * T] = normal_sprite[2 * T:3 * T, 0:3 * T]
    normal[0:T, 7 * T:8 * T] = normal_sprite[0:T, 7 * T:8 * T]
    save_png(normal, ASSETS / "tilesets/city_tiles_n.png")


# --------------------------------------------------------------------------
# FONDOS PARALLAX (960 px de ancho, repetibles horizontalmente)
# --------------------------------------------------------------------------
def build_backgrounds() -> None:
    print("Fondos")
    W = 960
    rng = random.Random(11)

    # Cielo: degradado por bandas (look Pixel Art) de 8x400, se escala en el nivel.
    stops = [(0.0, rgb("1a1436")), (0.35, rgb("3a2858")), (0.62, rgb("7a3a6a")),
             (0.8, rgb("d8645a")), (1.0, rgb("ffb070"))]
    H = 400
    sky = np.zeros((H, 8, 4), dtype=np.uint8)
    for y in range(H):
        t = y / (H - 1)
        t = math.floor(t * 24) / 24
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                sky[y, :, :3] = [round(a + (b - a) * k) for a, b in zip(c0, c1)]
                break
    sky[..., 3] = 255
    save_png(sky, ASSETS / "backgrounds/sky_gradient.png")

    # Estrellas y luna (capa estática).
    stars = np.zeros((240, W, 4), dtype=np.uint8)
    for _ in range(140):
        x, y = rng.randrange(W), rng.randrange(0, 200)
        b = rng.choice([150, 200, 255])
        stars[y, x] = (b, b, min(255, b + 20), 255)
    img = Image.fromarray(stars)
    d = ImageDraw.Draw(img)
    d.ellipse([700, 30, 730, 60], fill=(255, 240, 200, 255))
    d.ellipse([708, 26, 740, 58], fill=(0, 0, 0, 0))
    save_png(np.asarray(img), ASSETS / "backgrounds/stars.png")

    # Nubes.
    clouds = Image.new("RGBA", (W, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(clouds)
    for _ in range(7):
        cx, cy = rng.randrange(0, W), rng.randrange(20, 120)
        for k in range(5):
            rx, ry = rng.randint(14, 30), rng.randint(6, 12)
            ox = cx + rng.randint(-30, 30)
            oy = cy + rng.randint(-4, 6)
            for wrap in (-W, 0, W):
                d.ellipse([ox - rx + wrap, oy - ry, ox + rx + wrap, oy + ry], fill=(140, 90, 150, 255))
                d.ellipse([ox - rx + 2 + wrap, oy - ry + 3, ox + rx - 2 + wrap, oy + ry], fill=(214, 120, 120, 255))
                d.line([(ox - rx + 4 + wrap, oy + ry), (ox + rx - 4 + wrap, oy + ry)], fill=(255, 176, 120, 255))
    save_png(np.asarray(clouds), ASSETS / "backgrounds/clouds.png")

    def skyline(height: int, base_color: Color, window_color: Color, min_h: int, max_h: int,
                min_w: int, max_w: int, window_chance: float, details: bool) -> np.ndarray:
        img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        x = 0
        while x < W:
            w = rng.randint(min_w, max_w)
            h = rng.randint(min_h, max_h)
            top = height - h
            w = min(w, W - x)
            d.rectangle([x, top, x + w - 1, height], fill=(*base_color, 255))
            if details and rng.random() < 0.35:
                d.rectangle([x + w // 2 - 1, top - 10, x + w // 2, top], fill=(*base_color, 255))
            if details and rng.random() < 0.25:
                d.rectangle([x + 3, top - 7, x + 11, top], fill=(*base_color, 255))
                d.polygon([(x + 2, top - 7), (x + 7, top - 11), (x + 12, top - 7)], fill=(*base_color, 255))
            for wy in range(top + 5, height - 4, 7):
                for wx in range(x + 3, x + w - 3, 5):
                    if rng.random() < window_chance:
                        d.rectangle([wx, wy, wx + 1, wy + 2], fill=(*window_color, 255))
            x += w + rng.randint(0, 3)
        return np.asarray(img)

    save_png(skyline(220, rgb("3a2a52"), rgb("b89060"), 60, 200, 30, 70, 0.18, False),
             ASSETS / "backgrounds/city_far.png")
    save_png(skyline(200, rgb("221a34"), rgb("ffc860"), 50, 150, 40, 90, 0.28, True),
             ASSETS / "backgrounds/city_near.png")


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------
def build_ui() -> None:
    print("UI")

    def pixels(rows: list[str], colors: dict[str, tuple[int, int, int, int]]) -> np.ndarray:
        h, w = len(rows), len(rows[0])
        img = np.zeros((h, w, 4), dtype=np.uint8)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in colors:
                    img[y, x] = colors[ch]
        return img

    heart = [
        ".oo...oo..",
        "ohho.ohho.",
        "ohhhohhhho",
        "ohhhhhhhho",
        "ohhhhhhhho",
        ".ohhhhhho.",
        "..ohhhho..",
        "...ohho...",
        "....oo....",
    ]
    save_png(pixels(heart, {"o": (40, 16, 24, 255), "h": (240, 70, 90, 255)}), ASSETS / "ui/heart_full.png")
    save_png(pixels(heart, {"o": (40, 16, 24, 255), "h": (70, 50, 70, 255)}), ASSETS / "ui/heart_empty.png")
    coin = [
        "..oooo..",
        ".oyyyyo.",
        "oyywyyyo",
        "oywyyyyo",
        "oyyyyydo",
        "oyyyyydo",
        ".oyyddo.",
        "..oooo..",
    ]
    save_png(pixels(coin, {"o": (74, 42, 8, 255), "y": (255, 200, 58, 255), "w": (255, 250, 200, 255),
                           "d": (216, 138, 24, 255)}), ASSETS / "ui/coin_icon.png")
    lock = [
        "..oooo..",
        ".o....o.",
        ".o....o.",
        "oooooooo",
        "oggggggo",
        "oggoaggo",
        "oggoaggo",
        "oggggggo",
        "oooooooo",
    ]
    save_png(pixels(lock, {"o": (30, 24, 40, 255), "g": (200, 170, 90, 255), "a": (60, 40, 30, 255)}),
             ASSETS / "ui/lock.png")

    def circle_button(size: int, fill: tuple[int, int, int, int], ring: tuple[int, int, int, int]) -> Image.Image:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([0, 0, size - 1, size - 1], fill=ring)
        d.ellipse([2, 2, size - 3, size - 3], fill=fill)
        return img

    def icon_layer(size: int, kind: str, color: tuple[int, int, int, int]) -> Image.Image:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = size / 2
        s = size / 48
        if kind == "jump":
            d.polygon([(c, c - 11 * s), (c + 10 * s, c + 1 * s), (c + 4 * s, c + 1 * s), (c + 4 * s, c + 10 * s),
                       (c - 4 * s, c + 10 * s), (c - 4 * s, c + 1 * s), (c - 10 * s, c + 1 * s)], fill=color)
        elif kind == "scratch":
            for k in range(3):
                ox = (k - 1) * 7 * s
                d.line([(c - 8 * s + ox, c - 10 * s), (c + 4 * s + ox, c + 10 * s)], fill=color, width=max(2, round(3 * s)))
        elif kind == "howl":
            d.ellipse([c - 12 * s, c - 5 * s, c - 2 * s, c + 5 * s], fill=color)
            d.polygon([(c - 12 * s, c - 3 * s), (c - 11 * s, c - 10 * s), (c - 7 * s, c - 5 * s)], fill=color)
            for r in (6, 11, 16):
                d.arc([c - 4 * s - r * s, c - r * s, c - 4 * s + r * s, c + r * s], -50, 50, fill=color,
                      width=max(1, round(2 * s)))
        elif kind == "fury":
            d.polygon([(c, c - 13 * s), (c + 8 * s, c), (c + 6 * s, c + 9 * s), (c - 6 * s, c + 9 * s),
                       (c - 8 * s, c), (c - 3 * s, c - 4 * s)], fill=(255, 110, 60, 255))
            d.polygon([(c, c - 5 * s), (c + 4 * s, c + 3 * s), (c, c + 8 * s), (c - 4 * s, c + 3 * s)],
                      fill=(255, 220, 120, 255))
        elif kind == "slam":
            d.polygon([(c, c + 9 * s), (c + 9 * s, c - 1 * s), (c + 4 * s, c - 1 * s), (c + 4 * s, c - 11 * s),
                       (c - 4 * s, c - 11 * s), (c - 4 * s, c - 1 * s), (c - 9 * s, c - 1 * s)], fill=color)
            d.line([(c - 14 * s, c + 12 * s), (c + 14 * s, c + 12 * s)], fill=color, width=max(1, round(2 * s)))
        elif kind == "pause":
            d.rectangle([c - 7 * s, c - 9 * s, c - 2 * s, c + 9 * s], fill=color)
            d.rectangle([c + 2 * s, c - 9 * s, c + 7 * s, c + 9 * s], fill=color)
        return img

    buttons = {"jump": 56, "scratch": 48, "howl": 44, "slam": 44, "fury": 40, "pause": 32}
    for kind, size in buttons.items():
        icon_color = (245, 240, 255, 255)
        normal = circle_button(size, (26, 20, 40, 170), (230, 220, 255, 220))
        pressed = circle_button(size, (120, 100, 170, 220), (255, 255, 255, 255))
        for img in (normal, pressed):
            img.alpha_composite(icon_layer(size, kind, icon_color))
        normal.save(ASSETS / "ui" / f"btn_{kind}.png")
        pressed.save(ASSETS / "ui" / f"btn_{kind}_pressed.png")
        print("   ", f"assets/ui/btn_{kind}.png (+ _pressed)")
    for size in {buttons[k] for k in ("scratch", "howl", "slam", "fury")}:
        cd = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(cd).ellipse([2, 2, size - 3, size - 3], fill=(0, 0, 0, 150))
        cd.save(ASSETS / "ui" / f"cooldown_{size}.png")
        print("   ", f"assets/ui/cooldown_{size}.png")

    base = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.ellipse([0, 0, 71, 71], fill=(230, 220, 255, 200))
    d.ellipse([3, 3, 68, 68], fill=(26, 20, 40, 120))
    base.save(ASSETS / "ui/joystick_base.png")
    tip = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(tip)
    d.ellipse([0, 0, 31, 31], fill=(40, 30, 60, 255))
    d.ellipse([2, 2, 29, 29], fill=(230, 220, 255, 235))
    d.ellipse([7, 6, 13, 11], fill=(255, 255, 255, 255))
    tip.save(ASSETS / "ui/joystick_tip.png")
    print("    assets/ui/joystick_base.png, joystick_tip.png")


def build_icon_svg() -> None:
    """Icono de la app (Felix) como SVG de píxeles: nítido en cualquier tamaño."""
    print("Icono")
    face = [
        "................",
        "..O..........O..",
        ".OPO........OPO.",
        ".OPPO......OPPO.",
        ".OBBBOOOOOOBBBO.",
        ".OBBSBBBBBBSBBO.",
        "OBBBBBSBBSBBBBBO",
        "OBBGGBBBBBBGGBBO",
        "OBBGKBBBBBBGKBBO",
        "OBBBBBBNNBBBBBBO",
        "OBCCBBBBBBBBCCBO",
        ".OBBCCCMMCCCBBO.",
        "..OBBCCCCCCBBO..",
        "...OOBBBBBBOO...",
        ".....OOOOOO.....",
        "................",
    ]
    colors = {"O": "#2b1820", "B": "#f2963a", "S": "#b05022", "G": "#8fd65a", "K": "#1e141e",
              "N": "#f08c96", "C": "#ffe9c4", "M": "#5a1e2a", "P": "#f08c96"}
    rects = []
    for y, row in enumerate(face):
        for x, ch in enumerate(row):
            if ch in colors:
                rects.append(f'<rect x="{x * 7 + 8}" y="{y * 7 + 8}" width="7" height="7" fill="{colors[ch]}"/>')
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" shape-rendering="crispEdges">'
           '<rect width="128" height="128" rx="18" fill="#2a2140"/>' + "".join(rects) + "</svg>\n")
    (ROOT / "icon.svg").write_text(svg, encoding="utf-8")
    print("   icon.svg")


def main() -> None:
    random.seed(1)
    build_felix()
    build_enemies()
    build_obstacles()
    build_world_props()
    build_fx()
    build_tiles()
    build_backgrounds()
    build_ui()
    build_icon_svg()
    print("Listo.")


if __name__ == "__main__":
    main()
