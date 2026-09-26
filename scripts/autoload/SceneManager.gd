extends CanvasLayer
## Autoload "SceneManager": cambios de escena con fundido y carga en segundo plano.
##
## Todas las transiciones del juego pasan por aquí:
## - La escena destino se carga con ResourceLoader.load_threaded_request()
##   mientras la pantalla se oscurece, así la app no se congela en móvil.
## - Durante el fundido se bloquea la entrada (evita dobles toques).
## - Al cambiar de escena se restablecen la pausa y Engine.time_scale (hitstop).
## - Se usan rutas de archivo, nunca PackedScene exportadas: una escena que
##   exporta el PackedScene del siguiente nivel arrastraría toda la cadena de
##   niveles a memoria al cargarse.

signal transition_started(target_path: String)
signal transition_finished(scene_path: String)

const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const SHOP_PATH := "res://scenes/ui/Shop.tscn"
const FADE_DURATION := 0.3
const FADE_COLOR := Color(0.078, 0.067, 0.122)

var is_transitioning := false

var _fade_rect: ColorRect


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = FADE_COLOR
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	add_child(_fade_rect)


## Cambia a la escena en [param path] con fundido a negro.
func change_scene(path: String) -> void:
	if is_transitioning:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: la escena '%s' no existe." % path)
		return
	is_transitioning = true
	transition_started.emit(path)
	Engine.time_scale = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var request_error := ResourceLoader.load_threaded_request(path)
	if request_error != OK:
		push_warning("SceneManager: carga en hilo no disponible (%s)." % error_string(request_error))
	await _fade_to(1.0)

	var packed := await _wait_for_threaded_load(path)
	get_tree().paused = false
	Engine.time_scale = 1.0
	if packed == null:
		push_error("SceneManager: no se pudo cargar '%s'." % path)
	else:
		get_tree().change_scene_to_packed(packed)
		await get_tree().scene_changed

	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_finished.emit(path)


func reload_current_scene() -> void:
	var current := get_tree().current_scene
	if current != null and not current.scene_file_path.is_empty():
		change_scene(current.scene_file_path)


func go_to_level(index: int) -> void:
	var path := Global.get_level_path(index)
	if path.is_empty():
		go_to_main_menu()
	else:
		change_scene(path)


## Carga el nivel siguiente al actual o vuelve al menú tras el último.
func go_to_next_level() -> void:
	var next_index := Global.current_level_index + 1
	if next_index < Global.get_level_count():
		go_to_level(next_index)
	else:
		go_to_main_menu()


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU_PATH)


func go_to_shop() -> void:
	change_scene(SHOP_PATH)


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_fade_rect, "modulate:a", alpha, FADE_DURATION)
	await tween.finished


func _wait_for_threaded_load(path: String) -> PackedScene:
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	# La petición en hilo falló o no existía: último intento síncrono.
	return load(path) as PackedScene
