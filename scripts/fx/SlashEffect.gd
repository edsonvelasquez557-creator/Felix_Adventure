class_name SlashEffect
extends Sprite2D
## Zarpazo visual de la Ráfaga de Rasguños: reproduce los frames de la hoja una
## vez y se libera. Player.gd lo voltea (scale) para alternar garras.

@export var frames_per_second: float = 30.0

var _time := 0.0


func _ready() -> void:
	frame = 0


func _process(delta: float) -> void:
	_time += delta
	var next_frame := int(_time * frames_per_second)
	if next_frame >= hframes * vframes:
		queue_free()
	else:
		frame = next_frame
