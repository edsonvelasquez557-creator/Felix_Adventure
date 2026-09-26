class_name AbilityButton
extends TouchScreenButton
## Botón táctil de habilidad con indicador de recarga radial.
##
## TouchScreenButton es multitáctil de forma nativa y dispara la acción del
## InputMap indicada en "action": Player.gd recibe la habilidad igual que si
## se hubiera pulsado la tecla. Este script solo añade el feedback visual:
## barrido oscuro de la recarga, segundos restantes y atenuado cuando la
## habilidad no se puede usar (p. ej. el Golpe Sísmico estando en el suelo).

@export var ability: Player.Ability = Player.Ability.SCRATCH
@export var unavailable_modulate: Color = Color(1.0, 1.0, 1.0, 0.45)

var player: Player

@onready var cooldown_overlay: TextureProgressBar = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel


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
