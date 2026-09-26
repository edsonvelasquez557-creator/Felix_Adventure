class_name PauseMenu
extends CanvasLayer
## Menú de pausa. Tiene process_mode = ALWAYS para seguir funcionando con el
## árbol de escena pausado.
##
## Se abre con:
## - La acción "pause" (Esc / P / Start del mando / botón táctil del HUD).
## - El botón "atrás" de Android (NOTIFICATION_WM_GO_BACK_REQUEST).
## - Automáticamente cuando la app pasa a segundo plano (llamada, notificación):
##   al volver, el jugador no se encuentra a Felix muerto.

@onready var overlay: Control = %Overlay
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var vibration_button: CheckButton = %VibrationButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	vibration_button.button_pressed = Global.vibration_enabled
	vibration_button.toggled.connect(Global.set_vibration_enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			toggle()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			open()


func is_open() -> bool:
	return overlay.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open() or SceneManager.is_transitioning or not is_node_ready():
		return
	get_tree().paused = true
	overlay.visible = true
	resume_button.grab_focus()


func close() -> void:
	get_tree().paused = false
	overlay.visible = false


func _on_restart_pressed() -> void:
	close()
	Global.discard_run_coins()
	SceneManager.reload_current_scene()


func _on_menu_pressed() -> void:
	close()
	SceneManager.go_to_main_menu()
