class_name FlickerLight
extends PointLight2D
## PointLight2D con parpadeo orgánico (farolas viejas, chimenea del Refugio).
## La energía base es la configurada en el inspector; el ruido la hace oscilar.

@export_range(0.0, 1.0, 0.01) var flicker_strength: float = 0.12
@export var flicker_speed: float = 6.0

var _base_energy := 1.0
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base_energy = energy
	_noise.seed = randi()
	_noise.frequency = 0.5
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	energy = _base_energy * (1.0 + _noise.get_noise_1d(_time) * flicker_strength)
