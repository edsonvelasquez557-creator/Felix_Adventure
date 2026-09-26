class_name Level
extends Node2D
## Script raíz de cada nivel (Level_1 ... Level_10).
##
## Orquesta lo que pertenece al nivel y no a un actor concreto:
## - Registra el índice del nivel en Global y arranca el intento con 0 monedas.
## - Conecta el HUD con Felix y limita la cámara al tamaño del mapa.
## - Muerte de Felix: descarta monedas del intento y reinicia el nivel.
## - Hitstop: congela la acción unos milisegundos cuando se pide por EventBus.
## La victoria la gestiona el Refugio de Gatos (CatShelter).

@export_range(0, 9) var level_index: int = 0
@export var level_name: String = "Nivel"
@export var respawn_delay: float = 1.4
## Escala de tiempo durante el hitstop (0.05 = casi congelado).
@export_range(0.0, 1.0, 0.01) var hitstop_time_scale: float = 0.05
## Tiles extra por encima del mapa que la cámara puede mostrar (cielo abierto).
@export var camera_top_margin_tiles: int = 6

var _completed := false
var _hitstop_active := false

@onready var player: Player = %Player
@onready var camera: GameCamera = %GameCamera
@onready var hud: HUD = %HUD
@onready var ground: TileMapLayer = %Ground


func _ready() -> void:
	Global.current_level_index = level_index
	Global.discard_run_coins()
	camera.target = player
	camera.set_world_limits(_compute_world_rect())
	camera.snap_to_target()
	hud.bind_player(player)
	hud.show_banner(level_name)
	player.died.connect(_on_player_died)
	EventBus.hitstop_requested.connect(_on_hitstop_requested)
	EventBus.level_completed.connect(_on_level_completed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if not _completed:
		Global.discard_run_coins()


## Rectángulo del mundo (coordenadas globales) según los tiles usados.
func _compute_world_rect() -> Rect2:
	var used := ground.get_used_rect()
	var tile_size := Vector2(ground.tile_set.tile_size)
	var top_left := ground.to_global(Vector2(used.position) * tile_size)
	var size := Vector2(used.size) * tile_size
	top_left.y -= camera_top_margin_tiles * tile_size.y
	size.y += camera_top_margin_tiles * tile_size.y
	return Rect2(top_left, size)


func _on_player_died() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	Global.discard_run_coins()
	SceneManager.reload_current_scene()


func _on_level_completed() -> void:
	_completed = true
	hud.show_level_complete()


func _on_hitstop_requested(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = hitstop_time_scale
	# El temporizador ignora time_scale: dura "duration" segundos reales.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
