class_name HowlWave
extends Node2D
## Onda visual del Aullido Expansivo: anillos concéntricos que crecen y se
## desvanecen al mismo ritmo que el CircleShape2D del hitbox.
##
## Se dibuja con _draw() (sin texturas), así escala limpia a cualquier radio.
## En la escena usa un CanvasItemMaterial "unshaded" + mezcla aditiva para que
## brille incluso con el CanvasModulate oscuro del nivel.

@export var color: Color = Color(0.72, 0.9, 1.0, 0.9)
@export_range(1, 6, 1) var ring_count: int = 3
@export var ring_spacing: float = 7.0
@export var line_width: float = 2.0

var radius := 0.0

var _alpha := 0.0
var _tween: Tween


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in ring_count:
		var ring_radius := radius - i * ring_spacing
		if ring_radius <= 1.0:
			continue
		var ring_color := color
		ring_color.a *= _alpha * (1.0 - float(i) / ring_count)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, maxi(24, int(ring_radius)), ring_color, line_width)


## Lanza la onda de [param from_radius] a [param to_radius] en [param duration] segundos.
func play(from_radius: float, to_radius: float, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	radius = from_radius
	_alpha = 1.0
	visible = true
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "radius", to_radius, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_alpha", 0.0, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)
