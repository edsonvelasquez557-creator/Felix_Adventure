extends Control
## Tienda de skins de Felix.
##
## Las tarjetas se generan a partir del catálogo de Global: añadir una skin al
## catálogo (SkinCatalog.tres) basta para que aparezca aquí. Solo se gasta el
## monedero depositado (Global.coins). La skin equipada se aplica a Felix la
## próxima vez que se instancie un nivel (Player._ready -> apply_skin).

const SKIN_CARD_SCENE := preload("res://scenes/ui/SkinCard.tscn")

var _cards: Dictionary[StringName, SkinCard] = {}
var _message_tween: Tween

@onready var cards_container: HBoxContainer = %Cards
@onready var coin_label: Label = %CoinLabel
@onready var message_label: Label = %MessageLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(SceneManager.go_to_main_menu)
	Global.coins_changed.connect(_on_coins_changed)
	Global.skin_purchased.connect(_on_skins_changed)
	Global.skin_equipped.connect(_on_skins_changed)
	message_label.modulate.a = 0.0
	for skin in Global.get_skins():
		var card := SKIN_CARD_SCENE.instantiate() as SkinCard
		cards_container.add_child(card)
		card.setup(skin)
		card.action_requested.connect(_on_card_action_requested)
		_cards[skin.id] = card
	_on_coins_changed(Global.get_total_coins())
	back_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneManager.go_to_main_menu()


func _on_card_action_requested(skin_id: StringName) -> void:
	var skin := Global.get_skin(skin_id)
	if skin == null:
		return
	if Global.is_skin_owned(skin_id):
		Global.equip_skin(skin_id)
		_show_message("¡%s equipada!" % skin.display_name)
		return
	match Global.purchase_skin(skin_id):
		Global.PurchaseResult.SUCCESS:
			Global.equip_skin(skin_id)
			Global.vibrate(40)
			_show_message("¡Compraste %s!" % skin.display_name)
		Global.PurchaseResult.NOT_ENOUGH_COINS:
			_cards[skin_id].shake()
			Global.vibrate(20)
			_show_message("Te faltan %d monedas." % (skin.price - Global.coins))
		_:
			_show_message("No se pudo completar la compra.")


func _on_coins_changed(_total: int) -> void:
	# En la tienda solo cuenta lo depositado: es lo que se puede gastar.
	coin_label.text = str(Global.coins)
	for card: SkinCard in _cards.values():
		card.refresh()


func _on_skins_changed(_skin_id: StringName) -> void:
	for card: SkinCard in _cards.values():
		card.refresh()


func _show_message(text: String) -> void:
	message_label.text = text
	if _message_tween != null:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)
