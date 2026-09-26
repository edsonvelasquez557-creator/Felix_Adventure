class_name YarnBall
extends CharacterBody2D
## Ovillo de lana rodante gigante: obstáculo invencible que hay que saltar.
##
## Rueda en línea recta con gravedad (cae por desniveles y escalones). La
## animación de rodar avanza según la distancia recorrida: un frame cada
## (perímetro / nº de frames) píxeles. Así el giro se ve correcto a cualquier
## velocidad y no se rotan píxeles (se conserva el Pixel Art nítido).
## Al chocar con una pared se deshace (o rebota si [member bounce_on_walls]).

@export var roll_speed: float = 110.0
## -1 = rueda hacia la izquierda, 1 = hacia la derecha.
@export var direction: float = -1.0
@export var gravity: float = 900.0
@export var bounce_on_walls: bool = false
@export var max_bounces: int = 2
@export var lifetime: float = 14.0
@export var radius: float = 14.0
@export var unravel_scene: PackedScene

var _distance := 0.0
var _bounces := 0
var _age := 0.0
var _finished := false

@onready var sprite: Sprite2D = %Sprite


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_age += delta
	if _age >= lifetime:
		_unravel()
		return
	velocity.x = direction * roll_speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 600.0)
	move_and_slide()
	_update_roll_frame()
	if is_on_wall():
		if bounce_on_walls and _bounces < max_bounces:
			_bounces += 1
			direction = -direction
			EventBus.camera_shake_requested.emit(0.12)
		else:
			_unravel()


## Muerte instantánea en zonas letales.
func kill() -> void:
	queue_free()


func _update_roll_frame() -> void:
	_distance += absf(get_position_delta().x)
	var frame_count := sprite.hframes * sprite.vframes
	var step := TAU * radius / frame_count
	var index := int(_distance / step) % frame_count
	sprite.frame = index if direction > 0.0 else frame_count - 1 - index


func _unravel() -> void:
	_finished = true
	if unravel_scene != null:
		var burst := unravel_scene.instantiate() as Node2D
		burst.position = position + Vector2(0.0, -radius)
		get_parent().add_child.call_deferred(burst)
	queue_free()
