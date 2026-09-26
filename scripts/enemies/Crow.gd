class_name Crow
extends Enemy
## Cuervo: enemigo aéreo con movimiento senoidal.
##
## Patrulla horizontalmente alrededor de su punto de origen mientras su altura
## sigue una onda: y(t) = y0 + A · sin(2π · f · t). La velocidad vertical es un
## "resorte" hacia esa curva, de modo que tras recibir un empujón vuelve a la
## trayectoria con suavidad.
## En niveles avanzados ([member can_swoop] = true) se lanza en picado hacia
## la posición de Felix cuando lo tiene debajo y luego regresa a su ruta.
## No pertenece al grupo "ground_enemy": el Golpe Sísmico no le afecta.

enum CrowState { FLY, SWOOP, RETURN }

@export var fly_speed: float = 55.0
## Distancia máxima a cada lado del punto de origen.
@export var patrol_distance: float = 120.0
## Amplitud A de la onda (px).
@export var wave_amplitude: float = 18.0
## Frecuencia f de la onda (ciclos por segundo).
@export var wave_frequency: float = 0.8
## Rigidez del resorte que sigue la curva senoidal.
@export var wave_stiffness: float = 8.0
@export var can_swoop: bool = false
@export var swoop_speed: float = 190.0
@export var swoop_trigger_range: float = 120.0
@export var swoop_cooldown: float = 2.5
@export var swoop_max_time: float = 1.1

var crow_state: CrowState = CrowState.FLY

var _origin := Vector2.ZERO
var _wave_time := 0.0
var _state_time := 0.0
var _swoop_cooldown_left := 1.0
var _swoop_target := Vector2.ZERO


func _ready() -> void:
	affected_by_gravity = false
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	super()
	add_to_group(&"air_enemy")
	_origin = global_position
	# Fase aleatoria: varios cuervos juntos no aletean sincronizados.
	_wave_time = randf() * 10.0
	_play_animation(&"fly")


func _physics_ai(delta: float) -> void:
	_wave_time += delta
	_state_time += delta
	_swoop_cooldown_left -= delta
	match crow_state:
		CrowState.FLY:
			_fly()
		CrowState.SWOOP:
			_swoop()
		CrowState.RETURN:
			_return_to_route()


func _fly() -> void:
	if global_position.x > _origin.x + patrol_distance:
		set_facing(-1.0)
	elif global_position.x < _origin.x - patrol_distance:
		set_facing(1.0)
	var target_y := _origin.y + sin(_wave_time * TAU * wave_frequency) * wave_amplitude
	velocity = Vector2(facing * fly_speed, (target_y - global_position.y) * wave_stiffness)
	if can_swoop and _swoop_cooldown_left <= 0.0:
		_try_start_swoop()


func _try_start_swoop() -> void:
	var player := _get_player()
	if player == null or player.state == Player.State.DEAD:
		return
	var to_player := player.global_position - global_position
	if to_player.y > 8.0 and to_player.length() <= swoop_trigger_range:
		_swoop_target = player.global_position + Vector2(0.0, -10.0)
		set_facing(signf(to_player.x))
		_set_crow_state(CrowState.SWOOP)


func _swoop() -> void:
	var to_target := _swoop_target - global_position
	velocity = to_target.normalized() * swoop_speed
	if to_target.length() < 8.0 or _state_time >= swoop_max_time or is_on_wall():
		_set_crow_state(CrowState.RETURN)


func _return_to_route() -> void:
	var home := Vector2(
		clampf(global_position.x, _origin.x - patrol_distance, _origin.x + patrol_distance),
		_origin.y
	)
	var to_home := home - global_position
	velocity = to_home.normalized() * fly_speed * 1.6
	if to_home.length() < 6.0:
		_swoop_cooldown_left = swoop_cooldown
		_set_crow_state(CrowState.FLY)


func _set_crow_state(new_state: CrowState) -> void:
	crow_state = new_state
	_state_time = 0.0
	_play_animation(&"swoop" if new_state == CrowState.SWOOP else &"fly")


func _on_stun_ended() -> void:
	_set_crow_state(CrowState.RETURN)
