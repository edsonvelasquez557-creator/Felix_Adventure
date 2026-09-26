class_name Enemy
extends CharacterBody2D
## Clase base de todos los enemigos.
##
## Resuelve lo común: gravedad, recepción de golpes (retroceso + aturdimiento),
## destello blanco al ser golpeado, orientación, muerte con botín de monedas.
## Cada enemigo concreto implementa su IA en [method _physics_ai] y puede
## reaccionar a golpes en [method _on_hit_reaction].
##
## Estructura esperada de la escena (nombres únicos con %):
##   Enemy (CharacterBody2D)
##   ├── CollisionShape2D
##   ├── Visuals (Node2D)            %Visuals
##   │   └── Sprite (Sprite2D)       %Sprite
##   ├── AnimationPlayer             %AnimationPlayer
##   ├── HealthComponent             %HealthComponent  (los invencibles no lo llevan)
##   ├── Hurtbox (Area2D)            %Hurtbox
##   └── ContactHitbox (Area2D)      %ContactHitbox

signal defeated(enemy: Enemy)

@export_group("Física")
@export var gravity: float = 900.0
@export var max_fall_speed: float = 500.0
@export var affected_by_gravity: bool = true

@export_group("Combate")
## Daño del contacto con Felix.
@export var contact_damage: int = 1
@export var hurt_stun_time: float = 0.3
## 0 = recibe todo el retroceso, 1 = inamovible.
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0
@export var coin_reward: int = 2
@export var coin_scene: PackedScene
@export var death_burst_scene: PackedScene

@export_group("Orientación")
## Dirección inicial: 1 = derecha, -1 = izquierda.
@export var initial_facing: float = -1.0
## True si el arte de la hoja mira a la derecha.
@export var sprite_faces_right: bool = true

var facing: float = -1.0
var is_dead: bool = false

var _stun_left := 0.0
var _flash_tween: Tween

@onready var visuals: Node2D = %Visuals
@onready var sprite: Sprite2D = %Sprite
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var contact_hitbox: Hitbox = %ContactHitbox
@onready var health: HealthComponent = get_node_or_null(^"%HealthComponent") as HealthComponent


func _ready() -> void:
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	hurtbox.blocked.connect(_on_hurtbox_blocked)
	if health != null:
		health.died.connect(_die)
	contact_hitbox.damage = contact_damage
	set_facing(initial_facing)


func _physics_process(delta: float) -> void:
	if affected_by_gravity and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	elif _stun_left > 0.0:
		_stun_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if not affected_by_gravity:
			velocity.y = move_toward(velocity.y, 0.0, 500.0 * delta)
		if _stun_left <= 0.0:
			contact_hitbox.active = true
			_on_stun_ended()
	else:
		_physics_ai(delta)
	move_and_slide()


## IA del enemigo. Se llama cada frame de física salvo aturdido o muerto.
func _physics_ai(_delta: float) -> void:
	pass


## Reacción específica al recibir daño (cancelar una embestida, girarse...).
func _on_hit_reaction(_hit: HitData) -> void:
	pass


## Se llama cuando termina el aturdimiento por un golpe.
func _on_stun_ended() -> void:
	pass


## Se llama tras cambiar de orientación (para voltear RayCasts, etc.).
func _on_facing_changed() -> void:
	pass


func set_facing(direction: float) -> void:
	if direction == 0.0:
		return
	facing = signf(direction)
	sprite.flip_h = (facing < 0.0) == sprite_faces_right
	_on_facing_changed()


func is_stunned() -> bool:
	return _stun_left > 0.0


## Muerte instantánea (zonas letales).
func kill() -> void:
	if health != null:
		health.kill()
	else:
		queue_free()


func _play_animation(animation_name: StringName) -> void:
	if animation_player.has_animation(animation_name) and animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


func _get_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _on_hurtbox_hurt(hit: HitData) -> void:
	_flash()
	if is_dead:
		return
	velocity = hit.knockback * (1.0 - knockback_resistance)
	_stun_left = hurt_stun_time
	# Un enemigo aturdido no hace daño por contacto: así los combos cuerpo a
	# cuerpo (Ráfaga de Rasguños) no castigan al jugador por acertar.
	contact_hitbox.active = false
	_play_animation(&"hurt")
	_on_hit_reaction(hit)


func _on_hurtbox_blocked(_hit: HitData) -> void:
	pass


## Destello blanco: self_modulate > 1 satura el color hacia blanco.
func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	sprite.self_modulate = Color(3.0, 3.0, 3.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	contact_hitbox.active = false
	hurtbox.set_deferred(&"monitorable", false)
	collision_layer = 0
	_spawn_coins()
	_spawn_at(death_burst_scene, global_position + Vector2(0.0, -10.0))
	EventBus.enemy_defeated.emit(self, global_position)
	defeated.emit(self)
	_play_animation(&"death")
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _spawn_coins() -> void:
	if coin_scene == null:
		return
	for i in coin_reward:
		var coin := _spawn_at(coin_scene, global_position + Vector2(0.0, -12.0)) as Coin
		if coin != null:
			coin.launch(Vector2(randf_range(-80.0, 80.0), randf_range(-200.0, -140.0)))


## Instancia [param scene] en el padre del enemigo (diferido: puede llamarse
## durante callbacks de física sin romper el estado del servidor de física).
func _spawn_at(scene: PackedScene, at: Vector2) -> Node2D:
	if scene == null:
		return null
	var instance := scene.instantiate() as Node2D
	var parent := get_parent() as Node2D
	instance.position = parent.to_local(at) if parent != null else at
	get_parent().add_child.call_deferred(instance)
	return instance
