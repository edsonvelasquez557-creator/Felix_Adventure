class_name RobotVacuum
extends Enemy
## Aspiradora robot: obstáculo móvil INVENCIBLE.
##
## Avanza en línea recta y rebota al tocar una pared (usa la normal de la
## colisión de move_and_slide). Opcionalmente también se gira en los bordes.
## Su Hurtbox es invencible: los ataques de Felix solo sacan chispas.
## La única respuesta es esquivarla (saltar por encima).

@export var move_speed: float = 70.0
@export var turn_at_ledges: bool = true
@export var spark_scene: PackedScene

@onready var ledge_ray: RayCast2D = %LedgeRay


func _ready() -> void:
	super()
	add_to_group(&"ground_enemy")
	hurtbox.invincible = true
	_play_animation(&"move")


func _physics_ai(_delta: float) -> void:
	velocity.x = facing * move_speed
	if is_on_wall():
		var normal_x := get_wall_normal().x
		# Solo rebota si la pared está delante (la normal apunta hacia atrás).
		if normal_x != 0.0 and signf(normal_x) != facing:
			set_facing(signf(normal_x))
			_play_bump()
	elif turn_at_ledges and is_on_floor() and not ledge_ray.is_colliding():
		set_facing(-facing)


func _on_facing_changed() -> void:
	ledge_ray.position.x = absf(ledge_ray.position.x) * facing
	ledge_ray.force_raycast_update()


func _on_hurtbox_blocked(hit: HitData) -> void:
	# Feedback de "invencible": chispas y destello, sin daño ni retroceso.
	_flash()
	var at := hurtbox.global_position
	if hit.source != null:
		at.x = lerpf(at.x, hit.source.global_position.x, 0.4)
	_spawn_at(spark_scene, at)


func _play_bump() -> void:
	_play_animation(&"bump")
	animation_player.queue(&"move")
