class_name Hurtbox
extends Area2D
## Área que RECIBE golpes de un [Hitbox].
##
## Resta vida en el [HealthComponent] asignado y avisa al dueño con
## [signal hurt] (para aplicar retroceso, animación, parpadeo...). Si el golpe
## se ignora (invencible o con frames de invulnerabilidad) emite
## [signal blocked], útil para chispas o un sonido metálico.

signal hurt(hit: HitData)
signal blocked(hit: HitData)

@export var health: HealthComponent
## Nunca recibe daño (p. ej. la Aspiradora robot).
@export var invincible: bool = false
## Segundos de invulnerabilidad tras recibir daño (i-frames). 0 = ninguno.
@export_range(0.0, 5.0, 0.05) var invulnerability_time: float = 0.0

var _invulnerable_left := 0.0
var _blink_left := 0.0
var _forced_invulnerable := false


func _ready() -> void:
	monitoring = false


func _physics_process(delta: float) -> void:
	if _invulnerable_left > 0.0:
		_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _blink_left > 0.0:
		_blink_left = maxf(_blink_left - delta, 0.0)


## Aplica el golpe si procede. Devuelve true si el daño se hizo efectivo.
func receive_hit(hit: HitData) -> bool:
	if is_invulnerable():
		blocked.emit(hit)
		return false
	if health != null:
		health.take_damage(hit.damage)
	if invulnerability_time > 0.0:
		start_invulnerability(invulnerability_time, true)
	hurt.emit(hit)
	return true


func is_invulnerable() -> bool:
	return invincible or _forced_invulnerable or _invulnerable_left > 0.0 \
			or (health != null and health.is_dead())


## True mientras dura la invulnerabilidad por daño recibido (para el parpadeo).
func is_blinking() -> bool:
	return _blink_left > 0.0


## Invulnerabilidad temporal. [param blink] = true solo para los i-frames tras
## recibir daño; la protección de una habilidad (p. ej. el impacto sísmico)
## no debe hacer parpadear al personaje.
func start_invulnerability(duration: float, blink: bool = false) -> void:
	_invulnerable_left = maxf(_invulnerable_left, duration)
	if blink:
		_blink_left = maxf(_blink_left, duration)


## Invulnerabilidad controlada por estado (p. ej. durante el picado sísmico).
func set_forced_invulnerable(value: bool) -> void:
	_forced_invulnerable = value
