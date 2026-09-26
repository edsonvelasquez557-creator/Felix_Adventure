# 08 · Móvil: controles, rendimiento y exportación

## 1. Configuración de proyecto para móvil

| Ajuste (Project Settings) | Valor | Por qué |
|---|---|---|
| Rendering → Renderer | **Mobile** (Vulkan) | El que elegiste al crear el proyecto. Si el teléfono no tiene Vulkan, Godot cae automáticamente a OpenGL (`rendering_device/fallback_to_opengl3 = true`). |
| Display → Window → Size | **640×360** (ventana de prueba 1280×720) | Resolución base del pixel art; 360 divide exacto 720, 1080 y 1440 |
| Stretch → Mode / Aspect | **canvas_items / expand** | Texto e iconos nítidos a resolución nativa; en pantallas 20:9 se ve más mundo a los lados (~800×360) en vez de franjas negras |
| Stretch → Scale Mode | **integer** | Cada píxel del arte ocupa exactamente N×N píxeles de pantalla: sin píxeles "gordos y flacos" |
| Handheld → Orientation | **Sensor Landscape** | Horizontal, permitiendo girar el teléfono 180° |
| Textures → Default Filter | **Nearest** | Pixel art nítido |
| Input Devices → Emulate Touch From Mouse | **On** | Probar los controles táctiles con el ratón en el editor |
| Application → Config → Quit On Go Back | **Off** | El botón "atrás" de Android abre la pausa en vez de cerrar el juego |
| VRAM Compression → Import ETC2 ASTC | **On** | Requisito de la exportación a Android |

Además, `Global.gd` limita el juego a **60 FPS en móvil** (`Engine.max_fps = 60`): ahorra batería en pantallas de 90/120 Hz y mantiene el render alineado con los 60 pasos de física.

Resoluciones resultantes con escalado entero:

| Pantalla | Escala | Área visible de juego |
|---|---|---|
| 1280×720 | ×2 | 640×360 |
| 1600×720 (20:9) | ×2 | 800×360 |
| 1920×1080 | ×3 | 640×360 |
| 2400×1080 (20:9) | ×3 | 800×360 |
| 3200×1440 | ×4 | 800×360 |
| Tablet 2560×1600 | ×4 | 640×400 |

## 2. Controles táctiles (`HUD.tscn`)

| Control | Nodo | Detalles |
|---|---|---|
| Movimiento | **`VirtualJoystick` nativo** (Godot 4.7) | Modo *Dynamic*: aparece donde toca el pulgar dentro de la mitad izquierda. Pulsa `move_left`/`move_right` con fuerza **analógica** (se puede caminar despacio). Zona muerta 20 %. Estilo con `StyleBoxTexture` pixel art. |
| Salto | `TouchScreenButton` (`action = "jump"`) | 56 px + 6 px de margen táctil. Mantener = salto más alto. |
| 4 habilidades | `AbilityButton.tscn` (TouchScreenButton + script) | Disparan las mismas acciones que el teclado. Barrido radial de recarga, segundos restantes y atenuado si no se puede usar (Golpe Sísmico en el suelo). |
| Pausa | `TouchScreenButton` (`action = "pause"`) | Arriba a la derecha. |

- **Multitáctil real**: `VirtualJoystick` y `TouchScreenButton` siguen cada dedo por su índice: se puede mantener el joystick y a la vez saltar y atacar (verificado en las pruebas).
- **Un solo código de control**: `Player.gd` solo lee acciones del InputMap (`Input.get_axis`, `is_action_just_pressed`), así teclado, mando y pantalla táctil funcionan igual.
- **Ergonomía**: el salto (acción más frecuente) en la esquina inferior derecha, los Rasguños a su izquierda, Aullido y Golpe Sísmico en arco por encima, y la Furia (8 s, 20 s de recarga) más lejos. Separación entre centros ≥ 58 px para no pulsar dos a la vez.
- **Safe area**: todo el HUD está dentro de `SafeAreaMargin`, que convierte `DisplayServer.get_display_safe_area()` en márgenes: los botones nunca quedan bajo la muesca o la cámara perforada.
- Textos de tutorial según el dispositivo (`TutorialSign`: "Toca el botón de salto" en móvil, "Salta con Espacio" en PC).

## 3. Ciclo de vida de la app

| Evento | Qué hace el juego |
|---|---|
| La app pasa a segundo plano (llamada, notificación) | `PauseMenu` se abre solo; `Global` guarda la partida |
| Botón "atrás" de Android | En un nivel: pausa / continuar · en la tienda: volver al menú · en el menú: cerrar el selector o salir |
| Cierre de la app | Guardado |
| iOS | El botón "Salir" se oculta (las guías de Apple no permiten cerrar la app) |

**Vibración** (`Global.vibrate`): impactos del Golpe Sísmico, daño recibido, Furia, compras. Se puede desactivar en el menú de pausa y requiere el permiso `VIBRATE` en Android.

## 4. Rendimiento

| Medida | Dónde |
|---|---|
| `CPUParticles2D` en lugar de `GPUParticles2D` | Sin tirón por compilación de shaders en la primera emisión; igual en todos los renderers |
| Generadores (grúas, cestos) solo activos en pantalla | `VisibleOnScreenNotifier2D` en `ObstacleSpawner` |
| Monedas sin `AnimationPlayer` | El giro se calcula por tiempo en `Coin.gd` |
| Presupuesto de luces | ≤ 6 luces visibles, ≤ 2–3 con sombra (ver [04 §9](04_Iluminacion_y_Normal_Maps.md#9-rendimiento-en-móvil)) |
| Texturas pequeñas y sin compresión con pérdida | Todo el arte ocupa unos pocos MB |
| Carga de niveles en hilo | `SceneManager` usa `load_threaded_request` durante el fundido |

Para móviles de gama baja: cambia el renderer a **Compatibility** (Project Settings → Rendering → Renderer → `gl_compatibility`), desactiva el glow de `level_environment.tres` y las sombras de las farolas. La jugabilidad y el resto de la iluminación no cambian.

## 5. Exportar a Android

1. **Plantillas de exportación**: *Editor → Manage Export Templates → Download and Install* (deben ser de la versión 4.7.2).
2. **Herramientas**: instala **JDK 17** y el **Android SDK** (lo más cómodo es Android Studio). En *Editor → Editor Settings → Export → Android* indica las rutas del *Java SDK* y del *Android SDK*.
3. **Preset**: *Project → Export → Add… → Android*.
4. **Opciones importantes**:
   - *Package → Unique Name*: p. ej. `com.tuestudio.felix` (definitivo: Google Play no permite cambiarlo).
   - *Version → Code / Name*: 1 / `1.0.0` (sube el *Code* en cada publicación).
   - *Architectures*: `arm64-v8a` (obligatoria en Google Play); `armeabi-v7a` opcional para móviles antiguos.
   - *Permissions*: marca **Vibrate**.
   - *Launcher Icons*: principal 192×192 y adaptativos (foreground/background 432×432). Por defecto usa `icon.svg` (la cara de Felix).
   - *Resources → Filters to exclude*: `tools/*, docs/*` (herramientas y documentación no van en el juego).
5. **Firma**:
   - Pruebas: Godot usa la *debug keystore* automáticamente.
   - Publicación: crea una clave de release y **no la subas nunca al repositorio** (el `.gitignore` ya excluye `*.keystore` y `*.jks`):
     ```bash
     keytool -v -genkey -keystore felix-release.keystore -alias felix -keyalg RSA -validity 10000
     ```
     Indícala en *Keystore → Release* del preset (Godot guarda la contraseña en `.godot/export_credentials.cfg`, que tampoco se versiona).
6. **Probar en el teléfono**: activa *Opciones de desarrollador → Depuración USB*, conecta el móvil y pulsa el icono de Android de la barra del editor (*Remote Deploy*). Para un APK suelto: *Export Project* con formato APK.
7. **Google Play**: requiere **AAB**: *Project → Install Android Build Template*, activa *Gradle Build → Use Gradle Build* y exporta con formato AAB.

## 6. Exportar a iOS (resumen)

Necesitas un Mac con Xcode y una cuenta de Apple Developer. *Project → Export → Add… → iOS*: *Bundle Identifier*, *Team ID* y perfiles de firma; Godot genera un proyecto de Xcode desde el que se compila y se sube a App Store Connect. El juego ya oculta el botón "Salir" en iOS.

## 7. Probar en el escritorio como si fuera un móvil

- F5 abre una ventana de 1280×720 con los controles táctiles visibles; el ratón hace de dedo.
- Para simular un teléfono 20:9: Project Settings → Display → Window → *Window Width Override* = 1600, *Height* = 720.
- El teclado y el mando siguen funcionando a la vez (útil para probar rápido).
