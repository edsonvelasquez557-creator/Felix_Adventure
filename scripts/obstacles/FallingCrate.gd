class_name FallingCrate
extends CharacterBody2D
## Caja que cae.
##
## Estados:
## - WAITING: suspendida de una cuerda. El Area2D "Detector" (una columna bajo
##   la caja) detecta a Felix.
## - SHAKING: tiembla [member shake_time] segundos (aviso para el jugador).
## - FALLING: cae con gravedad; su Hitbox daña a Felix.
## - LANDED: se vuelve sólida (plataforma utilizable) o se rompe si
##   [member break_on_land] está activo (cajas de los CrateSpawner).
##
## Mientras espera y cae no es sólida (collision_layer = 0) para no empujar a
## Felix de forma extraña; al aterrizar pasa a la capa "world".

enum CrateState { WAITING, SHAKING, FALLING, LANDED }

const WORLD_LAYER := 1

@export var shake_time: float = 0.45
@export var gravity: float = 1100.0
@export var max_fall_speed: float = 620.0
## Cae nada más aparecer (lo usan los spawners).
@export var drop_immediately: bool = false
@export var break_on_land: bool = false
@export var debris_scene: PackedScene

var crate_state: CrateState = CrateState.WAITING

var _state_time := 0.0

@onready var visuals: Node2D = %Visuals
@onready var rope: Line2D = %Rope
@onready var detector: Area2D = %Detector
@onready var hitbox: Hitbox = %Hitbox


func _ready() -> void:
	collision_layer = 0
	hitbox.active = false
	detector.body_entered.connect(_on_detector_body_entered)
	if drop_immediately:
		rope.visible = false
		_set_state(CrateState.FALLING)


func _physics_process(delta: float) -> void:
	_state_time += delta
	match crate_state:
		CrateState.SHAKING:
			visuals.position.x = roundf(sin(_state_time * 70.0) * 1.5)
			if _state_time >= shake_time:
				visuals.position.x = 0.0
				rope.visible = false
				_set_state(CrateState.FALLING)
		CrateState.FALLING:
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
			move_and_slide()
			if is_on_floor():
				_land()


func _set_state(new_state: CrateState) -> void:
	crate_state = new_state
	_state_time = 0.0
	hitbox.active = new_state == CrateState.FALLING


func _on_detector_body_entered(body: Node2D) -> void:
	if crate_state == CrateState.WAITING and body is Player:
		detector.set_deferred(&"monitoring", false)
		_set_state(CrateState.SHAKING)


func _land() -> void:
	_set_state(CrateState.LANDED)
	velocity = Vector2.ZERO
	EventBus.camera_shake_requested.emit(0.18)
	if debris_scene != null:
		var debris := debris_scene.instantiate() as Node2D
		debris.position = position
		get_parent().add_child.call_deferred(debris)
	if break_on_land:
		queue_free()
	else:
		collision_layer = WORLD_LAYER
