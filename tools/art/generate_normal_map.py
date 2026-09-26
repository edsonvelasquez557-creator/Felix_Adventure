#!/usr/bin/env python3
"""Genera normal maps para Pixel Art 2D (formato que espera Godot 4).

Los generadores de imágenes por IA solo entregan el color (difuso). Para que las
luces 2D de Godot (PointLight2D + CanvasModulate) den volumen, cada hoja de
sprites necesita su normal map con EXACTAMENTE la misma distribución de celdas.

Cómo se calcula:
  1. Altura por forma: distancia de cada píxel al borde transparente (bisel).
     Los bordes quedan "bajos" y el centro "alto": volumen redondeado.
  2. Altura por detalle: luminancia suavizada (líneas oscuras = surcos).
  3. Gradiente de la altura -> vector normal -> RGB.

Convención: Godot usa normal maps estilo OpenGL (verde = arriba, "Y+").
Si una herramienta externa exporta estilo DirectX, usa --invert-y.

Uso:
  python generate_normal_map.py felix_classic.png
  python generate_normal_map.py felix_classic.png -o felix_normal.png --cell 48x48
  python generate_normal_map.py city_tiles.png --mode tile --cell 16x16

Requisitos: pip install pillow numpy
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def _shift(array: np.ndarray, dy: int, dx: int, fill: float | bool) -> np.ndarray:
    """Desplaza un array rellenando con `fill` (sin envolver)."""
    result = np.full_like(array, fill)
    h, w = array.shape[:2]
    ys_src = slice(max(0, -dy), h - max(0, dy))
    xs_src = slice(max(0, -dx), w - max(0, dx))
    ys_dst = slice(max(0, dy), h - max(0, -dy))
    xs_dst = slice(max(0, dx), w - max(0, -dx))
    result[ys_dst, xs_dst] = array[ys_src, xs_src]
    return result


def _inner_distance(mask: np.ndarray, max_distance: int) -> np.ndarray:
    """Distancia (en erosiones 4-conexas) al borde transparente, hasta max_distance."""
    distance = np.zeros(mask.shape, dtype=np.float32)
    current = mask.copy()
    for _ in range(max_distance):
        distance += current
        current = (
            current
            & _shift(current, 1, 0, False)
            & _shift(current, -1, 0, False)
            & _shift(current, 0, 1, False)
            & _shift(current, 0, -1, False)
        )
        if not current.any():
            break
    return distance


def _box_blur(values: np.ndarray, radius: int, wrap: bool) -> np.ndarray:
    if radius <= 0:
        return values
    result = values.copy()
    for axis in (0, 1):
        acc = np.zeros_like(result)
        for offset in range(-radius, radius + 1):
            if wrap:
                acc += np.roll(result, offset, axis=axis)
            else:
                dy, dx = (offset, 0) if axis == 0 else (0, offset)
                shifted = _shift(result, dy, dx, 0.0)
                edge = _shift(np.ones_like(result), dy, dx, 0.0)
                acc += np.where(edge > 0, shifted, result)
        result = acc / (2 * radius + 1)
    return result


def _gradients(height: np.ndarray, wrap: bool) -> tuple[np.ndarray, np.ndarray]:
    if wrap:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    else:
        dx = (_shift(height, 0, -1, 0.0) - _shift(height, 0, 1, 0.0)) * 0.5
        dy = (_shift(height, -1, 0, 0.0) - _shift(height, 1, 0, 0.0)) * 0.5
    return dx, dy


def normal_map_for_cell(
    rgba: np.ndarray,
    mode: str = "sprite",
    bevel: int = 4,
    strength: float = 2.2,
    detail: float = 0.35,
    blur: int = 1,
    invert_y: bool = False,
) -> np.ndarray:
    """Calcula el normal map (RGBA uint8) de una celda o imagen completa."""
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    alpha = rgba[..., 3].astype(np.float32) / 255.0
    mask = alpha > 0.0
    luminance = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    if mode == "tile":
        # Tiles opacos y repetibles: solo detalle, con gradientes que envuelven
        # para que no aparezcan costuras entre tiles vecinos.
        height = _box_blur(luminance, blur, wrap=True)
        dx, dy = _gradients(height, wrap=True)
        strength_scale = strength * 2.0
    else:
        distance = _inner_distance(mask, bevel)
        shape = np.sqrt(np.clip(distance / float(bevel), 0.0, 1.0))  # perfil redondeado
        detail_height = _box_blur(luminance, blur, wrap=False)
        height = np.where(mask, shape + detail * detail_height, 0.0).astype(np.float32)
        dx, dy = _gradients(height, wrap=False)
        strength_scale = strength

    # Superficie z = h(x, y) con y hacia abajo en la imagen.
    # Normal (convención OpenGL, Y hacia arriba) = (-dh/dx, +dh/dy_imagen, 1).
    nx = -dx * strength_scale
    ny = dy * strength_scale
    if invert_y:
        ny = -ny
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)

    encoded = np.clip((normal * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    out = np.zeros(rgba.shape, dtype=np.uint8)
    out[..., :3] = encoded
    out[..., 3] = 255
    if mode != "tile":
        flat = np.array([128, 128, 255], dtype=np.uint8)
        out[~mask, :3] = flat
    return out


def generate_normal_map(
    image: Image.Image,
    cell: tuple[int, int] | None = None,
    **kwargs,
) -> Image.Image:
    """Genera el normal map de una imagen; con `cell` procesa cada celda aparte."""
    rgba = np.asarray(image.convert("RGBA"))
    out = np.zeros_like(rgba)
    if cell is None:
        out = normal_map_for_cell(rgba, **kwargs)
    else:
        cell_w, cell_h = cell
        h, w = rgba.shape[:2]
        for y in range(0, h, cell_h):
            for x in range(0, w, cell_w):
                block = rgba[y:y + cell_h, x:x + cell_w]
                out[y:y + cell_h, x:x + cell_w] = normal_map_for_cell(block, **kwargs)
    return Image.fromarray(out, "RGBA")


def _parse_cell(text: str | None) -> tuple[int, int] | None:
    if not text:
        return None
    width, height = text.lower().split("x")
    return int(width), int(height)


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera normal maps (OpenGL / Y+) para sprites 2D de Godot 4.")
    parser.add_argument("input", type=Path, help="PNG difuso (hoja de sprites o tileset)")
    parser.add_argument("-o", "--output", type=Path, help="PNG de salida (por defecto <entrada>_n.png)")
    parser.add_argument("--mode", choices=["sprite", "tile"], default="sprite",
                        help="sprite: bisel por silueta + detalle. tile: solo detalle, sin costuras")
    parser.add_argument("--cell", help="Procesa por celdas, p. ej. 48x48 (evita que frames vecinos se mezclen)")
    parser.add_argument("--bevel", type=int, default=4, help="Ancho del bisel en píxeles (modo sprite)")
    parser.add_argument("--strength", type=float, default=2.2, help="Intensidad del relieve")
    parser.add_argument("--detail", type=float, default=0.35, help="Peso del detalle por luminancia (modo sprite)")
    parser.add_argument("--blur", type=int, default=1, help="Suavizado de la altura en píxeles")
    parser.add_argument("--invert-y", action="store_true", help="Invierte el verde (convención DirectX)")
    args = parser.parse_args()

    output = args.output or args.input.with_name(args.input.stem + "_n.png")
    image = Image.open(args.input)
    result = generate_normal_map(
        image,
        cell=_parse_cell(args.cell),
        mode=args.mode,
        bevel=args.bevel,
        strength=args.strength,
        detail=args.detail,
        blur=args.blur,
        invert_y=args.invert_y,
    )
    result.save(output)
    print(f"Normal map guardado en {output}")


if __name__ == "__main__":
    main()
