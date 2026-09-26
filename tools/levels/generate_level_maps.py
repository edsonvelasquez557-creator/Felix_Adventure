#!/usr/bin/env python3
"""Genera los mapas ASCII (greybox) de los 10 niveles de Felix.

Cada nivel se arma encadenando TRAMOS diseñados para la física de Felix
(salto de ~3,6 tiles de alto y ~6 de largo corriendo). La progresión de
enemigos y obstáculos por nivel está en LEVELS (ver también
docs/03_Enemigos_Obstaculos_y_Niveles.md).

Salida: tools/levels/level_XX.txt (cabecera + mapa + capa de fondo).
Después, tools/LevelBuilder.gd convierte cada .txt en scenes/levels/Level_N.tscn.

    python tools/levels/generate_level_maps.py

¡Ojo! Sobrescribe los .txt. Si editas un nivel a mano en el editor de Godot,
no vuelvas a generar su .tscn.

Leyenda del mapa principal:
  .  vacío            #  suelo            B  ladrillo       M  metal
  =  plataforma de un solo sentido
  g  hierba (primer plano)
  P  inicio de Felix  c  moneda           S  Refugio de Gatos (meta)
  D  perro            C  cuervo           W  cuervo que hace picados
  V  aspiradora       ~  charco           X  caja colgante
  K  grúa de cajas    Y  cesto de ovillos L  farola           T  cartel
Capa de fondo (decorativa): w pared de ladrillo, o ventana iluminada, n ventana oscura.
"""

from __future__ import annotations

import random
from pathlib import Path

ROWS = 23
GROUND = 19  # primera fila de suelo (la superficie queda en y = 19 * 16 = 304 px)
OUT = Path(__file__).resolve().parent


class LevelMap:
    def __init__(self) -> None:
        self.main: dict[tuple[int, int], str] = {}
        self.back: dict[tuple[int, int], str] = {}
        self.x = 0

    def put(self, x: int, y: int, ch: str) -> None:
        self.main[(x, y)] = ch

    def ground(self, x0: int, x1: int, top: int = GROUND) -> None:
        for x in range(x0, x1):
            for y in range(top, ROWS):
                self.main[(x, y)] = "#"

    def width(self) -> int:
        return max(x for x, _ in self.main) + 1

    def render(self, layer: dict[tuple[int, int], str]) -> list[str]:
        w = self.width()
        return ["".join(layer.get((x, y), ".") for x in range(w)) for y in range(ROWS)]


# ------------------------------------------------------------------ tramos

def start(m: LevelMap) -> None:
    """Pared izquierda + zona segura: ningún enemigo ve a Felix al aparecer."""
    for y in range(4, GROUND):
        m.put(0, y, "#")
        m.put(1, y, "#")
    m.ground(0, 18)
    m.put(4, GROUND - 1, "P")
    m.put(12, GROUND - 1, "L")
    m.x = 18


def finish(m: LevelMap) -> None:
    x = m.x
    m.ground(x, x + 16)
    m.put(x + 3, GROUND - 1, "L")
    for i in range(3):
        m.put(x + 5 + i, GROUND - 3, "c")
    m.put(x + 10, GROUND - 1, "S")
    for y in range(4, GROUND):
        m.put(x + 16, y, "#")
        m.put(x + 17, y, "#")
    m.ground(x + 16, x + 18)
    m.x = x + 18


def flat(m: LevelMap, n: int, coins: int = 0, lamp: bool = False, grass: bool = False) -> None:
    x = m.x
    m.ground(x, x + n)
    for i in range(coins):
        m.put(x + 2 + i * 2, GROUND - 3, "c")
    if lamp:
        m.put(x + n // 2, GROUND - 1, "L")
    if grass:
        for gx in range(x, x + n, 3):
            if (gx, GROUND - 1) not in m.main:
                m.put(gx, GROUND - 1, "g")
    m.x = x + n


def sign(m: LevelMap) -> None:
    m.ground(m.x, m.x + 4)
    m.put(m.x + 2, GROUND - 1, "T")
    m.x += 4


def gap(m: LevelMap, w: int, coins: bool = True) -> None:
    x = m.x
    if coins:
        for i in range(w):
            m.put(x + i, GROUND - 4 - (1 if 0 < i < w - 1 else 0), "c")
    m.x = x + w


def stairs(m: LevelMap, height: int = 2, plateau: int = 5, coins: bool = True) -> None:
    x = m.x
    m.ground(x, x + 2 * height + plateau + 2)
    for step in range(height):
        for y in range(GROUND - step - 1, GROUND):
            m.put(x + 1 + step, y, "B")
            m.put(x + 2 * height + plateau - step, y, "B")
    for px in range(x + height + 1, x + height + plateau + 1):
        for y in range(GROUND - height, GROUND):
            m.put(px, y, "B")
        if coins and (px - x) % 2 == 0:
            m.put(px, GROUND - height - 2, "c")
    m.x = x + 2 * height + plateau + 2


def platforms(m: LevelMap, coins: bool = True) -> None:
    x = m.x
    m.ground(x, x + 16)
    for px in range(x + 2, x + 7):
        m.put(px, GROUND - 3, "=")
    for px in range(x + 8, x + 13):
        m.put(px, GROUND - 6, "=")
    if coins:
        for px in range(x + 9, x + 12):
            m.put(px, GROUND - 8, "c")
        m.put(x + 4, GROUND - 5, "c")
    m.x = x + 16


def pit_platform(m: LevelMap) -> None:
    """Foso ancho con un tablón en medio: dos saltos seguidos."""
    x = m.x
    for px in range(x + 3, x + 6):
        m.put(px, GROUND - 1, "=")
    for i in range(3):
        m.put(x + 3 + i, GROUND - 3, "c")
    m.x = x + 9


def puddle(m: LevelMap, n: int, w: int) -> None:
    x = m.x
    m.ground(x, x + n)
    start_x = x + (n - w) // 2
    for px in range(start_x, start_x + w):
        m.put(px, GROUND - 1, "~")
    m.x = x + n


def dog_zone(m: LevelMap, n: int, dogs: int, coins: int = 2) -> None:
    x = m.x
    m.ground(x, x + n)
    for i in range(dogs):
        m.put(x + 5 + i * max(4, (n - 8) // max(dogs, 1)), GROUND - 1, "D")
    for i in range(coins):
        m.put(x + 3 + i * 3, GROUND - 4, "c")
    m.x = x + n


def crow_zone(m: LevelMap, n: int, crows: int, swoop: bool = False) -> None:
    x = m.x
    m.ground(x, x + n)
    for i in range(crows):
        m.put(x + 6 + i * 9, GROUND - 6 - (i % 2) * 2, "W" if swoop else "C")
    for i in range(n // 4):
        m.put(x + 2 + i * 4, GROUND - 3, "c")
    m.x = x + n


def vacuum_room(m: LevelMap, n: int = 16, vacuums: int = 1) -> None:
    x = m.x
    m.ground(x, x + n)
    for y in (GROUND - 2, GROUND - 1):
        m.put(x, y, "B")
        m.put(x + n - 1, y, "B")
    for i in range(vacuums):
        m.put(x + 4 + i * 6, GROUND - 1, "V")
    for i in range(3):
        m.put(x + 5 + i * 3, GROUND - 5, "c")
    m.x = x + n


def crate_zone(m: LevelMap, n: int, crates: int) -> None:
    x = m.x
    m.ground(x, x + n)
    for i in range(crates):
        m.put(x + 4 + i * 7, GROUND - 9, "X")
    m.x = x + n


def crane_zone(m: LevelMap, n: int = 18) -> None:
    x = m.x
    m.ground(x, x + n)
    m.put(x + n // 2, GROUND - 13, "K")
    for i in range(3):
        m.put(x + n // 2 - 3 + i * 3, GROUND - 3, "c")
    m.x = x + n


def yarn_run(m: LevelMap, n: int = 24) -> None:
    """Pasillo largo con un cesto de ovillos al fondo que rueda hacia Felix."""
    x = m.x
    m.ground(x, x + n)
    for y in range(GROUND - 3, GROUND):
        m.put(x + n - 1, y, "B")
        m.put(x + n - 2, y, "B")
    for px in range(x + n - 5, x + n - 2):
        m.put(px, GROUND - 3, "=")
    m.put(x + n - 4, GROUND - 4, "Y")
    for i in range(4):
        m.put(x + 3 + i * 4, GROUND - 4, "c")
    m.x = x + n


def building(m: LevelMap, x0: int, x1: int, top: int = 6, lit: float = 0.35, seed: int = 0) -> None:
    rng = random.Random(seed)
    for x in range(x0, x1):
        for y in range(top, GROUND):
            ch = "w"
            if (y - top) % 3 == 1 and (x - x0) % 3 == 1 and y < GROUND - 2:
                ch = "o" if rng.random() < lit else "n"
            m.back[(x, y)] = ch


# ------------------------------------------------------------------ niveles

def level_01(m: LevelMap) -> None:
    start(m)
    sign(m)                       # moverse
    flat(m, 10, coins=4, grass=True)
    sign(m)                       # saltar
    stairs(m, 2, 4)
    flat(m, 4)
    gap(m, 3)
    flat(m, 8, lamp=True)
    sign(m)                       # charcos
    puddle(m, 12, 4)
    platforms(m)
    sign(m)                       # rasguños
    dog_zone(m, 16, 1)
    flat(m, 6, lamp=True)
    sign(m)                       # aullido
    dog_zone(m, 18, 2)
    sign(m)                       # golpe sísmico
    stairs(m, 3, 3, coins=False)
    dog_zone(m, 14, 1)
    sign(m)                       # furia
    dog_zone(m, 20, 2, coins=3)
    gap(m, 3)
    flat(m, 6, lamp=True, grass=True)
    sign(m)                       # refugio
    finish(m)
    building(m, 20, 36, 7, seed=1)
    building(m, 70, 92, 5, seed=2)
    building(m, 128, 150, 8, seed=3)


def level_02(m: LevelMap) -> None:
    start(m)
    flat(m, 6, coins=2)
    gap(m, 3)
    crow_zone(m, 18, 2)
    platforms(m)
    gap(m, 4)
    flat(m, 6, lamp=True)
    dog_zone(m, 14, 1)
    pit_platform(m)
    crow_zone(m, 20, 2)
    stairs(m, 3, 4)
    gap(m, 3)
    crow_zone(m, 16, 1)
    dog_zone(m, 14, 1)
    finish(m)


def level_03(m: LevelMap) -> None:
    start(m)
    flat(m, 8, coins=3, lamp=True)
    crate_zone(m, 18, 2)
    dog_zone(m, 14, 1)
    gap(m, 3)
    crow_zone(m, 16, 1)
    crate_zone(m, 22, 3)
    platforms(m)
    puddle(m, 10, 3)
    dog_zone(m, 18, 2)
    crate_zone(m, 16, 2)
    finish(m)
    building(m, 12, 40, 6, seed=4)
    building(m, 90, 120, 7, seed=5)


def level_04(m: LevelMap) -> None:
    start(m)
    flat(m, 6, coins=2)
    vacuum_room(m, 16, 1)
    puddle(m, 12, 5)
    dog_zone(m, 16, 1)
    vacuum_room(m, 20, 2)
    gap(m, 3)
    platforms(m)
    puddle(m, 14, 6)
    vacuum_room(m, 18, 1)
    dog_zone(m, 16, 2)
    finish(m)
    building(m, 10, 60, 5, lit=0.5, seed=6)
    building(m, 100, 150, 6, lit=0.5, seed=7)


def level_05(m: LevelMap) -> None:
    start(m)
    flat(m, 6, coins=2)
    yarn_run(m, 24)
    crane_zone(m, 18)
    vacuum_room(m, 16, 1)
    gap(m, 3)
    yarn_run(m, 26)
    stairs(m, 2, 4)
    crane_zone(m, 20)
    dog_zone(m, 14, 1)
    finish(m)


def level_06(m: LevelMap) -> None:
    start(m)
    puddle(m, 12, 5)
    crow_zone(m, 18, 2, swoop=True)
    dog_zone(m, 16, 2)
    puddle(m, 12, 6)
    gap(m, 3)
    crow_zone(m, 20, 2, swoop=True)
    platforms(m)
    dog_zone(m, 18, 3)
    puddle(m, 14, 6)
    crow_zone(m, 16, 1, swoop=True)
    finish(m)


def level_07(m: LevelMap) -> None:
    start(m)
    dog_zone(m, 16, 2)
    vacuum_room(m, 18, 2)
    crane_zone(m, 18)
    gap(m, 4)
    dog_zone(m, 18, 2)
    platforms(m)
    vacuum_room(m, 20, 2)
    crane_zone(m, 16)
    dog_zone(m, 20, 3)
    finish(m)
    building(m, 12, 70, 4, lit=0.6, seed=8)
    building(m, 110, 170, 4, lit=0.6, seed=9)


def level_08(m: LevelMap) -> None:
    start(m)
    yarn_run(m, 26)
    vacuum_room(m, 18, 2)
    crate_zone(m, 18, 2)
    yarn_run(m, 28)
    gap(m, 3)
    crane_zone(m, 18)
    vacuum_room(m, 16, 1)
    yarn_run(m, 24)
    dog_zone(m, 16, 2)
    finish(m)


def level_09(m: LevelMap) -> None:
    start(m)
    crow_zone(m, 16, 2, swoop=True)
    gap(m, 4)
    platforms(m)
    pit_platform(m)
    dog_zone(m, 16, 2)
    crow_zone(m, 18, 3, swoop=True)
    gap(m, 4)
    stairs(m, 3, 5)
    crate_zone(m, 16, 2)
    pit_platform(m)
    crow_zone(m, 16, 2, swoop=True)
    vacuum_room(m, 16, 1)
    finish(m)


def level_10(m: LevelMap) -> None:
    start(m)
    flat(m, 6, coins=3, lamp=True)
    dog_zone(m, 16, 2)
    crow_zone(m, 16, 2, swoop=True)
    vacuum_room(m, 18, 2)
    crate_zone(m, 16, 2)
    yarn_run(m, 24)
    gap(m, 4)
    platforms(m)
    puddle(m, 12, 5)
    crane_zone(m, 18)
    dog_zone(m, 20, 3)
    pit_platform(m)
    crow_zone(m, 18, 3, swoop=True)
    flat(m, 8, lamp=True)
    finish(m)
    building(m, 12, 60, 5, lit=0.55, seed=10)
    building(m, 150, 230, 5, lit=0.65, seed=11)


LEVELS = [
    {
        "builder": level_01, "name": "Callejón al Anochecer", "theme": "street",
        "ambient": "#8f86c4", "background_tint": "#ffffff",
        "overrides": ["dog.alert_time=0.7", "dog.charge_speed=190.0", "dog.patrol_speed=35.0"],
        "signs": [
            "Muévete con A / D o las flechas | Desliza el pulgar izquierdo para moverte",
            "Salta con Espacio: mantenlo para llegar más alto | Toca el botón de salto: mantenlo para llegar más alto",
            "Los charcos te frenan: ¡sáltalos!",
            "K: Ráfaga de Rasguños (varios golpes seguidos) | Botón de garras: Ráfaga de Rasguños",
            "J: Aullido Expansivo, empuja a todos | Botón de ondas: Aullido Expansivo",
            "Salta y pulsa I: ¡Golpe Sísmico! | Salta y toca la flecha abajo: ¡Golpe Sísmico!",
            "L: Furia Felina, daño x2 durante 8 s | Botón de llama: Furia Felina (daño x2, 8 s)",
            "¡El Refugio de Gatos! Entra por la puerta",
        ],
    },
    {"builder": level_02, "name": "Tejados de Hojalata", "theme": "roof", "ambient": "#7f7cb8",
     "background_tint": "#e8e0ff", "overrides": ["dog.alert_time=0.6", "crow.wave_amplitude=16.0"]},
    {"builder": level_03, "name": "Mercado Nocturno", "theme": "street", "ambient": "#7a70ae",
     "background_tint": "#d8d0f0", "overrides": ["dog.alert_time=0.55", "hanging_crate.shake_time=0.5"]},
    {"builder": level_04, "name": "Lavandería 24 Horas", "theme": "brick", "ambient": "#7078a8",
     "background_tint": "#c8d0f0", "overrides": ["dog.alert_time=0.5", "vacuum.move_speed=65.0"]},
    {"builder": level_05, "name": "Almacén de Juguetes", "theme": "metal", "ambient": "#6c6c9c",
     "background_tint": "#c0b8e0", "overrides": ["vacuum.move_speed=75.0", "yarn.interval=3.6",
                                                "crates.interval=2.6"]},
    {"builder": level_06, "name": "Parque bajo la Lluvia", "theme": "street", "ambient": "#5c6690",
     "background_tint": "#9aa4c8", "overrides": ["dog.alert_time=0.45", "dog.charge_speed=220.0",
                                                "crow.swoop_cooldown=3.0"]},
    {"builder": level_07, "name": "Callejones de Neón", "theme": "brick", "ambient": "#6a5a9a",
     "background_tint": "#d0a8e8", "overrides": ["dog.alert_time=0.35", "dog.charge_speed=250.0",
                                                "vacuum.move_speed=85.0", "crates.interval=2.0"]},
    {"builder": level_08, "name": "Fábrica de Estambre", "theme": "metal", "ambient": "#665c8c",
     "background_tint": "#b8a8d8", "overrides": ["yarn.interval=2.8", "yarn.instance_properties={\"direction\": -1.0, \"bounce_on_walls\": false, \"roll_speed\": 125.0}",
                                                "vacuum.move_speed=85.0"]},
    {"builder": level_09, "name": "Tormenta en los Tejados", "theme": "roof", "ambient": "#4c5480",
     "background_tint": "#8088b0", "overrides": ["dog.alert_time=0.35", "dog.charge_speed=250.0",
                                                "crow.swoop_cooldown=2.2", "crow.swoop_speed=210.0"]},
    {"builder": level_10, "name": "El Gran Refugio", "theme": "street", "ambient": "#584c84",
     "background_tint": "#a898c8", "overrides": ["dog.alert_time=0.3", "dog.charge_speed=260.0",
                                                "crow.swoop_cooldown=2.0", "vacuum.move_speed=90.0",
                                                "yarn.interval=3.0", "crates.interval=2.0"]},
]


def main() -> None:
    for index, spec in enumerate(LEVELS, start=1):
        m = LevelMap()
        spec["builder"](m)
        lines = [f"name={spec['name']}", f"theme={spec['theme']}", f"ambient={spec['ambient']}",
                 f"background_tint={spec['background_tint']}"]
        lines += spec.get("overrides", [])
        lines += [f"sign={text}" for text in spec.get("signs", [])]
        signs_needed = sum(1 for ch in m.main.values() if ch == "T")
        assert signs_needed == len(spec.get("signs", [])), (index, signs_needed)
        lines.append("--- mapa")
        lines += m.render(m.main)
        lines.append("--- fondo")
        lines += m.render(m.back)
        path = OUT / f"level_{index:02d}.txt"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{path.name}: {m.width()} columnas")


if __name__ == "__main__":
    main()
