# 05 · Hoja de sprites y animaciones

Especificación técnica del arte para que cualquier ilustración nueva (hecha a mano o con IA) **encaje sin tocar código**. Los PNG provisionales de `assets/` ya siguen este layout exacto: úsalos como plantilla.

## 1. Dirección de arte

| Regla | Valor |
|---|---|
| Resolución base del juego | 640×360 (se escala ×2, ×3, ×4 en enteros; en teléfonos 20:9 se ve ~800×360) |
| Tamaño de tile | 16×16 px |
| Felix | Celda de **48×48**, cuerpo de ~32×28 px (unos 2 tiles de alto con orejas) |
| Contorno | 1 px, oscuro y de color (no negro puro) — ej. `#2b1820` |
| Luz pintada | Desde **arriba-izquierda** (coincide con los normal maps generados) |
| Paleta | 12–16 colores por personaje; sombras más frías y luces más cálidas |
| Bordes | Duros: **sin antialiasing** contra el fondo transparente |
| Rotaciones y escalados | Nunca en el motor: los giros (ovillo) y el aplastamiento se **dibujan** en frames |
| Formato | PNG RGBA de 8 bits, fondo transparente |

## 2. Hoja de Felix (`assets/sprites/player/felix_<skin>.png`)

- **Tamaño: 480 × 624 px** = 10 columnas × 13 filas de celdas de 48×48.
- Una fila por animación; los frames empiezan en la columna 0. Las celdas sobrantes quedan transparentes.
- **Pivote**: el centro inferior de los pies está en el píxel **(24, 46)** de cada celda (fila 46 = contorno inferior de las patas). El `Sprite2D` está en `(0, −22)`, así el origen del `CharacterBody2D` son los pies.
- Deja 1–2 px libres en los bordes de la celda (el normal map calcula el bisel desde la silueta).
- Todas las skins usan **el mismo layout y la misma silueta**; solo cambia el color. Así comparten normal map y animaciones.

```
     col:   0     1     2     3     4     5     6     7     8     9
fila  0  [idle ×6                          ]
fila  1  [run ×8                                       ]
fila  2  [jump ×4             ]
fila  3  [fall ×3       ]
fila  4  [land ×3       ]
fila  5  [howl ×8                                      ]
fila  6  [scratch ×10                                              ]
fila  7  [fury ×8                                      ]
fila  8  [slam_start ×2 | slam_dive ×2]
fila  9  [slam_impact ×6                   ]
fila 10  [hurt ×3       ]
fila 11  [death ×8                                     ]
fila 12  [victory ×6                       ]
```

### Animaciones, frames y FPS

Las duraciones coinciden con los tiempos de `Player.gd`: si cambias FPS o frames, ajusta también el `@export` correspondiente.

| Fila | Animación | Estado de la FSM | Frames | FPS | Loop | Duración | Frames clave |
|---|---|---|---|---|---|---|---|
| 0 | `idle` | IDLE | 6 | 8 | Sí | 0,75 s | Respiración (1–3), parpadeo en el 4, cola oscila |
| 1 | `run` | RUN | 8 | 14 | Sí | 0,57 s | Galope: contacto 0 y 4, suspensión 2 y 6 |
| 2 | `jump` | JUMP | 4 | 12 | No | 0,33 s | 0 agacharse, 1 impulso, 2–3 subida (se mantiene el último) |
| 3 | `fall` | FALL | 3 | 10 | Sí | 0,3 s | Patas estiradas hacia abajo, cola arriba |
| 4 | `land` | IDLE (al aterrizar) | 3 | 20 | No | 0,15 s | 0 aplastado, 2 recuperado → encadena `idle` |
| 5 | `howl` | HOWL | 8 | 16 | No | **0,5 s** = `howl_duration` | 0–2 inhalar; **3 = sale la onda** (0,18 s = `howl_windup`); 4–6 sostener; 7 recuperar |
| 6 | `scratch` | SCRATCH | 10 | 24 | No | **0,42 s** = `scratch_duration` | **Zarpazos en 1, 3, 5, 7, 9** (ticks de daño a 0,04 / 0,12 / 0,20 / 0,28 / 0,36 s); el 9 es el remate |
| 7 | `fury` | FURY | 8 | 18 | No | **0,45 s** = `fury_cast_time` | Lomo arqueado estilo "gato de Halloween", pelo erizado desde el 2, ojos brillantes desde el 3, bufido 5–7 |
| 8 | `slam_start` | SLAM_DIVE (pausa) | 2 (cols 0–1) | 20 | No | **0,1 s** = `slam_hang_time` | Se hace bola en el aire |
| 8 | `slam_dive` | SLAM_DIVE (picado) | 2 (cols 2–3) | 12 | Sí | — | Bola con patas abajo + líneas de velocidad |
| 9 | `slam_impact` | SLAM_IMPACT | 6 | 18 | No | **0,33 s** = `slam_recovery_time` | **0 = impacto** (máximo aplastamiento), 5 de pie |
| 10 | `hurt` | HURT | 3 | 10 | No | **0,3 s** = `hurt_stun_time` | Retroceso, ojos cerrados/en X, pelo erizado |
| 11 | `death` | DEAD | 8 | 10 | No | 0,8 s | 0–2 tambaleo, 3–7 tumbado de lado |
| 12 | `victory` | VICTORY | 6 | 8 | Sí | 0,75 s | Sentado de frente, ojos felices, cola enroscada |

Las animaciones están en el `AnimationPlayer` de `Player.tscn` como pistas discretas sobre `Visuals/Sprite:frame_coords` (`Vector2i(columna, fila)`). Para añadir o retocar una: panel *Animation* → selecciona la animación → mueve las claves.

### Normal map y especular de Felix

- `felix_normal.png`: mismas medidas y layout (480×624). Se genera con `tools/art/generate_normal_map.py … --cell 48x48`.
- Si una skin cambia la silueta (p. ej. un sombrero), asígnale su propio `normal_map` en su `SkinData`.

## 3. Enemigos, obstáculos y mundo

| Archivo | Celda | Columnas × filas | Filas (animación · frames · FPS) |
|---|---|---|---|
| `enemies/stray_dog.png` | 48×32 | 6 × 7 | idle 4·6 · walk 6·10 · alert 4·12 · charge 6·16 · recover 4·8 · hurt 2·8 · death 4·8 |
| `enemies/crow.png` | 32×32 | 6 × 4 | fly 6·12 · swoop 3·10 · hurt 2·8 · death 4·8 |
| `enemies/robot_vacuum.png` | 32×24 | 4 × 2 | move 4·10 · bump 3·12 |
| `obstacles/yarn_ball.png` | 32×32 | 8 × 1 | Rodar: 8 ángulos de 45° (el frame avanza según la distancia) |
| `obstacles/crate.png` | 24×24 | 1 | — |
| `obstacles/puddle.png` | 48×10 | NinePatch | Bordes de 8 px a izquierda y derecha; el centro se repite |
| `world/coin.png` | 12×12 | 6 × 1 | Giro 10 FPS (anchos 10-8-5-2-5-8) |
| `world/cat_shelter.png` | 96×80 | 1 | Pivote: centro inferior. Puerta centrada, ventana redonda arriba |
| `world/street_lamp.png` | 16×64 | 1 | Bombilla a 52 px del suelo |
| `fx/slash.png` | 32×32 | 4 × 1 | 30 FPS, sin loop |
| `fx/crack.png` | 64×16 | 3 × 1 | Variantes (se elige una al azar) |

Todos (salvo efectos, moneda y charco) llevan su `*_n.png` con el mismo layout. Los sprites de enemigos miran **a la derecha**.

## 4. Tileset (`assets/tilesets/city_tiles.png`, 128×64, tiles de 16×16)

| (col, fila) | Tile | Colisión |
|---|---|---|
| (0–2, 0) / (0–2, 1) | Acera: superficie / relleno (3 variantes) | Sólido |
| (3, 0) / (3, 1) | Ladrillo: superficie / relleno | Sólido |
| (4, 0) / (4, 1) | Tejado: superficie / relleno | Sólido |
| (3, 2) | Bloque metálico | Sólido |
| (0, 2) (1, 2) (2, 2) | Tablón izquierdo / centro / derecho | Un sentido |
| (5, 0) (5, 1) | Pared de ladrillo de fondo | — |
| (6, 0) (6, 1) | Ventana apagada / encendida | — |
| (7, 0) | Hierba de primer plano | — |

Los tiles de relleno deben ser **repetibles** (sin costuras) en las 4 direcciones.

## 5. Fondos parallax (`assets/backgrounds/`)

| Capa | Archivo | Tamaño | `motion_scale` | Notas |
|---|---|---|---|---|
| Cielo | `sky_gradient.png` | 8×400 (se estira) | (0, 0) | Degradado por bandas: índigo → violeta → naranja |
| Estrellas y luna | `stars.png` | 960×240 | (0, 0) | Transparente |
| Nubes | `clouds.png` | 960×160 | (0.08, 0.02) + deriva | **Repetible horizontalmente** |
| Ciudad lejana | `city_far.png` | 960×220 | (0.2, 0.05) | Siluetas, pocas ventanas |
| Ciudad cercana | `city_near.png` | 960×200 | (0.45, 0.1) | Más detalle: antenas, depósitos de agua |

960 px de ancho cubre la pantalla más ancha prevista (~870 px en teléfonos 21:9) con `motion_mirroring = 960`.

## 6. UI (`assets/ui/`)

| Elemento | Tamaño | Notas |
|---|---|---|
| Botón de salto | 56×56 (+ `_pressed`) | Círculo con icono; la zona táctil es 6 px mayor |
| Rasguños / Aullido / Golpe / Furia | 48 / 44 / 44 / 40 | Idem; `cooldown_<tamaño>.png` para el barrido |
| Pausa | 32×32 | — |
| Joystick | base 72×72, pomo 32×32 | `StyleBoxTexture` del `VirtualJoystick` |
| Corazón / moneda / candado | 10×9 / 8×8 / 8×9 | Se muestran a ×2 |

## 7. Del arte generado al juego (pipeline)

1. **Generar** el arte (ver [06](06_Prompts_IA.md)). Las IA producen imágenes grandes con "falsos píxeles".
2. **Reducir a la rejilla real**: escala al tamaño objetivo con *vecino más cercano* (p. ej. de 1024 px a 48 px por celda), o redibuja encima.
3. **Limpiar**: reducir la paleta (12–16 colores), quitar píxeles sueltos y antialiasing, contorno de 1 px uniforme.
4. **Montar la hoja**: abre `felix_classic.png` como capa de referencia en Aseprite/LibreSprite, coloca cada frame en su celda respetando el **pivote (24, 46)** y la misma altura de suelo en todos los frames.
5. **Exportar** como PNG con **el mismo nombre** del placeholder: Godot lo reimporta automáticamente y todo sigue funcionando.
6. **Normal map**: `python tools/art/generate_normal_map.py felix_classic.png -o felix_normal.png --cell 48x48` (o Laigter).
7. **Skins**: recolorea la hoja base (misma silueta) y guarda `felix_<skin>.png`.
8. Probar con F6 en `Level_1.tscn` bajo una farola: se deben ver volumen y bordes iluminados.

> Si tu arte final necesita celdas más grandes (p. ej. 64×64), cambia `SkinData.FRAME_SIZE`, `hframes`/`vframes` del `Sprite2D`, la posición del `Sprite2D` y el tamaño de las formas de colisión. Es un cambio acotado, pero requiere esos cuatro ajustes.
