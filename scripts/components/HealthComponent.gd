class_name HealthComponent
extends Node
## Componente de vida reutilizable (Felix y enemigos).
##
## No sabe nada de animaciones ni de física: solo lleva la cuenta de puntos de
## vida y avisa con señales. El dueño decide qué hacer al recibir daño o morir.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export_range(1, 999, 1) var max_health: int = 3

var current_health: int = -1


func _ready() -> void:
	if current_health < 0:
		current_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var previous := current_health
	current_health = mini(current_health + amount, max_health)
	if current_health != previous:
		healed.emit(current_health - previous)
		health_changed.emit(current_health, max_health)


## Muerte instantánea (caída al vacío, zonas letales).
func kill() -> void:
	take_damage(current_health)


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health == 0
