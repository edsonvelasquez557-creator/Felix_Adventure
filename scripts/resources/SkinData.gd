class_name SkinData
extends Resource
## Datos de una skin de Felix que se vende en la tienda.
##
## Todas las skins comparten EXACTAMENTE la misma distribución de la hoja de
## sprites (celdas de 48x48, mismas filas y columnas). Gracias a eso, cambiar de
## skin solo reemplaza la textura difusa del Sprite2D: el AnimationPlayer, los
## hitboxes y la máquina de estados no cambian.
##
## Si la silueta de la skin es idéntica a la base (solo cambia el color), puede
## dejarse [member normal_map] vacío y se reutilizará el normal map base.

## Tamaño de celda de la hoja de sprites de Felix (px).
const FRAME_SIZE := Vector2i(48, 48)

## Identificador único y estable (se guarda en la partida). No lo cambies tras publicar.
@export var id: StringName = &""
## Nombre visible en la tienda.
@export var display_name: String = ""
## Descripción corta para la tarjeta de la tienda.
@export_multiline var description: String = ""
## Precio en monedas. 0 = gratuita (se posee desde el inicio).
@export_range(0, 100000, 1, "or_greater") var price: int = 0
## Hoja de sprites difusa (color) con el layout estándar de Felix.
@export var sprite_sheet: Texture2D
## Normal map opcional. Si es null se usa el normal map de la escena base.
@export var normal_map: Texture2D
## Celda (columna, fila) que se muestra como miniatura en la tienda.
@export var preview_cell: Vector2i = Vector2i(0, 0)
## Color de acento para la tarjeta de la tienda.
@export var accent_color: Color = Color(1.0, 0.72, 0.3)


## Devuelve true si la skin tiene los datos mínimos para usarse.
func is_valid() -> bool:
	return id != &"" and sprite_sheet != null


## Recorta la celda [member preview_cell] de la hoja para usarla como icono.
func get_preview_texture() -> Texture2D:
	if sprite_sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite_sheet
	atlas.region = Rect2(Vector2(preview_cell * FRAME_SIZE), Vector2(FRAME_SIZE))
	return atlas
