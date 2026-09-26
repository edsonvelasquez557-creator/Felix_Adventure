class_name Hitbox
extends Area2D
## Área que INFLIGE daño a los [Hurtbox] que solapa.
##
## Modos de impacto:
## - Golpe único ([member rehit_interval] = 0): cada objetivo recibe como máximo
##   un impacto por activación. Lo usan el Aullido y el Golpe Sísmico.
## - Daño continuo ([member rehit_interval] > 0): el mismo objetivo vuelve a
##   recibir daño cada N segundos mientras siga dentro. Lo usan el contacto de
##   enemigos y obstáculos.
## Los Rasguños reactivan el hitbox en cada tick (ver Player.gd), de modo que
## cada tick golpea una vez a todos los objetivos del área.
##
## El solapamiento se consulta en _physics_process (no solo con area_entered)
## para que un objetivo que ya estaba dentro al activarse también reciba daño.

signal hit_landed(hurtbox: Hurtbox, hit: HitData)

enum KnockbackMode {
	FROM_SOURCE, ## Horizontal, alejándose de [member source]. Contacto de enemigos.
	RADIAL, ## Desde el centro del hitbox hacia fuera. Aullido.
	FACING, ## Hacia donde mira el atacante ([member facing]). Rasguños.
}

@export var damage: int = 1
@export var knockback_force: float = 180.0
## Impulso vertical hacia arriba (px/s) que se suma al retroceso.
@export var knockback_lift: float = 120.0
@export var knockback_mode: KnockbackMode = KnockbackMode.FROM_SOURCE
## 0 = un impacto por objetivo y activación. >0 = segundos entre impactos al mismo objetivo.
@export_range(0.0, 5.0, 0.01) var rehit_interval: float = 0.0
## Si no está vacío, solo golpea a objetivos cuyo dueño pertenezca a este grupo.
@export var required_target_group: StringName = &""
## Un hitbox inactivo no golpea. Activarlo reinicia la memoria de impactos.
@export var active: bool = true:
	set(value):
		active = value
		if active:
			reset_hits()

## Nodo que golpea. Por defecto, la raíz de la escena dueña (owner).
var source: Node2D
## Dirección horizontal para [constant KnockbackMode.FACING] (1 = derecha, -1 = izquierda).
var facing: float = 1.0

var _elapsed := 0.0
var _last_hit_time: Dictionary[int, float] = {}


func _ready() -> void:
	monitorable = false
	if source == null:
		source = owner as Node2D


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null and _can_hit(hurtbox):
			_apply_hit(hurtbox)


## Olvida a quién se golpeó: la siguiente comprobación vuelve a golpear a todos.
func reset_hits() -> void:
	_last_hit_time.clear()


func _can_hit(hurtbox: Hurtbox) -> bool:
	if source != null and hurtbox.owner == source:
		return false
	if required_target_group != &"":
		var target := hurtbox.owner
		if target == null or not target.is_in_group(required_target_group):
			return false
	var target_id := hurtbox.get_instance_id()
	if not _last_hit_time.has(target_id):
		return true
	return rehit_interval > 0.0 and _elapsed - _last_hit_time[target_id] >= rehit_interval


func _apply_hit(hurtbox: Hurtbox) -> void:
	_last_hit_time[hurtbox.get_instance_id()] = _elapsed
	var hit := HitData.new(damage, _compute_knockback(hurtbox), source)
	hit.hitbox = self
	if hurtbox.receive_hit(hit):
		hit_landed.emit(hurtbox, hit)


func _compute_knockback(hurtbox: Hurtbox) -> Vector2:
	var target_position := hurtbox.global_position
	match knockback_mode:
		KnockbackMode.RADIAL:
			var direction := target_position - global_position
			if direction.length_squared() < 1.0:
				direction = Vector2(facing, 0.0)
			var push := direction.normalized() * knockback_force
			return Vector2(push.x, minf(push.y, 0.0) - knockback_lift)
		KnockbackMode.FACING:
			return Vector2(facing * knockback_force, -knockback_lift)
		_:
			var origin_x := source.global_position.x if source != null else global_position.x
			var side := signf(target_position.x - origin_x)
			if side == 0.0:
				side = facing
			return Vector2(side * knockback_force, -knockback_lift)
