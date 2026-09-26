# 06 · Prompts para generar el arte con IA

Prompts listos para copiar en **Midjourney**, **DALL·E / GPT‑Image** y **Stable Diffusion (SDXL)**. Están en inglés porque los modelos responden mejor en ese idioma; las explicaciones están en español.

## 0. Antes de empezar: qué esperar de la IA

- Las IA **no** generan hojas de sprites perfectas: los frames salen con tamaños distintos, "falsos píxeles" (bloques que no encajan en una rejilla real) y colores de más. El flujo profesional es: **IA para diseño y poses → limpieza en Aseprite → montaje en la rejilla** (ver [05 §7](05_Sprites_y_Animaciones.md#7-del-arte-generado-al-juego-pipeline)).
- **Consistencia del personaje**: genera primero una *model sheet* de Felix y úsala como referencia en todos los prompts siguientes:
  - Midjourney: `--oref <url de la imagen de Felix> --ow 100` (Omni Reference; en versiones anteriores `--cref <url> --cw 100`).
  - GPT‑Image / DALL·E: adjunta la imagen y escribe "use the attached character as the exact reference".
  - Stable Diffusion: IP‑Adapter con la imagen de referencia + ControlNet OpenPose para la pose + semilla fija.
- **Fondo**: pide fondo transparente cuando la herramienta lo soporte (GPT‑Image). Si no, usa **magenta plano `#FF00FF`**: se elimina con un clic y nunca aparece en el personaje.

## 1. Bloque de estilo (se añade a TODOS los prompts)

```text
pixel art game asset, 16-bit era style, crisp hard-edged pixels, no anti-aliasing, 1-pixel dark colored outline, limited 16-color palette, flat cel shading with light coming from the top-left, cozy dusk city mood, readable silhouette, orthographic side view, centered, plain flat magenta (#FF00FF) background
```

**Negativo** (Stable Diffusion: *negative prompt*; Midjourney: `--no`):

```text
blurry, anti-aliasing, soft gradients, painterly, 3d render, photorealistic, noise, dithering noise, jpeg artifacts, text, watermark, signature, cropped, extra limbs, extra tails, inconsistent size, perspective view, drop shadow on background
```

Parámetros recomendados:

| Herramienta | Parámetros |
|---|---|
| Midjourney v7 | `--ar 1:1 --style raw --stylize 50` (tiras de animación: `--ar 4:1` o `--ar 8:1`) |
| SDXL | 1024×1024, 30–40 pasos, CFG 6–7, sampler DPM++ 2M Karras, LoRA de pixel art (p. ej. *pixel-art-xl*) a 0,8; después reducir con vecino más cercano |
| GPT‑Image / DALL·E | Lenguaje natural; pide "transparent background" y "exactly N frames in one horizontal row, evenly spaced" |

## 2. Felix: diseño base (model sheet)

```text
character model sheet of Felix, a small brave orange tabby cat hero for a 2D platformer, chibi proportions with a big round head, short body and short legs, bright green eyes, cream muzzle and belly, dark orange tabby stripes on head and back, pink inner ears and nose, expressive curious face, long curled tail, shown in four views: side view facing right (main), front view, back view, three-quarter view, all at the same scale on one sheet, [BLOQUE DE ESTILO]
```

## 3. Felix: animaciones (una tira por fila de la hoja)

Plantilla común: **reemplaza `{N}` y `{ACCIÓN}`**, mantén el resto.

```text
pixel art sprite animation strip of Felix the orange tabby cat (use the reference character exactly), side view facing right, exactly {N} frames in a single horizontal row, every frame the same size (48x48 pixel cell), same scale and same ground line in every frame, feet touching the bottom of the cell, {ACCIÓN}, [BLOQUE DE ESTILO]
```

| Fila | N | `{ACCIÓN}` |
|---|---|---|
| idle | 6 | `standing idle loop: gentle breathing, chest rises and falls, tail sways slowly, one blink on frame 5, ears twitch` |
| run | 8 | `fast gallop run cycle loop: front and back legs alternate stretching and gathering, body bobs up and down, ears flat back, tail streaming behind horizontally` |
| jump | 4 | `jump start: frame 1 crouch preparing, frame 2 explosive push-off with legs extended back, frames 3-4 rising with legs tucked, determined face` |
| fall | 3 | `falling loop: legs stretched down reaching for the ground, tail raised and flailing, ears slightly up, surprised eyes` |
| land | 3 | `landing: frame 1 strong squash with body low and wide, frame 2 recovering, frame 3 back to standing pose` |
| howl | 8 | `powerful howl attack: frames 1-3 inhale with closed eyes and puffed chest, frame 4 releases the howl with head raised high and mouth wide open, frames 5-7 sustain the howl with fur bristling, frame 8 recover; add faint pale-blue sound rings around the mouth on frames 4-7` |
| scratch | 10 | `rapid claw flurry attack: leaning forward, alternating front paws swipe forward on frames 2, 4, 6, 8 and 10 with sharp white claws extended and tiny white slash streaks, frames between are paws pulled back, angry focused eyes, last swipe is the strongest` |
| fury | 8 | `rage power-up: arched back Halloween-cat pose, fur standing on end with spiky outline growing from frame 3, tail puffed and raised, eyes glowing white-hot from frame 4, hissing with fangs visible on frames 6-8, faint orange-red aura` |
| slam (4) | 4 | `ground pound: frames 1-2 curls into a tight ball in mid-air, frames 3-4 diving straight down as a ball with paws pointing down and white speed lines above` |
| slam_impact | 6 | `ground pound impact: frame 1 maximum squash flattened against the ground with legs spread and fur bristling, frames 2-5 recovering upward, frame 6 standing` |
| hurt | 3 | `taking damage: recoiling backward, eyes squeezed shut then X-shaped, fur puffed out, ears back` |
| death | 8 | `knocked out: frames 1-3 dizzy stagger with X eyes, frames 4-8 lying on its side with legs up, cartoon style, not gory` |
| victory | 6 | `happy victory loop: sitting facing the camera, eyes closed in joy (^ ^), tail curling around the paws, head bobbing gently` |

### Skins (misma silueta, solo color)

```text
recolor of the reference Felix sprite sheet, identical poses, identical silhouette and identical pixel positions, only change the palette to: {PALETA}, [BLOQUE DE ESTILO]
```

| Skin | `{PALETA}` |
|---|---|
| Sombra de Medianoche | `jet black fur with subtle blue-violet highlights, glowing golden yellow eyes, dark pink nose` |
| Siamés Real | `cream fur with dark chocolate brown ears, tail tip and paws, bright sky-blue eyes` |
| Copo de Nieve | `fluffy pure white fur with soft lavender-grey shading, light blue eyes, pink nose and inner ears` |
| Cyber Felix | `dark navy fur with glowing neon cyan stripes, magenta glowing eyes and nose, futuristic tech look` |

> Consejo: para skins suele ser más rápido y fiel **recolorear la hoja en Aseprite** (reemplazo de paleta) que regenerarla con IA. Así la silueta es idéntica y comparten normal map.

## 4. Enemigos

### Perro callejero

```text
pixel art sprite of a scruffy stray street dog enemy for a 2D platformer, medium-sized mutt, brown fur with darker patches, floppy ears, torn red collar, mean but cartoonish face, side view facing right, fits a 48x32 pixel cell, [BLOQUE DE ESTILO]
```

Animaciones (plantilla de tira de §3 con celda 48×32): `walk` 6 · `idle` 4 (jadeando) · `alert` 4 (agachado gruñendo, dientes, ojos rojos: **telegrafía clara**) · `charge` 6 (carrera furiosa con la boca abierta) · `recover` 4 (mareado, estrellitas girando sobre la cabeza) · `hurt` 2 · `death` 4 (cae y se desvanece en humo).

### Cuervo

```text
pixel art sprite of a black crow enemy for a 2D platformer, glossy black feathers with purple-blue sheen, sharp yellow beak, small red eyes, side view facing right, fits a 32x32 pixel cell, [BLOQUE DE ESTILO]
```

Animaciones: `fly` 6 (ciclo de aleteo completo: alas arriba → abajo) · `swoop` 3 (alas plegadas en picado) · `hurt` 2 · `death` 4 (plumas sueltas cayendo).

### Aspiradora robot

```text
pixel art sprite of a round robot vacuum cleaner enemy seen from the side, flat disc shape, dark grey plastic body with lighter top, front bumper, glowing cyan status LED on top, small black wheels, spinning side brush at the front, slightly menacing but cute, fits a 32x24 pixel cell, [BLOQUE DE ESTILO]
```

Animaciones: `move` 4 (cepillo girando, LED parpadeando) · `bump` 3 (se comprime al chocar, LED rojo).

## 5. Obstáculos, objetos y meta

```text
pixel art sprite animation strip, a giant ball of pink-magenta yarn with visible wound threads and one loose strand, 8 frames in one row showing it rotating 45 degrees per frame, each frame 32x32 pixels, [BLOQUE DE ESTILO]
```

```text
pixel art sprite, a sturdy wooden shipping crate with planks, diagonal X brace and metal corner plates, 24x24 pixels, [BLOQUE DE ESTILO]
```

```text
pixel art sprite animation strip, a gold coin with a small cat paw emblem spinning, 6 frames in one row (front, turning, edge, turning, front), each frame 12x12 pixels, shiny highlight, [BLOQUE DE ESTILO]
```

```text
pixel art sprite of a small cozy cat shelter house, warm and safe, wooden walls, red shingled roof with chimney, round attic window with warm yellow light, arched door with a cat-head shaped sign, a pink heart above the door, two flower pots, warm light spilling from the windows, front view, 96x80 pixels, [BLOQUE DE ESTILO]
```

```text
pixel art sprite of an old iron street lamp post with a warm glowing lantern on top, thin and tall, 16x64 pixels, [BLOQUE DE ESTILO]
```

## 6. Tileset

```text
pixel art tileset for a 2D side-scrolling platformer at dusk, 16x16 pixel tiles arranged on a grid: city sidewalk top tiles with a light curb edge, seamless dark concrete and dirt fill tiles, red brick wall tiles, purple rooftop tiles, riveted metal factory block, wooden one-way plank platform (left, middle and right pieces), dark background brick wall, lit and unlit windows, small grass tufts, all tiles seamless and tileable, [BLOQUE DE ESTILO]
```

> Después, recorta cada tile a 16×16 y colócalo en la posición del atlas indicada en [05 §4](05_Sprites_y_Animaciones.md#4-tileset-assetstilesetscity_tilespng-128x64-tiles-de-16x16).

## 7. Fondos parallax (repetibles horizontalmente)

Añade a cada uno: `seamless horizontally tileable, wide panoramic 960x{ALTO} pixels, no characters`.

| Capa | Prompt |
|---|---|
| Cielo | `pixel art sky gradient at dusk, deep indigo at the top fading to violet and warm orange near the horizon, horizontal color bands, a few stars and a thin crescent moon, 960x400` |
| Nubes | `pixel art scattered fluffy clouds lit from below by the setting sun, lavender tops and peach-orange bottoms, transparent background, 960x160` |
| Ciudad lejana | `pixel art distant city skyline silhouette, muted purple buildings of varied heights, very few tiny lit windows, low detail, transparent sky, 960x220` |
| Ciudad cercana | `pixel art near city skyline, dark blue-violet apartment buildings with many warm yellow lit windows, rooftop water towers, antennas and fire escapes, transparent sky, 960x200` |

## 8. UI

```text
set of mobile game button icons in pixel art, white icons on round dark purple semi-transparent buttons with a light lavender ring: up arrow (jump), three diagonal claw marks (scratch), cat head with sound waves (howl), flame (fury), down arrow hitting the ground line (ground pound), pause symbol, each icon centered, clear at small size, [BLOQUE DE ESTILO]
```

```text
pixel art UI elements: full red heart and empty dark heart (10x9 pixels), small gold coin icon (8x8), padlock icon (8x9), [BLOQUE DE ESTILO]
```

## 9. Checklist tras generar

- [ ] Fondo eliminado (magenta → transparente) sin halos rosados en los bordes.
- [ ] Reducido a la rejilla real con vecino más cercano; paleta de 12–16 colores.
- [ ] Contorno de 1 px uniforme y sin antialiasing.
- [ ] Cada frame en su celda, pivote en (24, 46) para Felix y la misma línea de suelo en todos.
- [ ] Mismo nombre de archivo que el placeholder → Godot lo reimporta solo.
- [ ] Normal map regenerado con el mismo layout.
- [ ] Probado bajo una farola en `Level_1.tscn`.
