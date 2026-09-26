class_name ObstacleSpawner
extends Marker2D
## Generador periódico de obstáculos (cajas desde una grúa, ovillos rodantes...).
##
## Solo actúa mientras está en pantalla (VisibleOnScreenNotifier2D): en móvil
## no se simulan obstáculos que el jugador no ve.
## [member instance_properties] permite configurar cada instancia sin código,
## p. ej. {"direction": -1.0} para un ovillo o {"drop_immediately": true}.

@export var obstacle_scene: PackedScene
@export var interval: float = 2.5
@export var start_delay: float = 0.6
@export var max_alive: int = 3
## Propiedades que se asignan a cada instancia al crearla.
@export var instance_properties: Dictionary = {}

var _time_left := 0.0
var _alive := 0

@onready var screen_notifier: VisibleOnScreenNotifier2D = %ScreenNotifier


func _ready() -> void:
	_time_left = start_delay


func _physics_process(delta: float) -> void:
	if obstacle_scene == null or not screen_notifier.is_on_screen():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = interval
		_spawn()


func _spawn() -> void:
	if _alive >= max_alive:
		return
	var instance := obstacle_scene.instantiate() as Node2D
	for property in instance_properties:
		instance.set(property, instance_properties[property])
	var parent_2d := get_parent() as Node2D
	instance.position = parent_2d.to_local(global_position) if parent_2d != null else global_position
	_alive += 1
	instance.tree_exited.connect(_on_instance_exited)
	get_parent().add_child(instance)


func _on_instance_exited() -> void:
	_alive = maxi(_alive - 1, 0)
