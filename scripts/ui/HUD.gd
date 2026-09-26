class_name HUD
extends CanvasLayer
## HUD del nivel, pensado para pantallas táctiles.
##
## - Arriba a la izquierda: corazones, monedas y barra de Furia Felina.
## - Arriba a la derecha: botón de pausa.
## - Abajo a la izquierda: joystick virtual flotante.
## - Abajo a la derecha: salto + 4 habilidades con indicador de recarga.
## Todo vive dentro de un SafeAreaMargin para respetar muescas y bordes.
## El nivel conecta a Felix con bind_player(); el HUD no busca nodos por su cuenta.

@export var heart_full: Texture2D
@export var heart_empty: Texture2D
## Muestra los controles táctiles también en escritorio (probar en el editor).
@export var always_show_touch_controls: bool = true

var _player: Player
var _banner_tween: Tween
var _coin_tween: Tween
var _level_coins := 0

@onready var hearts: HBoxContainer = %Hearts
@onready var coin_icon: TextureRect = %CoinIcon
@onready var coin_label: Label = %CoinLabel
@onready var fury_bar: ProgressBar = %FuryBar
@onready var banner: Label = %Banner
@onready var touch_controls: Control = %TouchControls
@onready var action_cluster: Control = %ActionCluster


func _ready() -> void:
	fury_bar.visible = false
	banner.modulate.a = 0.0
	touch_controls.visible = always_show_touch_controls or DisplayServer.is_touchscreen_available()
	Global.coins_changed.connect(_on_coins_changed)
	EventBus.coin_collected.connect(_on_coin_collected)
	_set_coin_text(Global.get_total_coins())


func _process(_delta: float) -> void:
	if fury_bar.visible and is_instance_valid(_player) and _player.fury_duration > 0.0:
		fury_bar.value = _player.get_fury_time_left() / _player.fury_duration * 100.0


## Conecta el HUD con Felix (lo llama Level.gd).
func bind_player(player: Player) -> void:
	_player = player
	player.health_changed.connect(_update_hearts)
	player.fury_started.connect(_on_fury_started)
	player.fury_ended.connect(_on_fury_ended)
	_update_hearts(player.get_health(), player.get_max_health())
	for child in action_cluster.get_children():
		var button := child as AbilityButton
		if button != null:
			button.player = player


## Texto grande centrado que aparece y se desvanece (nombre del nivel, avisos).
func show_banner(text: String, hold_time: float = 1.8) -> void:
	banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(hold_time)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)


func show_level_complete() -> void:
	show_banner("¡A salvo en el Refugio!\n+%d monedas" % _level_coins, 3.0)


func _update_hearts(current: int, maximum: int) -> void:
	while hearts.get_child_count() < maximum:
		var heart := TextureRect.new()
		heart.texture = heart_full
		heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		hearts.add_child(heart)
	while hearts.get_child_count() > maximum:
		var extra := hearts.get_child(hearts.get_child_count() - 1)
		hearts.remove_child(extra)
		extra.queue_free()
	for i in hearts.get_child_count():
		var heart := hearts.get_child(i) as TextureRect
		heart.texture = heart_full if i < current else heart_empty


func _on_coins_changed(total: int) -> void:
	_set_coin_text(total)
	if _coin_tween != null:
		_coin_tween.kill()
	coin_icon.pivot_offset = coin_icon.size * 0.5
	coin_icon.scale = Vector2(1.5, 1.5)
	_coin_tween = create_tween()
	_coin_tween.tween_property(coin_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _on_coin_collected(amount: int, _world_position: Vector2) -> void:
	_level_coins += amount


func _set_coin_text(total: int) -> void:
	coin_label.text = str(total)


func _on_fury_started(_duration: float) -> void:
	fury_bar.value = 100.0
	fury_bar.visible = true


func _on_fury_ended() -> void:
	fury_bar.visible = false
