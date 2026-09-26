class_name Player
extends CharacterBody2D
## Felix, el gato protagonista.
##
## Controlador de plataformas con una Máquina de Estados Finitos (FSM) explícita
## y cuatro habilidades con tiempo de recarga:
##   1. Aullido Expansivo  -> estado HOWL: un Area2D circular crece rápido,
##      daña y empuja radialmente a los enemigos.
##   2. Ráfaga de Rasguños -> estado SCRATCH: hitbox frontal temporal que se
##      reactiva en varios ticks (daño continuo) y remata con un empujón.
##   3. Furia Felina       -> estado FURY (lanzamiento corto) + buff de 8 s en
##      paralelo: daño base x2, tinte (modulate) pulsante, aura de luz y brasas.
##   4. Golpe Sísmico      -> estados SLAM_DIVE / SLAM_IMPACT: solo en el aire;
##      gravedad extrema hacia abajo y, al tocar el suelo (is_on_floor), grieta
##      visual, partículas, temblor y un hitbox rectangular amplio que daña a
##      los enemigos terrestres.
##
## Física "de diseñador": el salto se define con altura y tiempos, y de ahí se
## derivan la velocidad inicial y las gravedades de subida y caída. Incluye
## coyote time, jump buffer, salto de altura variable y "apex hang".
##
## Cada estado tiene tres piezas: entrada (_enter_state), lógica por frame de
## física (_physics_<estado>) y salida (_exit_state). Las transiciones solo
## ocurren a través de _change_state(), que garantiza que siempre se ejecute la
## salida del estado anterior (por ejemplo, apagar un hitbox si Felix recibe un
## golpe a mitad de un ataque).

signal state_changed(previous: State, current: State)
signal health_changed(current: int, maximum: int)
signal ability_activated(ability: Ability, cooldown: float)
signal fury_started(duration: float)
signal fury_ended
signal died

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	HOWL,
	SCRATCH,
	FURY,
	SLAM_DIVE,
	SLAM_IMPACT,
	HURT,
	DEAD,
	VICTORY,
}

enum Ability { HOWL, SCRATCH, FURY, SLAM }

## Acción del InputMap asociada a cada habilidad (índice = valor de Ability).
const ABILITY_ACTIONS: Array[StringName] = [
	&"ability_howl",
	&"ability_scratch",
	&"ability_fury",
	&"ability_slam",
]
const NO_ABILITY := -1

@export_group("Movimiento")
@export var run_speed: float = 150.0
@export var ground_acceleration: float = 1400.0
@export var ground_friction: float = 1800.0
## Aceleración al invertir la dirección en el suelo (giros más ágiles).
@export var turn_acceleration: float = 2600.0
@export var air_acceleration: float = 950.0
@export var air_friction: float = 420.0

@export_group("Salto")
## Altura máxima del salto en píxeles (16 px = 1 tile).
@export var jump_height: float = 58.0:
	set(value):
		jump_height = value
		_update_jump_physics()
## Segundos hasta el punto más alto.
@export var jump_time_to_peak: float = 0.36:
	set(value):
		jump_time_to_peak = maxf(value, 0.05)
		_update_jump_physics()
## Segundos de caída desde el punto más alto (menor = caída más "pesada").
@export var jump_time_to_descent: float = 0.3:
	set(value):
		jump_time_to_descent = maxf(value, 0.05)
		_update_jump_physics()
## Fracción de la velocidad de subida que se conserva al soltar el botón.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.45
## Por debajo de esta |velocidad vertical| se considera que Felix está en el ápice.
@export var apex_hang_threshold: float = 45.0
@export_range(0.1, 1.0, 0.05) var apex_gravity_multiplier: float = 0.55
@export var max_fall_speed: float = 420.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12

@export_group("Combate")
## Daño base de Felix. La Furia Felina lo multiplica.
@export var base_damage: int = 1
@export var hurt_stun_time: float = 0.3
## Entradas de habilidad pulsadas durante otra acción se recuerdan este tiempo.
@export var ability_buffer_time: float = 0.15

@export_group("Aullido Expansivo")
@export var howl_cooldown: float = 4.0
## Anticipación: segundos desde el inicio hasta que sale la onda.
@export var howl_windup: float = 0.18
## Duración total del estado (coincide con la animación: 8 frames a 16 FPS).
@export var howl_duration: float = 0.5
@export var howl_expand_time: float = 0.25
@export var howl_start_radius: float = 10.0
@export var howl_max_radius: float = 88.0
## Multiplicador sobre el daño base.
@export var howl_power: float = 2.0
@export var howl_knockback: float = 330.0
## Gravedad reducida si se aúlla en el aire (Felix "flota" un instante).
@export_range(0.0, 1.0, 0.05) var howl_air_gravity_scale: float = 0.2

@export_group("Ráfaga de Rasguños")
@export var scratch_cooldown: float = 0.8
## Duración total (10 frames a 24 FPS).
@export var scratch_duration: float = 0.42
@export var scratch_hits: int = 5
@export var scratch_first_hit_time: float = 0.04
@export var scratch_hit_interval: float = 0.08
@export var scratch_power: float = 1.0
@export var scratch_knockback: float = 40.0
@export var scratch_finisher_knockback: float = 240.0
@export var scratch_finisher_lift: float = 150.0
## Pequeño avance hacia delante mientras se rasguña.
@export var scratch_lunge_speed: float = 70.0
@export_range(0.0, 1.0, 0.05) var scratch_air_gravity_scale: float = 0.35

@export_group("Furia Felina")
@export var fury_cooldown: float = 20.0
## Duración del buff (el Timer FuryTimer se arranca con este valor).
@export var fury_duration: float = 8.0
## Duración del lanzamiento (8 frames a 18 FPS). Felix es invulnerable mientras.
@export var fury_cast_time: float = 0.45
@export var fury_damage_multiplier: float = 2.0
## Tinte (modulate) del nodo Visuals durante la furia. Valores >1 dan brillo.
@export var fury_tint: Color = Color(1.5, 0.62, 0.5)

@export_group("Golpe Sísmico")
@export var slam_cooldown: float = 3.0
## Altura mínima sobre el suelo para poder activarlo.
@export var slam_min_height: float = 20.0
## Suspensión en el aire antes del picado (anticipación).
@export var slam_hang_time: float = 0.1
@export var slam_start_speed: float = 380.0
## Multiplica la gravedad de caída durante el picado.
@export var slam_gravity_multiplier: float = 4.5
@export var slam_max_fall_speed: float = 900.0
@export var slam_power: float = 4.0
@export var slam_knockback: float = 200.0
@export var slam_knockback_lift: float = 280.0
## Segundos que el hitbox del impacto permanece activo.
@export var slam_hitbox_time: float = 0.12
## Recuperación tras el impacto (6 frames a 18 FPS).
@export var slam_recovery_time: float = 0.33
@export_range(0.0, 1.0, 0.05) var slam_shake_trauma: float = 0.65
@export var slam_hitstop: float = 0.06

@export_group("Efectos")
@export var slash_scene: PackedScene
@export var crack_scene: PackedScene

## Desactivar para cinemáticas o menús.
var input_enabled: bool = true
var state: State = State.IDLE
## Dirección a la que mira Felix: 1 derecha, -1 izquierda.
var facing: float = 1.0
## Eje horizontal leído este frame (-1..1, analógico con joystick).
var move_input: float = 0.0

var _state_time := 0.0
var _jump_velocity := 0.0
var _jump_gravity := 0.0
var _fall_gravity := 0.0
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _jump_held := false
var _buffered_ability: int = NO_ABILITY
var _ability_buffer_left := 0.0
var _cooldowns := PackedFloat32Array()
var _cooldown_totals := PackedFloat32Array()
var _speed_modifiers: Dictionary[int, float] = {}
var _howl_released := false
var _howl_circle: CircleShape2D
var _howl_tween: Tween
var _scratch_hits_done := 0
var _slash_flip := false
var _slam_diving := false
var _fury_tween: Tween
var _victory_target_x := 0.0
var _victory_arrived := false
var _base_normal_map: Texture2D
var _base_specular_map: Texture2D
var _base_specular_color := Color.WHITE
var _base_shininess := 1.0

@onready var visuals: Node2D = %Visuals
@onready var sprite: Sprite2D = %Sprite
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var howl_hitbox: Hitbox = %HowlHitbox
@onready var howl_shape: CollisionShape2D = %HowlShape
@onready var howl_wave: HowlWave = %HowlWave
@onready var scratch_hitbox: Hitbox = %ScratchHitbox
@onready var slam_hitbox: Hitbox = %SlamHitbox
@onready var slash_spawn: Marker2D = %SlashSpawn
@onready var ground_probe: RayCast2D = %GroundProbe
@onready var fury_timer: Timer = %FuryTimer
@onready var fury_aura: PointLight2D = %FuryAura
@onready var fury_embers: CPUParticles2D = %FuryEmbers
@onready var dust_particles: CPUParticles2D = %DustParticles
@onready var slam_debris: CPUParticles2D = %SlamDebris


#region Ciclo de vida

func _ready() -> void:
	add_to_group(&"player")
	_update_jump_physics()
	_cooldowns.resize(ABILITY_ACTIONS.size())
	_cooldown_totals.resize(ABILITY_ACTIONS.size())

	# El círculo del aullido se anima en tiempo real: cada instancia necesita
	# su propio recurso para no compartir el radio con otras escenas.
	howl_shape.shape = howl_shape.shape.duplicate() as Shape2D
	_howl_circle = howl_shape.shape as CircleShape2D
	howl_hitbox.active = false
	scratch_hitbox.active = false
	slam_hitbox.active = false
	ground_probe.target_position = Vector2(0.0, slam_min_height)

	# La textura de la escena es la skin base: se conserva su normal map y su
	# especular para reutilizarlos en skins que solo cambian el color.
	var base_texture := sprite.texture as CanvasTexture
	if base_texture != null:
		_base_normal_map = base_texture.normal_texture
		_base_specular_map = base_texture.specular_texture
		_base_specular_color = base_texture.specular_color
		_base_shininess = base_texture.specular_shininess
	apply_skin(Global.get_equipped_skin())

	Global.skin_equipped.connect(_on_skin_equipped)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	fury_timer.timeout.connect(_end_fury)

	_set_facing(facing)
	_enter_state(state, state)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_input()
	_state_time += delta
	match state:
		State.IDLE:
			_physics_idle(delta)
		State.RUN:
			_physics_run(delta)
		State.JUMP:
			_physics_jump(delta)
		State.FALL:
			_physics_fall(delta)
		State.HOWL:
			_physics_howl(delta)
		State.SCRATCH:
			_physics_scratch(delta)
		State.FURY:
			_physics_fury(delta)
		State.SLAM_DIVE:
			_physics_slam_dive(delta)
		State.SLAM_IMPACT:
			_physics_slam_impact(delta)
		State.HURT:
			_physics_hurt(delta)
		State.DEAD:
			_physics_dead(delta)
		State.VICTORY:
			_physics_victory(delta)
	move_and_slide()


func _process(_delta: float) -> void:
	# Parpadeo durante los frames de invulnerabilidad (solo visual).
	if hurtbox.is_blinking() and state != State.DEAD:
		sprite.visible = posmod(Time.get_ticks_msec(), 140) < 80
	else:
		sprite.visible = true

#endregion


#region API pública

## Aplica una skin de la tienda: solo cambia la textura difusa del Sprite2D.
## El normal map base se reutiliza si la skin no trae uno propio.
func apply_skin(skin: SkinData) -> void:
	if skin == null or skin.sprite_sheet == null:
		return
	var skin_texture := CanvasTexture.new()
	skin_texture.diffuse_texture = skin.sprite_sheet
	skin_texture.normal_texture = skin.normal_map if skin.normal_map != null else _base_normal_map
	skin_texture.specular_texture = _base_specular_map
	skin_texture.specular_color = _base_specular_color
	skin_texture.specular_shininess = _base_shininess
	sprite.texture = skin_texture


func can_use_ability(ability: Ability) -> bool:
	return _is_free_state() and is_ability_ready(ability)


## Disponibilidad para la UI: recarga terminada y condición de la habilidad.
func is_ability_ready(ability: Ability) -> bool:
	if _cooldowns[ability] > 0.0 or state == State.DEAD or state == State.VICTORY:
		return false
	match ability:
		Ability.FURY:
			return not is_fury_active()
		Ability.SLAM:
			return not is_on_floor() and not ground_probe.is_colliding()
	return true


func get_cooldown_remaining(ability: Ability) -> float:
	return _cooldowns[ability]


## 1 = recién usada, 0 = lista.
func get_cooldown_ratio(ability: Ability) -> float:
	var total := _cooldown_totals[ability]
	if total <= 0.0:
		return 0.0
	return clampf(_cooldowns[ability] / total, 0.0, 1.0)


func is_fury_active() -> bool:
	return not fury_timer.is_stopped()


func get_fury_time_left() -> float:
	return fury_timer.time_left if is_fury_active() else 0.0


## Multiplicador de daño actual (Furia Felina duplica el daño base).
func get_damage_multiplier() -> float:
	return fury_damage_multiplier if is_fury_active() else 1.0


## Los charcos (y cualquier otra fuente) registran un multiplicador de velocidad.
func add_speed_modifier(modifier_source: Object, multiplier: float) -> void:
	_speed_modifiers[modifier_source.get_instance_id()] = multiplier


func remove_speed_modifier(modifier_source: Object) -> void:
	_speed_modifiers.erase(modifier_source.get_instance_id())


func get_speed_multiplier() -> float:
	var result := 1.0
	for multiplier: float in _speed_modifiers.values():
		result *= multiplier
	return result


func get_health() -> int:
	return health.current_health


func get_max_health() -> int:
	return health.max_health


## Muerte instantánea (caída al vacío).
func kill() -> void:
	health.kill()


## El Refugio de Gatos llama a esto: Felix camina hasta la puerta y celebra.
func enter_shelter(door_position: Vector2) -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	_victory_target_x = door_position.x
	_change_state(State.VICTORY)

#endregion


#region Estados de movimiento

func _physics_idle(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	if _try_start_buffered_ability() or _try_jump():
		return
	if not is_on_floor():
		_change_state(State.FALL)
	elif move_input != 0.0:
		_change_state(State.RUN)


func _physics_run(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	if _try_start_buffered_ability() or _try_jump():
		return
	if not is_on_floor():
		_change_state(State.FALL) # El coyote time empieza a contar aquí.
	elif move_input == 0.0:
		_change_state(State.IDLE)


func _physics_jump(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	if _try_start_buffered_ability():
		return
	if velocity.y >= 0.0 or is_on_ceiling():
		_change_state(State.FALL)


func _physics_fall(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	if _try_start_buffered_ability() or _try_jump():
		return
	if is_on_floor():
		_land()

#endregion


#region Estados de habilidades

func _physics_howl(delta: float) -> void:
	_apply_gravity(delta, 1.0 if is_on_floor() else howl_air_gravity_scale)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if not _howl_released and _state_time >= howl_windup:
		_release_howl()
	if _state_time >= howl_duration:
		_return_to_neutral()


func _physics_scratch(delta: float) -> void:
	_apply_gravity(delta, 1.0 if is_on_floor() else scratch_air_gravity_scale)
	velocity.x = move_toward(velocity.x, facing * scratch_lunge_speed, ground_acceleration * delta)
	var next_hit_time := scratch_first_hit_time + _scratch_hits_done * scratch_hit_interval
	if _scratch_hits_done < scratch_hits and _state_time >= next_hit_time:
		_scratch_tick()
	if _state_time >= scratch_duration:
		_return_to_neutral()


func _physics_fury(delta: float) -> void:
	_apply_gravity(delta, 1.0 if is_on_floor() else 0.3)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if _state_time >= fury_cast_time:
		_return_to_neutral()


func _physics_slam_dive(delta: float) -> void:
	if _state_time < slam_hang_time:
		velocity = Vector2.ZERO # Anticipación: Felix se "congela" en el aire.
		return
	if not _slam_diving:
		_slam_diving = true
		velocity.y = slam_start_speed
		_play_animation(&"slam_dive")
	# Gravedad drásticamente aumentada: caída casi vertical y muy rápida.
	velocity.x = 0.0
	velocity.y = minf(velocity.y + _fall_gravity * slam_gravity_multiplier * delta, slam_max_fall_speed)
	if is_on_floor():
		_change_state(State.SLAM_IMPACT)


func _physics_slam_impact(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if slam_hitbox.active and _state_time >= slam_hitbox_time:
		slam_hitbox.active = false
	if _state_time >= slam_recovery_time:
		_return_to_neutral()

#endregion


#region Estados de daño, muerte y victoria

func _physics_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	if _state_time >= hurt_stun_time:
		_return_to_neutral()


func _physics_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)


func _physics_victory(delta: float) -> void:
	_apply_gravity(delta)
	var distance := _victory_target_x - global_position.x
	if absf(distance) > 2.0 and not _victory_arrived:
		_set_facing(signf(distance))
		velocity.x = move_toward(velocity.x, signf(distance) * run_speed * 0.6, ground_acceleration * delta)
	else:
		velocity.x = 0.0
		if not _victory_arrived and is_on_floor():
			_victory_arrived = true
			_play_animation(&"victory")

#endregion


#region Máquina de estados

func _change_state(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	_exit_state(previous)
	state = new_state
	_state_time = 0.0
	_enter_state(new_state, previous)
	state_changed.emit(previous, new_state)


func _enter_state(new_state: State, _previous: State) -> void:
	match new_state:
		State.IDLE:
			_play_animation(&"idle")
		State.RUN:
			_play_animation(&"run")
		State.JUMP:
			_play_animation(&"jump")
		State.FALL:
			_play_animation(&"fall")
		State.HOWL:
			_howl_released = false
			if not is_on_floor():
				velocity.y = minf(velocity.y, 0.0) * 0.3
			_play_animation(&"howl")
		State.SCRATCH:
			_scratch_hits_done = 0
			_orient_attack_nodes()
			if not is_on_floor():
				velocity.y = minf(velocity.y, 30.0)
			_play_animation(&"scratch")
		State.FURY:
			hurtbox.set_forced_invulnerable(true)
			_activate_fury()
			_play_animation(&"fury")
		State.SLAM_DIVE:
			_slam_diving = false
			velocity = Vector2.ZERO
			hurtbox.set_forced_invulnerable(true)
			_play_animation(&"slam_start")
		State.SLAM_IMPACT:
			velocity = Vector2.ZERO
			_play_animation(&"slam_impact")
			_perform_slam_impact()
		State.HURT:
			_play_animation(&"hurt")
		State.DEAD:
			_enter_dead()
		State.VICTORY:
			_victory_arrived = false
			hurtbox.set_forced_invulnerable(true)
			_play_animation(&"run")


func _exit_state(old_state: State) -> void:
	match old_state:
		State.SCRATCH:
			scratch_hitbox.active = false
		State.FURY, State.SLAM_DIVE:
			hurtbox.set_forced_invulnerable(false)
		State.SLAM_IMPACT:
			slam_hitbox.active = false


func _return_to_neutral() -> void:
	if is_on_floor():
		_change_state(State.RUN if move_input != 0.0 else State.IDLE)
	else:
		_change_state(State.FALL)


func _is_free_state() -> bool:
	return state == State.IDLE or state == State.RUN or state == State.JUMP or state == State.FALL

#endregion


#region Entrada y temporizadores

func _read_input() -> void:
	if not input_enabled or state == State.DEAD or state == State.VICTORY:
		move_input = 0.0
		_jump_held = false
		return
	move_input = Input.get_axis(&"move_left", &"move_right")
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_left = jump_buffer_time
	var jump_pressed := Input.is_action_pressed(&"jump")
	# Salto variable: soltar el botón mientras se sube recorta la velocidad.
	if _jump_held and not jump_pressed and state == State.JUMP and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	_jump_held = jump_pressed
	for i in ABILITY_ACTIONS.size():
		if Input.is_action_just_pressed(ABILITY_ACTIONS[i]):
			_buffered_ability = i
			_ability_buffer_left = ability_buffer_time


func _tick_timers(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left -= delta
	_jump_buffer_left -= delta
	_ability_buffer_left -= delta
	if _ability_buffer_left <= 0.0:
		_buffered_ability = NO_ABILITY

#endregion


#region Física

## Deriva velocidad y gravedades a partir de altura y tiempos del salto:
##   v0 = -2h / t_subida,  g_subida = 2h / t_subida²,  g_caída = 2h / t_caída²
func _update_jump_physics() -> void:
	_jump_velocity = -2.0 * jump_height / jump_time_to_peak
	_jump_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = 2.0 * jump_height / (jump_time_to_descent * jump_time_to_descent)


func _current_gravity() -> float:
	var result := _jump_gravity if velocity.y < 0.0 else _fall_gravity
	# "Apex hang": cerca del punto más alto la gravedad se suaviza si se
	# mantiene el botón de salto, lo que da más control en el aire.
	if _jump_held and absf(velocity.y) < apex_hang_threshold and (state == State.JUMP or state == State.FALL):
		result *= apex_gravity_multiplier
	return result


func _apply_gravity(delta: float, gravity_scale: float = 1.0) -> void:
	velocity.y = minf(velocity.y + _current_gravity() * gravity_scale * delta, max_fall_speed)


func _apply_horizontal_movement(delta: float) -> void:
	var target_speed := move_input * run_speed * get_speed_multiplier()
	var rate: float
	if is_on_floor():
		if move_input == 0.0:
			rate = ground_friction
		elif velocity.x != 0.0 and signf(move_input) != signf(velocity.x):
			rate = turn_acceleration
		else:
			rate = ground_acceleration
	else:
		rate = air_acceleration if move_input != 0.0 else air_friction
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if move_input != 0.0:
		_set_facing(signf(move_input))


func _try_jump() -> bool:
	if _jump_buffer_left <= 0.0:
		return false
	if not is_on_floor() and _coyote_left <= 0.0:
		return false
	velocity.y = _jump_velocity
	# Un salto "almacenado" con un toque breve ya soltado se trata como salto corto.
	if not Input.is_action_pressed(&"jump"):
		velocity.y *= jump_cut_multiplier
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	dust_particles.restart()
	_change_state(State.JUMP)
	return true


func _land() -> void:
	dust_particles.restart()
	if move_input != 0.0:
		_change_state(State.RUN)
	else:
		_change_state(State.IDLE)
		_play_animation(&"land")
		animation_player.queue(&"idle")


func _set_facing(direction: float) -> void:
	if direction == 0.0:
		return
	facing = signf(direction)
	# flip_h también invierte correctamente el normal map (Godot corrige la X).
	sprite.flip_h = facing < 0.0


## Coloca los nodos de ataque frontales en el lado al que mira Felix.
## Se mueve la posición en lugar de escalar por -1: las formas de colisión con
## escala negativa pueden dar resultados inesperados.
func _orient_attack_nodes() -> void:
	scratch_hitbox.position.x = absf(scratch_hitbox.position.x) * facing
	slash_spawn.position.x = absf(slash_spawn.position.x) * facing

#endregion


#region Habilidades

func _try_start_buffered_ability() -> bool:
	if _buffered_ability == NO_ABILITY:
		return false
	var ability := _buffered_ability as Ability
	if not can_use_ability(ability):
		return false # Se mantiene en el búfer por si queda libre en breve.
	_buffered_ability = NO_ABILITY
	var cooldown := _get_cooldown_duration(ability)
	_cooldowns[ability] = cooldown
	_cooldown_totals[ability] = cooldown
	ability_activated.emit(ability, cooldown)
	match ability:
		Ability.HOWL:
			_change_state(State.HOWL)
		Ability.SCRATCH:
			_change_state(State.SCRATCH)
		Ability.FURY:
			_change_state(State.FURY)
		Ability.SLAM:
			_change_state(State.SLAM_DIVE)
	return true


func _get_cooldown_duration(ability: Ability) -> float:
	match ability:
		Ability.HOWL:
			return howl_cooldown
		Ability.SCRATCH:
			return scratch_cooldown
		Ability.FURY:
			return fury_cooldown
		_:
			return slam_cooldown


## Daño final = daño base x potencia de la habilidad x multiplicador (Furia).
func _compute_damage(power: float) -> int:
	return maxi(1, roundi(base_damage * power * get_damage_multiplier()))


func _release_howl() -> void:
	_howl_released = true
	howl_hitbox.damage = _compute_damage(howl_power)
	howl_hitbox.knockback_force = howl_knockback
	howl_hitbox.facing = facing
	_howl_circle.radius = howl_start_radius
	howl_hitbox.active = true
	if _howl_tween != null:
		_howl_tween.kill()
	# El radio del CircleShape2D crece con una curva rápida al principio.
	_howl_tween = create_tween()
	_howl_tween.tween_property(_howl_circle, "radius", howl_max_radius, howl_expand_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_howl_tween.tween_callback(_on_howl_expanded)
	howl_wave.play(howl_start_radius, howl_max_radius, howl_expand_time + 0.12)
	EventBus.camera_shake_requested.emit(0.25)
	Global.vibrate(35)


func _on_howl_expanded() -> void:
	howl_hitbox.active = false
	_howl_circle.radius = howl_start_radius


func _scratch_tick() -> void:
	_scratch_hits_done += 1
	var is_finisher := _scratch_hits_done >= scratch_hits
	scratch_hitbox.damage = _compute_damage(scratch_power)
	scratch_hitbox.knockback_force = scratch_finisher_knockback if is_finisher else scratch_knockback
	scratch_hitbox.knockback_lift = scratch_finisher_lift if is_finisher else 0.0
	scratch_hitbox.facing = facing
	# Reactivar el hitbox borra su memoria: cada tick golpea una vez a cada objetivo.
	scratch_hitbox.active = true
	_spawn_slash(is_finisher)
	if is_finisher:
		Global.vibrate(25)


func _activate_fury() -> void:
	fury_timer.start(fury_duration)
	fury_aura.enabled = true
	fury_embers.emitting = true
	if _fury_tween != null:
		_fury_tween.kill()
	# Pulso de color: el tinte "respira" mientras dura la furia.
	_fury_tween = create_tween().set_loops()
	_fury_tween.tween_property(visuals, "modulate", fury_tint, 0.25)
	_fury_tween.tween_property(visuals, "modulate", fury_tint.lerp(Color.WHITE, 0.45), 0.25)
	fury_started.emit(fury_duration)
	EventBus.camera_shake_requested.emit(0.3)
	Global.vibrate(90)


func _end_fury() -> void:
	if _fury_tween != null:
		_fury_tween.kill()
		_fury_tween = null
	fury_timer.stop()
	visuals.modulate = Color.WHITE
	fury_aura.enabled = false
	fury_embers.emitting = false
	fury_ended.emit()


func _perform_slam_impact() -> void:
	slam_hitbox.damage = _compute_damage(slam_power)
	slam_hitbox.knockback_force = slam_knockback
	slam_hitbox.knockback_lift = slam_knockback_lift
	slam_hitbox.facing = facing
	slam_hitbox.active = true
	slam_debris.restart()
	dust_particles.restart()
	_spawn_effect(crack_scene, global_position)
	hurtbox.start_invulnerability(0.25)
	EventBus.camera_shake_requested.emit(slam_shake_trauma)
	EventBus.hitstop_requested.emit(slam_hitstop)
	Global.vibrate(80, 0.9)


func _spawn_slash(is_finisher: bool) -> void:
	var slash := _spawn_effect(slash_scene, slash_spawn.global_position)
	if slash == null:
		return
	_slash_flip = not _slash_flip
	slash.scale = Vector2(facing, -1.0 if _slash_flip else 1.0) * (1.4 if is_finisher else 1.0)


func _spawn_effect(scene: PackedScene, at: Vector2) -> Node2D:
	if scene == null:
		return null
	var effect := scene.instantiate() as Node2D
	var layer := get_tree().get_first_node_in_group(&"effects_layer")
	if layer == null:
		layer = get_parent()
	layer.add_child(effect)
	effect.global_position = at
	return effect

#endregion


#region Daño y muerte

func _on_hurt(hit: HitData) -> void:
	if health.is_dead() or state == State.DEAD:
		return
	velocity = hit.knockback if hit.knockback != Vector2.ZERO else Vector2(-facing * 150.0, -140.0)
	_change_state(State.HURT)
	EventBus.camera_shake_requested.emit(0.35)
	EventBus.hitstop_requested.emit(0.05)
	Global.vibrate(60)


func _on_died() -> void:
	_change_state(State.DEAD)


func _enter_dead() -> void:
	if is_fury_active():
		_end_fury()
	howl_hitbox.active = false
	velocity = Vector2(-facing * 60.0, -170.0)
	hurtbox.set_deferred(&"monitorable", false)
	_play_animation(&"death")
	died.emit()
	EventBus.player_died.emit()
	Global.vibrate(220)


func _on_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)


func _on_skin_equipped(_skin_id: StringName) -> void:
	apply_skin(Global.get_equipped_skin())

#endregion


func _play_animation(animation_name: StringName) -> void:
	if animation_player.has_animation(animation_name):
		animation_player.clear_queue()
		animation_player.play(animation_name)
