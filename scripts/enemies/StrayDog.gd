class_name StrayDog
extends Enemy
## Perro callejero: enemigo terrestre con embestida.
##
## Máquina de estados propia:
##   PATROL -> ALERT -> CHARGE -> RECOVER -> PATROL
## - PATROL: camina y da la vuelta ante paredes (WallRay) o bordes (LedgeRay).
## - ALERT: el VisionRay (RayCast2D horizontal a la altura de los ojos) choca
##   primero con Felix = línea de visión directa. Se frena y gruñe durante
##   [member alert_time]: es la telegrafía que avisa al jugador.
## - CHARGE: embestida en línea recta con daño y retroceso aumentados.
## - RECOVER: queda aturdido (más tiempo si se estrelló contra una pared).
##   Es la ventana ideal para castigarlo: mareado no hace daño por contacto.
## Si Felix salta por encima, el rayo no lo ve: esquivar es una estrategia.

enum DogState { PATROL, ALERT, CHARGE, RECOVER }

@export var patrol_speed: float = 40.0
@export var charge_speed: float = 230.0
## Telegrafía previa a la embestida. Menos tiempo = perro más peligroso.
@export var alert_time: float = 0.45
@export var charge_max_time: float = 1.3
@export var recover_time: float = 0.7
@export var wall_stun_time: float = 1.2
@export var vision_range: float = 150.0
@export var charge_damage: int = 2
@export var charge_knockback: float = 260.0
@export var turn_at_ledges: bool = true

var dog_state: DogState = DogState.PATROL

var _state_time := 0.0
var _recover_duration := 0.0
var _default_knockback := 0.0

@onready var vision_ray: RayCast2D = %VisionRay
@onready var wall_ray: RayCast2D = %WallRay
@onready var ledge_ray: RayCast2D = %LedgeRay


func _ready() -> void:
	super()
	add_to_group(&"ground_enemy")
	_default_knockback = contact_hitbox.knockback_force
	_enter_dog_state(DogState.PATROL)


func _physics_ai(delta: float) -> void:
	_state_time += delta
	match dog_state:
		DogState.PATROL:
			velocity.x = facing * patrol_speed
			if is_on_floor() and _is_path_blocked():
				set_facing(-facing)
			elif _can_see_player():
				_enter_dog_state(DogState.ALERT)
		DogState.ALERT:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _state_time >= alert_time:
				_enter_dog_state(DogState.CHARGE)
		DogState.CHARGE:
			velocity.x = facing * charge_speed
			if wall_ray.is_colliding():
				# Choque contra la pared: rebote y aturdimiento largo.
				velocity = Vector2(-facing * 70.0, -90.0)
				_recover_duration = wall_stun_time
				EventBus.camera_shake_requested.emit(0.2)
				_enter_dog_state(DogState.RECOVER)
			elif (turn_at_ledges and is_on_floor() and not ledge_ray.is_colliding()) \
					or _state_time >= charge_max_time:
				_recover_duration = recover_time
				_enter_dog_state(DogState.RECOVER)
		DogState.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _state_time >= _recover_duration:
				_enter_dog_state(DogState.PATROL)


func _enter_dog_state(new_state: DogState) -> void:
	dog_state = new_state
	_state_time = 0.0
	var charging := new_state == DogState.CHARGE
	contact_hitbox.damage = charge_damage if charging else contact_damage
	contact_hitbox.knockback_force = charge_knockback if charging else _default_knockback
	# Mareado tras la embestida: ventana segura para castigarlo.
	contact_hitbox.active = new_state != DogState.RECOVER
	match new_state:
		DogState.PATROL:
			_play_animation(&"walk")
		DogState.ALERT:
			_play_animation(&"alert")
		DogState.CHARGE:
			_play_animation(&"charge")
		DogState.RECOVER:
			_play_animation(&"recover")


func _can_see_player() -> bool:
	# El rayo detecta mundo y jugador: si lo primero que toca es Felix, lo ve.
	return vision_ray.is_colliding() and vision_ray.get_collider() is Player


func _is_path_blocked() -> bool:
	return wall_ray.is_colliding() or (turn_at_ledges and not ledge_ray.is_colliding())


func _on_facing_changed() -> void:
	vision_ray.target_position.x = vision_range * facing
	wall_ray.target_position.x = absf(wall_ray.target_position.x) * facing
	ledge_ray.position.x = absf(ledge_ray.position.x) * facing
	vision_ray.force_raycast_update()
	wall_ray.force_raycast_update()
	ledge_ray.force_raycast_update()


func _on_hit_reaction(hit: HitData) -> void:
	# Un golpe cancela la embestida y el perro se gira hacia el agresor.
	if hit.source != null:
		var side := signf(hit.source.global_position.x - global_position.x)
		if side != 0.0:
			set_facing(side)
	dog_state = DogState.RECOVER
	contact_hitbox.damage = contact_damage
	contact_hitbox.knockback_force = _default_knockback


func _on_stun_ended() -> void:
	_enter_dog_state(DogState.ALERT if _can_see_player() else DogState.PATROL)
