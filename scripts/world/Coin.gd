class_name Coin
extends Area2D
## Moneda coleccionable.
##
## El giro se hace cambiando el frame de la hoja por tiempo, sin
## AnimationPlayer: decenas de monedas comparten un cálculo barato por frame
## (importante en móvil). También flota con una onda senoidal redondeada a
## píxeles enteros para no romper la rejilla del Pixel Art.
## Las monedas que sueltan los enemigos saltan y, tras un instante, vuelan
## hacia Felix (imán): en pantalla táctil perseguir monedas es incómodo.

@export var value: int = 1
@export var spin_fps: float = 10.0
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0
@export var magnet_delay: float = 0.45
@export var magnet_speed: float = 280.0

var _time := 0.0
var _collected := false
var _launched := false
var _launch_time := 0.0
var _velocity := Vector2.ZERO
var _magnet_target: Node2D

@onready var sprite: Sprite2D = %Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Fase según la posición: las monedas de una fila no giran al unísono.
	_time = fposmod(global_position.x * 0.05, TAU)


func _process(delta: float) -> void:
	_time += delta
	sprite.frame = int(_time * spin_fps) % (sprite.hframes * sprite.vframes)
	if _launched:
		_update_launch(delta)
	elif not _collected:
		sprite.position.y = roundf(sin(_time * bob_speed) * bob_height)


## Lanza la moneda con [param initial_velocity] (botín de enemigos).
func launch(initial_velocity: Vector2) -> void:
	_launched = true
	_launch_time = 0.0
	_velocity = initial_velocity
	monitoring = false


func _update_launch(delta: float) -> void:
	_launch_time += delta
	if _launch_time < magnet_delay:
		_velocity.y += 700.0 * delta
		position += _velocity * delta
		return
	if not monitoring and not _collected:
		monitoring = true
	if not is_instance_valid(_magnet_target):
		_magnet_target = get_tree().get_first_node_in_group(&"player") as Node2D
	if _magnet_target != null:
		var target := _magnet_target.global_position + Vector2(0.0, -12.0)
		global_position = global_position.move_toward(target, magnet_speed * delta)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	_launched = false
	set_deferred(&"monitoring", false)
	Global.add_run_coins(value)
	EventBus.coin_collected.emit(value, global_position)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", sprite.position.y - 14.0, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
