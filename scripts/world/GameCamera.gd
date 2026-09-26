class_name GameCamera
extends Camera2D
## Cámara del nivel.
##
## - Sigue al objetivo (Felix) con el suavizado nativo de Camera2D.
## - "Look-ahead": se adelanta hacia donde mira Felix para mostrar lo que viene.
## - Temblor por trauma: cada petición suma trauma (0..1) y el desplazamiento
##   es proporcional a trauma² con ruido suave (FastNoiseLite). El resultado se
##   redondea a píxeles enteros para mantener nítido el Pixel Art.
## - Se actualiza en el paso de física, igual que Felix, para evitar el
##   "jitter" entre personaje y cámara.

@export var target: Node2D
@export var look_ahead_distance: float = 36.0
@export var look_ahead_speed: float = 2.5
## Desplazamiento vertical: muestra un poco más de lo que hay sobre Felix.
@export var vertical_offset: float = -28.0
@export var max_shake_offset: Vector2 = Vector2(9.0, 6.0)
## Trauma que se pierde por segundo.
@export var trauma_decay: float = 1.8
@export var shake_noise_speed: float = 55.0

var trauma := 0.0

var _look_ahead := 0.0
var _noise := FastNoiseLite.new()
var _noise_time := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_noise.seed = randi()
	_noise.frequency = 0.08
	EventBus.camera_shake_requested.connect(add_trauma)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node2D
	snap_to_target()


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var player := target as Player
		var facing := player.facing if player != null else 1.0
		_look_ahead = lerpf(_look_ahead, facing * look_ahead_distance, clampf(look_ahead_speed * delta, 0.0, 1.0))
		global_position = target.global_position + Vector2(_look_ahead, vertical_offset)
	_update_shake(delta)


## Suma trauma (0..1). Varias peticiones seguidas se acumulan hasta 1.
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Coloca la cámara sobre el objetivo sin suavizado (inicio de nivel).
func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0.0, vertical_offset)
		reset_smoothing()


## Limita la cámara al rectángulo del mundo (en coordenadas globales).
func set_world_limits(world_rect: Rect2) -> void:
	limit_left = floori(world_rect.position.x)
	limit_top = floori(world_rect.position.y)
	limit_right = ceili(world_rect.end.x)
	limit_bottom = ceili(world_rect.end.y)


func _update_shake(delta: float) -> void:
	if trauma <= 0.0:
		offset = Vector2.ZERO
		return
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	_noise_time += delta * shake_noise_speed
	var strength := trauma * trauma
	offset = Vector2(
		max_shake_offset.x * strength * _noise.get_noise_2d(_noise_time, 0.0),
		max_shake_offset.y * strength * _noise.get_noise_2d(0.0, _noise_time)
	).round()
