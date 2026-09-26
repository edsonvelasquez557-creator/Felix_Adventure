class_name SeismicCrack
extends Node2D
## Grieta del Golpe Sísmico: "rompe el piso" visualmente.
##
## Es un decal (Sprite2D) apoyado en la superficie del suelo, con un destello
## de luz breve (PointLight2D) que ilumina el entorno usando los normal maps.
## Tras [member lifetime] segundos se desvanece y se libera.

@export var lifetime: float = 5.0
@export var fade_time: float = 1.2
@export var flash_energy: float = 2.2
@export var flash_time: float = 0.35

@onready var decal: Sprite2D = %Decal
@onready var flash: PointLight2D = %Flash


func _ready() -> void:
	# Variante aleatoria para que dos grietas seguidas no se vean idénticas.
	decal.frame = randi() % (decal.hframes * decal.vframes)
	decal.flip_h = randf() < 0.5
	flash.energy = flash_energy
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "energy", 0.0, flash_time).set_ease(Tween.EASE_OUT)
	var life_tween := create_tween()
	life_tween.tween_interval(maxf(lifetime - fade_time, 0.0))
	life_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	life_tween.tween_callback(queue_free)
