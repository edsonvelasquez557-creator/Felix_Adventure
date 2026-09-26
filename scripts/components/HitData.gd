class_name HitData
extends RefCounted
## Paquete de información de un golpe: cuánto daño, qué retroceso y quién lo causó.
##
## Se crea en [Hitbox] y viaja hasta el [Hurtbox] que lo recibe. Al ser un
## RefCounted se libera solo cuando nadie lo referencia.

## Puntos de vida que resta.
var damage: int = 1
## Velocidad (px/s) que se aplica al objetivo como retroceso.
var knockback: Vector2 = Vector2.ZERO
## Nodo que origina el golpe (Felix, un perro, una caja...).
var source: Node2D
## Hitbox que produjo el golpe.
var hitbox: Area2D


func _init(p_damage: int = 1, p_knockback: Vector2 = Vector2.ZERO, p_source: Node2D = null) -> void:
	damage = p_damage
	knockback = p_knockback
	source = p_source
