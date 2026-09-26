class_name CatShelter
extends Area2D
## Meta de cada nivel: el Refugio de Gatos, cálido y seguro.
##
## Al atravesar el Area2D:
## 1. Felix camina hasta la puerta y celebra (estado VICTORY: sin control).
## 2. La luz de la ventana se intensifica y salen corazones.
## 3. Global.complete_level(): se depositan las monedas del intento, se
##    desbloquea el siguiente nivel y se guarda la partida.
## 4. Tras la celebración se carga la siguiente escena con SceneManager
##    (en segundo plano y con fundido).

signal reached

## Opcional: escena a cargar en lugar del siguiente nivel de la lista global.
@export_file("*.tscn") var next_scene_override: String = ""
@export var celebration_time: float = 1.6

var _triggered := false

@onready var door: Marker2D = %Door
@onready var window_light: PointLight2D = %WindowLight
@onready var hearts: CPUParticles2D = %Hearts


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if _triggered or player == null or player.state == Player.State.DEAD:
		return
	_triggered = true
	player.enter_shelter(door.global_position)
	hearts.emitting = true
	var tween := create_tween()
	tween.tween_property(window_light, "energy", window_light.energy * 1.8, 0.4)
	Global.complete_level(Global.current_level_index)
	Global.vibrate(120)
	reached.emit()
	EventBus.level_completed.emit()

	await get_tree().create_timer(celebration_time).timeout
	if next_scene_override.is_empty():
		SceneManager.go_to_next_level()
	else:
		SceneManager.change_scene(next_scene_override)
