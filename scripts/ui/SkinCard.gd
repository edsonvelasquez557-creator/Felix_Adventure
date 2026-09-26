class_name SkinCard
extends PanelContainer
## Tarjeta de una skin en la tienda: vista previa animada (idle de Felix con
## esa skin), nombre, descripción y botón Comprar / Equipar / Equipada.

signal action_requested(skin_id: StringName)

const IDLE_ROW := 0
const IDLE_FRAMES := 6
const IDLE_FPS := 8.0

var skin: SkinData

var _atlas: AtlasTexture
var _time := 0.0
var _shake_tween: Tween

@onready var preview: TextureRect = %Preview
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var action_button: Button = %ActionButton


func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)


func _process(delta: float) -> void:
	if _atlas == null:
		return
	_time += delta
	var frame_index := int(_time * IDLE_FPS) % IDLE_FRAMES
	_atlas.region.position = Vector2(frame_index, IDLE_ROW) * Vector2(SkinData.FRAME_SIZE)


## Configura la tarjeta. Llamar después de añadirla al árbol.
func setup(p_skin: SkinData) -> void:
	skin = p_skin
	name_label.text = skin.display_name
	description_label.text = skin.description
	_atlas = skin.get_preview_texture() as AtlasTexture
	preview.texture = _atlas
	self_modulate = skin.accent_color.lerp(Color.WHITE, 0.55)
	refresh()


## Actualiza el botón según monedas, posesión y skin equipada.
func refresh() -> void:
	if skin == null:
		return
	action_button.modulate = Color.WHITE
	if Global.equipped_skin_id == skin.id:
		action_button.text = "Equipada"
		action_button.disabled = true
	elif Global.is_skin_owned(skin.id):
		action_button.text = "Equipar"
		action_button.disabled = false
	else:
		action_button.text = "Comprar  %d" % skin.price
		action_button.disabled = false
		action_button.modulate = Color.WHITE if Global.can_afford(skin.price) else Color(1.0, 0.6, 0.6)


## Sacudida horizontal: feedback de "no te alcanza".
func shake() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for offset: float in [6.0, -6.0, 4.0, -4.0, 0.0]:
		_shake_tween.tween_property(self, "position:x", position.x + offset, 0.04)


func _on_action_pressed() -> void:
	action_requested.emit(skin.id)
