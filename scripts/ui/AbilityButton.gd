class_name AbilityButton
extends TouchScreenButton
## Botón táctil de habilidad con indicador de recarga radial.
##
## TouchScreenButton es multitáctil de forma nativa y dispara la acción del
## InputMap indicada en "action": Player.gd recibe la habilidad igual que si
## se hubiera pulsado la tecla. Este script solo añade el feedback visual:
## barrido oscuro de la recarga, segundos restantes y atenuado cuando la
## habilidad no se puede usar (p. ej. el Golpe Sísmico estando en el suelo).
##
## La zona táctil (círculo) y el indicador se ajustan solos al tamaño de la
## textura, así una misma escena sirve para botones de distinto tamaño.

@export var ability: Player.Ability = Player.Ability.SCRATCH
## Círculo oscuro semitransparente del tamaño del botón (barrido de recarga).
@export var cooldown_texture: Texture2D
## Píxeles extra alrededor del botón que también cuentan como toque.
@export var touch_margin: float = 6.0
@export var unavailable_modulate: Color = Color(1.0, 1.0, 1.0, 0.45)

var player: Player

@onready var cooldown_overlay: TextureProgressBar = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel


func _ready() -> void:
	var button_size := texture_normal.get_size() if texture_normal != null else Vector2(48.0, 48.0)
	if shape == null:
		var circle := CircleShape2D.new()
		circle.radius = button_size.x * 0.5 + touch_margin
		shape = circle
	shape_centered = true
	cooldown_overlay.texture_progress = cooldown_texture
	cooldown_overlay.size = button_size
	cooldown_label.size = button_size


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var ratio := player.get_cooldown_ratio(ability)
	cooldown_overlay.value = ratio * 100.0
	var remaining := player.get_cooldown_remaining(ability)
	cooldown_label.text = str(ceili(remaining)) if remaining >= 1.0 else ""
	if ratio <= 0.0 and not player.is_ability_ready(ability):
		self_modulate = unavailable_modulate
	else:
		self_modulate = Color.WHITE
