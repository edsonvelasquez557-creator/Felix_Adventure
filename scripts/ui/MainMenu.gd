extends Control
## Menú principal.
##
## - Jugar / Continuar: carga el último nivel desbloqueado.
## - Niveles: selector con los 10 niveles (los bloqueados aparecen deshabilitados).
## - Tienda: skins de Felix.
## - Salir: oculto en iOS (las guías de Apple no permiten cerrar la app).
## El botón "atrás" de Android cierra el selector o la app.

const IDLE_FRAMES := 6
const IDLE_FPS := 8.0

@export var lock_icon: Texture2D

var _preview_atlas: AtlasTexture
var _preview_time := 0.0

@onready var play_button: Button = %PlayButton
@onready var levels_button: Button = %LevelsButton
@onready var shop_button: Button = %ShopButton
@onready var quit_button: Button = %QuitButton
@onready var coin_label: Label = %CoinLabel
@onready var felix_preview: TextureRect = %FelixPreview
@onready var level_panel: Control = %LevelPanel
@onready var level_grid: GridContainer = %LevelGrid
@onready var close_levels_button: Button = %CloseLevelsButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	levels_button.pressed.connect(_open_level_panel)
	shop_button.pressed.connect(SceneManager.go_to_shop)
	quit_button.pressed.connect(get_tree().quit)
	close_levels_button.pressed.connect(_close_level_panel)
	quit_button.visible = not OS.has_feature("ios") and not OS.has_feature("web")
	coin_label.text = str(Global.coins)
	var resume_index := Global.get_resume_level_index()
	if resume_index > 0:
		play_button.text = "Continuar · Nivel %d" % (resume_index + 1)
	level_panel.visible = false
	_build_level_grid()
	_setup_preview()
	play_button.grab_focus()


func _process(delta: float) -> void:
	if _preview_atlas == null:
		return
	_preview_time += delta
	var frame_index := int(_preview_time * IDLE_FPS) % IDLE_FRAMES
	_preview_atlas.region.position.x = frame_index * SkinData.FRAME_SIZE.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if level_panel.visible:
			_close_level_panel()
		else:
			get_tree().quit()


func _on_play_pressed() -> void:
	SceneManager.go_to_level(Global.get_resume_level_index())


func _build_level_grid() -> void:
	for i in Global.get_level_count():
		var button := Button.new()
		var unlocked := Global.is_level_unlocked(i)
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(48.0, 40.0)
		button.disabled = not unlocked
		if not unlocked and lock_icon != null:
			button.icon = lock_icon
		button.pressed.connect(SceneManager.go_to_level.bind(i))
		level_grid.add_child(button)


func _open_level_panel() -> void:
	level_panel.visible = true
	close_levels_button.grab_focus()


func _close_level_panel() -> void:
	level_panel.visible = false
	levels_button.grab_focus()


## Felix con la skin equipada hace su animación de reposo en el menú.
func _setup_preview() -> void:
	var skin := Global.get_equipped_skin()
	if skin == null:
		return
	_preview_atlas = skin.get_preview_texture() as AtlasTexture
	felix_preview.texture = _preview_atlas
