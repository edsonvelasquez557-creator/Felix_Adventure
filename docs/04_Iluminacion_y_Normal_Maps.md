# 04 · Iluminación dinámica con Normal Maps en Godot 4

Guía práctica de cómo se ilumina Felix: normal maps en sprites 2D, `CanvasModulate` como luz ambiente, `PointLight2D` para farolas y efectos, sombras en tiempo real y brillos. Todo lo descrito está ya montado en el proyecto; los ejemplos indican dónde verlo.

## 1. Cómo funciona la luz 2D en Godot 4

```
color final = color del sprite × CanvasModulate  +  Σ (aporte de cada luz 2D que lo toca)
                                                        ↑ depende del normal map y de height
```

- **`CanvasModulate`** oscurece (multiplica) todo lo que hay en su lienzo: es la **luz ambiente** (anochecer, noche).
- **Las luces 2D** (`PointLight2D`, `DirectionalLight2D`) suman luz encima. Sin normal map, un sprite se ilumina como un papel plano. **Con normal map**, cada píxel sabe hacia dónde "mira" y recibe más o menos luz según la posición de la lámpara: aparece el volumen, los bordes y los reflejos.
- **Todo es por lienzo (canvas)**. El mundo, cada `CanvasLayer` y el `ParallaxBackground` (que *es* un CanvasLayer) tienen su propio lienzo. Un `CanvasModulate` o una luz solo afectan a su lienzo. Consecuencias en Felix:
  - El HUD (CanvasLayer 10) nunca se oscurece.
  - El fondo parallax necesita su **propio** `CanvasModulate` (`BackgroundTint`) para oscurecerse en niveles nocturnos, y las farolas del mundo no lo iluminan (correcto: está muy lejos).

## 2. Preparar las texturas (Pixel Art)

| Ajuste | Dónde | Valor |
|---|---|---|
| Filtro | Project Settings → Rendering → Textures → Canvas Textures → Default Texture Filter | **Nearest** (ya configurado) |
| Compresión | Import de cada PNG | **Lossless** (por defecto en 2D). No uses VRAM/lossy en pixel art ni en normal maps: crean artefactos. |
| Mipmaps | Import | Desactivados |
| Tamaños | — | El normal map debe tener **exactamente** el mismo tamaño y layout de celdas que la hoja de color |

## 3. Crear el normal map

**Convención**: Godot espera normal maps estilo **OpenGL ("Y+", verde hacia arriba)**. Si una herramienta exporta estilo DirectX (verde hacia abajo), la luz parecerá venir del lado contrario en vertical: invierte el canal verde (o marca *Normal Map Invert Y* en el import).

Opciones, de más rápida a más artesanal:

1. **Herramienta del proyecto** (gratis, reproducible):
   ```bash
   pip install pillow numpy
   # Sprites: bisel por silueta + detalle por luminancia, celda a celda
   python tools/art/generate_normal_map.py felix_classic.png -o felix_normal.png --cell 48x48 --bevel 4 --strength 2.4
   # Tiles opacos y repetibles: sin costuras
   python tools/art/generate_normal_map.py city_tiles.png -o city_tiles_n.png --mode tile --cell 16x16
   ```
   Calcula la altura como distancia al borde transparente (volumen redondeado) más la luminancia (surcos en las líneas oscuras) y la convierte a normales.
2. **Laigter** (gratis, código abierto) o **SpriteIlluminator** (de pago): generan normal, especular y oclusión con vista previa en vivo. Exporta en "OpenGL/Y+".
3. **Pintado a mano** en Aseprite/LibreSprite con una paleta de normales (8–16 direcciones). Es lo más fiel al pixel art: úsalo al menos para la cara de Felix.

> Consejo de estilo: normal maps **suaves** (bisel de 3–4 px, fuerza moderada). Un relieve exagerado convierte el pixel art en "plastilina".

## 4. `CanvasTexture`: juntar color + normal + especular

En Godot 4 los normal maps 2D no se asignan al nodo sino a un recurso **`CanvasTexture`**:

1. Selecciona el `Sprite2D` → Inspector → **Texture** → *New CanvasTexture*.
2. En el `CanvasTexture`:
   - **Diffuse → Texture**: la hoja de color (`felix_classic.png`).
   - **Normal Map → Texture**: `felix_normal.png`.
   - **Specular → Texture** (opcional): máscara en grises de zonas brillantes (ojos, metal, agua). **Specular Color** y **Shininess** controlan el reflejo.
3. `hframes`/`vframes` del `Sprite2D` funcionan igual: como ambas hojas comparten layout, cada frame usa su región de normal map.
4. `flip_h` también es seguro: Godot invierte la componente X de la normal al voltear, la luz sigue viniendo del lado correcto.

Equivalente por código (así aplica Felix las skins, `Player.apply_skin()`):

```gdscript
var skin_texture := CanvasTexture.new()
skin_texture.diffuse_texture = skin.sprite_sheet          # solo cambia el color
skin_texture.normal_texture = skin.normal_map if skin.normal_map else _base_normal_map
skin_texture.specular_texture = _base_specular_map
sprite.texture = skin_texture
```

Dónde se usa `CanvasTexture` en el proyecto:

| Elemento | Diffuse | Normal | Especular |
|---|---|---|---|
| Felix (5 skins) | `felix_<skin>.png` | `felix_normal.png` (compartido) | — |
| Enemigos, caja, ovillo, farola, Refugio | `*.png` | `*_n.png` | — |
| TileSet (atlas) | `city_tiles.png` | `city_tiles_n.png` | — |
| Charco (`NinePatchRect`) | `puddle.png` | `puddle_n.png` (plano) | `puddle_specular.png` (alto): **refleja las farolas** |

## 5. `CanvasModulate`: la luz ambiente

- Un solo `CanvasModulate` por lienzo. En cada nivel: `CanvasModulate` (mundo) y `ParallaxCity/BackgroundTint` (fondo).
- Colores usados: anochecer `#8f86c4` (nivel 1) → noche `#4c5480` (nivel 9). Regla: **nunca negro puro**; un ambiente azul-violeta hace que las luces cálidas (naranja) resalten por contraste de temperatura.
- El constructor de niveles lee `ambient=` y `background_tint=` de cada mapa (`tools/levels/level_XX.txt`).

## 6. `PointLight2D`: las luces

| Propiedad | Qué hace | Valores en Felix |
|---|---|---|
| `texture` | Forma e intensidad de la luz | `light_soft.tres` (degradado radial suave) o `light_banded.png` (**degradado por bandas**: queda muy "pixel art") |
| `texture_scale` | Radio | Farola 1,7 · Refugio 2,6 · Furia 0,9 · destello sísmico 1,6 |
| `color` / `energy` | Tono e intensidad | Cálidos (1.0, 0.8, 0.5) sobre ambiente frío |
| `height` | **Altura de la luz para los normal maps** (px). 0 = rasante (solo bordes), mayor = de frente | Farola 36 · Refugio 24 · Furia 16 · destello 12 |
| `blend_mode` | *Add* (suma, por defecto), *Sub* (resta, "luz negra"), *Mix* | Add |
| `range_item_cull_mask` ↔ `light_mask` del sprite | Qué objetos ilumina cada luz | Todo en la capa 1 |
| `shadow_enabled` | Sombras en tiempo real (ver §7) | Farolas y Refugio |

Recetas incluidas:

| Receta | Escena | Técnica |
|---|---|---|
| Farola con parpadeo | `StreetLamp.tscn` | `PointLight2D` + `FlickerLight.gd` (ruido sobre `energy`) + halo aditivo |
| Ventana del Refugio | `CatShelter.tscn` | Luz cálida con sombras y parpadeo de chimenea; se intensifica con un `Tween` al llegar |
| Aura de Furia | `Player.tscn` → `FuryAura` | Luz naranja que se enciende con el buff; ilumina el suelo y a los enemigos cercanos |
| Destello del Golpe Sísmico | `SeismicCrack.tscn` → `Flash` | `Tween` de `energy` de 2,2 a 0 en 0,35 s: ilumina el entorno desde el suelo |
| LED de la aspiradora | `RobotVacuum.tscn` → `LedLight` | Luz cian pequeña que viaja con ella |

## 7. Sombras en tiempo real

1. **Oclusores**: en el `TileSet` hay una *Occlusion Layer*; cada tile sólido tiene un `OccluderPolygon2D` cuadrado (en el editor: TileSet → Paint → Occlusion). Para objetos sueltos, añade un `LightOccluder2D` con su polígono.
2. **Luz**: `shadow_enabled = true`. Filtro **`SHADOW_FILTER_NONE`** para sombras de borde nítido (coherentes con el pixel art); `PCF5/PCF13` las suavizan a más coste.
3. `shadow_color` controla cuán oscura es la sombra; `shadow_item_cull_mask` y `occluder_light_mask` qué oclusores cuentan para qué luces.
4. El `TileMapLayer` `Ground` tiene `occlusion_enabled`; `BackWall` y `Foreground` no (no deben tapar la luz).

> Opcional: un `LightOccluder2D` pequeño en Felix hace que proyecte sombra con las farolas. Queda muy bien, pero en móvil activa solo sombras en 2–3 luces visibles a la vez.

## 8. Brillos (emisivos y glow)

| Técnica | Cuándo | En el proyecto |
|---|---|---|
| **Material *unshaded*** (`CanvasItemMaterial.light_mode = UNSHADED`) | Algo debe verse con su color real aunque todo esté oscuro | Monedas, textos de carteles, corazones del Refugio |
| **Unshaded + aditivo** (`unshaded_add.tres`) | Efectos luminosos | Anillos del Aullido, zarpazos, brasas de la Furia, halos de farolas, chispas |
| **`modulate` > 1** | "Sobrexponer" un sprite | Tinte de la Furia (1,5; 0,62; 0,5), destello blanco de los enemigos al recibir daño |
| **Glow de `WorldEnvironment`** | Halo difuso alrededor de lo más brillante | `level_environment.tres`: fondo *Canvas*, glow con umbral 0,82, mezcla *Screen* |

Sobre el glow: funciona en los renderers **Mobile** (el del proyecto) y Forward+. Con `Rendering → Viewport → HDR 2D` activado, los valores de `modulate`/`energy` por encima de 1 generan un bloom más intenso (más coste). Si el juego cae a Compatibility en un móvil sin Vulkan, el glow puede verse distinto: el resto de la iluminación funciona igual.

## 9. Rendimiento en móvil

Con `stretch/mode = canvas_items` la luz se calcula a la resolución real del teléfono (p. ej. 2400×1080): cada luz que toca un sprite cuesta por píxel.

- Presupuesto orientativo: **≤ 6 luces visibles** a la vez, **≤ 2–3 con sombra**.
- Texturas de luz pequeñas (128×128) escaladas con `texture_scale`.
- Luces y generadores lejanos no suman coste de dibujo si no se ven, pero sus scripts sí se ejecutan: `FlickerLight` es barato; evita `_process` pesados en luces.
- Partículas con `CPUParticles2D` (sin compilación de shaders en la primera emisión).
- Si un dispositivo va justo: desactiva el glow (`glow_enabled = false`) y las sombras de farolas; el aspecto general se mantiene gracias a normal maps + `CanvasModulate`.

## 10. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| La luz no se ve sobre el fondo | El fondo es otro lienzo (CanvasLayer) | Normal: tiñe el fondo con su propio `CanvasModulate` |
| El sprite se ve plano | Falta el normal map o la luz tiene `height` alta | Revisa el `CanvasTexture`; baja `height` para realzar bordes |
| Luz "al revés" en vertical | Normal map estilo DirectX | Invierte el canal verde (`--invert-y`) |
| Bordes con halo blanco o puntos raros | Compresión con pérdida | Import en *Lossless* |
| Un texto o moneda se ve oscuro | Le afecta el `CanvasModulate` | Material *unshaded* |
| Sombras que "cortan" demasiado | Oclusores en decoración | Quita oclusión de capas decorativas |
