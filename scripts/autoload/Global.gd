extends Node
## Autoload "Global": estado persistente del jugador.
##
## Responsabilidades:
## - Monedero persistente entre escenas (el Autoload nunca se destruye al
##   cambiar de escena) y entre sesiones (guardado en user://).
## - Monedas "del intento": lo que Felix recoge durante un nivel se acumula en
##   [member run_coins] y solo pasa al monedero al completar el nivel. Si Felix
##   muere o sale al menú se descartan. Así no se pueden farmear monedas
##   muriendo a propósito.
## - Tienda: catálogo de skins, compra, equipamiento y skin activa.
## - Progresión: niveles desbloqueados.
## - Ajustes de móvil (vibración) y guardado atómico.
##
## Ningún otro script escribe el archivo de guardado: todo pasa por aquí.

## Cambió el total visible de monedas (monedero + monedas del intento).
signal coins_changed(total: int)
## Se compró una skin.
signal skin_purchased(skin_id: StringName)
## Se equipó una skin (Felix la aplica al instante si está en escena).
signal skin_equipped(skin_id: StringName)
## Se desbloqueó un nivel nuevo.
signal level_unlocked(level_index: int)

enum PurchaseResult { SUCCESS, ALREADY_OWNED, NOT_ENOUGH_COINS, UNKNOWN_SKIN }

const SAVE_PATH := "user://savegame.cfg"
const SAVE_TMP_PATH := "user://savegame.tmp.cfg"
const SAVE_VERSION := 1
const SKIN_CATALOG_PATH := "res://resources/skins/SkinCatalog.tres"
const DEFAULT_SKIN_ID: StringName = &"classic"
const MOBILE_MAX_FPS := 60
## Orden oficial de los niveles. Se usan rutas (no PackedScene) para no
## cargar en memoria todos los niveles a la vez.
const LEVEL_PATHS: PackedStringArray = [
	"res://scenes/levels/Level_1.tscn",
	"res://scenes/levels/Level_2.tscn",
	"res://scenes/levels/Level_3.tscn",
	"res://scenes/levels/Level_4.tscn",
	"res://scenes/levels/Level_5.tscn",
	"res://scenes/levels/Level_6.tscn",
	"res://scenes/levels/Level_7.tscn",
	"res://scenes/levels/Level_8.tscn",
	"res://scenes/levels/Level_9.tscn",
	"res://scenes/levels/Level_10.tscn",
]

## Monedas depositadas (las únicas que se pueden gastar en la tienda).
var coins: int = 0:
	set(value):
		coins = maxi(value, 0)
		_emit_coins_changed()
## Monedas recogidas en el intento actual, aún sin depositar.
var run_coins: int = 0
var owned_skins: Array[StringName] = [DEFAULT_SKIN_ID]
var equipped_skin_id: StringName = DEFAULT_SKIN_ID
## Cuántos niveles están disponibles (1 = solo el primero).
var unlocked_level_count: int = 1
var game_completed: bool = false
## Índice (base 0) del nivel en juego; -1 si estamos en un menú.
var current_level_index: int = -1
var vibration_enabled: bool = true

var _skins: Array[SkinData] = []
var _skins_by_id: Dictionary[StringName, SkinData] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile"):
		# Tope de 60 FPS en móvil: ahorra batería en pantallas de 90/120 Hz y
		# mantiene el render alineado con los 60 ticks de física por segundo.
		Engine.max_fps = MOBILE_MAX_FPS
	_load_skin_catalog()
	load_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			# Android/iOS pueden cerrar la app en segundo plano sin avisar:
			# se guarda en cuanto deja de estar visible.
			save_game()


#region Monedas

## Total que muestra el HUD: monedero + monedas del intento.
func get_total_coins() -> int:
	return coins + run_coins


## Suma monedas recogidas durante el nivel (se depositan al completarlo).
func add_run_coins(amount: int) -> void:
	if amount <= 0:
		return
	run_coins += amount
	_emit_coins_changed()


## Pasa las monedas del intento al monedero persistente.
func bank_run_coins() -> void:
	if run_coins == 0:
		return
	var amount := run_coins
	run_coins = 0
	coins += amount


## Descarta las monedas del intento (muerte, reinicio o salida al menú).
func discard_run_coins() -> void:
	if run_coins == 0:
		return
	run_coins = 0
	_emit_coins_changed()


## Suma monedas directamente al monedero (recompensas, compras reales...).
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save_game()


func can_afford(price: int) -> bool:
	return price >= 0 and coins >= price


## Resta [param amount] del monedero. Devuelve false si no alcanza.
func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	return true

#endregion


#region Tienda y skins

## Skins en el orden del catálogo.
func get_skins() -> Array[SkinData]:
	return _skins.duplicate()


func get_skin(skin_id: StringName) -> SkinData:
	return _skins_by_id.get(skin_id)


func is_skin_owned(skin_id: StringName) -> bool:
	return skin_id in owned_skins


## Intenta comprar una skin. Solo se gasta el monedero depositado.
func purchase_skin(skin_id: StringName) -> PurchaseResult:
	var skin := get_skin(skin_id)
	if skin == null:
		return PurchaseResult.UNKNOWN_SKIN
	if is_skin_owned(skin_id):
		return PurchaseResult.ALREADY_OWNED
	if not spend_coins(skin.price):
		return PurchaseResult.NOT_ENOUGH_COINS
	owned_skins.append(skin_id)
	skin_purchased.emit(skin_id)
	save_game()
	return PurchaseResult.SUCCESS


## Equipa una skin ya comprada. Felix la aplica al instanciarse en el nivel.
func equip_skin(skin_id: StringName) -> bool:
	if not is_skin_owned(skin_id) or get_skin(skin_id) == null:
		return false
	if equipped_skin_id != skin_id:
		equipped_skin_id = skin_id
		skin_equipped.emit(skin_id)
		save_game()
	return true


func get_equipped_skin() -> SkinData:
	var skin := get_skin(equipped_skin_id)
	if skin == null:
		skin = get_skin(DEFAULT_SKIN_ID)
	return skin

#endregion


#region Progresión

func get_level_count() -> int:
	return LEVEL_PATHS.size()


func get_level_path(index: int) -> String:
	if index < 0 or index >= LEVEL_PATHS.size():
		return ""
	return LEVEL_PATHS[index]


func is_level_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_level_count


func has_next_level(index: int) -> bool:
	return index + 1 < LEVEL_PATHS.size()


## Nivel en el que continúa "Jugar": el último desbloqueado.
func get_resume_level_index() -> int:
	return clampi(unlocked_level_count - 1, 0, LEVEL_PATHS.size() - 1)


## Se llama al entrar en el Refugio: deposita monedas, desbloquea y guarda.
func complete_level(index: int) -> void:
	bank_run_coins()
	var next_index := index + 1
	if next_index >= LEVEL_PATHS.size():
		game_completed = true
	elif next_index >= unlocked_level_count:
		unlocked_level_count = next_index + 1
		level_unlocked.emit(next_index)
	save_game()

#endregion


#region Ajustes de móvil

func set_vibration_enabled(enabled: bool) -> void:
	vibration_enabled = enabled
	save_game()


## Vibración háptica. Solo actúa en móvil y si el jugador no la desactivó.
## Requiere el permiso VIBRATE en el preset de exportación de Android.
func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)

#endregion


#region Guardado

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("wallet", "coins", coins)
	var owned := PackedStringArray()
	for skin_id in owned_skins:
		owned.append(String(skin_id))
	config.set_value("shop", "owned_skins", owned)
	config.set_value("shop", "equipped_skin", String(equipped_skin_id))
	config.set_value("progress", "unlocked_levels", unlocked_level_count)
	config.set_value("progress", "game_completed", game_completed)
	config.set_value("settings", "vibration", vibration_enabled)

	# Guardado atómico: se escribe un temporal y se renombra encima del real.
	# Si el sistema mata la app a mitad de escritura, la partida previa sobrevive.
	var err := config.save(SAVE_TMP_PATH)
	if err != OK:
		push_error("Global: no se pudo escribir la partida (%s)." % error_string(err))
		return
	err = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
	if err != OK:
		# Algunos sistemas no reemplazan al renombrar: guardado directo.
		err = config.save(SAVE_PATH)
		DirAccess.remove_absolute(SAVE_TMP_PATH)
		if err != OK:
			push_error("Global: no se pudo guardar la partida (%s)." % error_string(err))


func load_game() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return # Primera partida: valores por defecto.
	if err != OK:
		push_warning("Global: partida ilegible (%s); se usan valores por defecto." % error_string(err))
		return

	var version := int(config.get_value("meta", "version", 0))
	if version > SAVE_VERSION:
		push_warning("Global: la partida es de una versión más nueva (%d)." % version)
	# Aquí irían las migraciones: if version < 2: ...

	coins = maxi(int(config.get_value("wallet", "coins", 0)), 0)
	owned_skins = _sanitize_owned_skins(config.get_value("shop", "owned_skins", PackedStringArray()))
	var equipped := StringName(str(config.get_value("shop", "equipped_skin", DEFAULT_SKIN_ID)))
	equipped_skin_id = equipped if is_skin_owned(equipped) else DEFAULT_SKIN_ID
	unlocked_level_count = clampi(int(config.get_value("progress", "unlocked_levels", 1)), 1, LEVEL_PATHS.size())
	var completed: Variant = config.get_value("progress", "game_completed", false)
	game_completed = completed is bool and completed
	var vibration: Variant = config.get_value("settings", "vibration", true)
	vibration_enabled = vibration if vibration is bool else true


## Borra el progreso (opción de ajustes / depuración).
func reset_progress() -> void:
	run_coins = 0
	coins = 0
	owned_skins = _sanitize_owned_skins(PackedStringArray())
	equipped_skin_id = DEFAULT_SKIN_ID
	unlocked_level_count = 1
	game_completed = false
	skin_equipped.emit(equipped_skin_id)
	save_game()

#endregion


func _load_skin_catalog() -> void:
	var catalog := load(SKIN_CATALOG_PATH) as SkinCatalog
	if catalog == null:
		push_error("Global: no se encontró el catálogo de skins en %s." % SKIN_CATALOG_PATH)
		return
	for skin in catalog.skins:
		if skin == null or not skin.is_valid():
			push_warning("Global: se ignoró una skin sin id o sin hoja de sprites.")
			continue
		if _skins_by_id.has(skin.id):
			push_warning("Global: id de skin duplicado '%s'." % skin.id)
			continue
		_skins.append(skin)
		_skins_by_id[skin.id] = skin
	if not _skins_by_id.has(DEFAULT_SKIN_ID):
		push_error("Global: el catálogo debe incluir la skin por defecto '%s'." % DEFAULT_SKIN_ID)
	owned_skins = _sanitize_owned_skins(PackedStringArray())


## Filtra ids desconocidos (partidas antiguas o editadas a mano) y asegura
## que las skins gratuitas estén siempre en posesión del jugador.
func _sanitize_owned_skins(saved: Variant) -> Array[StringName]:
	var result: Array[StringName] = [DEFAULT_SKIN_ID]
	for skin in _skins:
		if skin.price == 0 and not skin.id in result:
			result.append(skin.id)
	if saved is PackedStringArray or saved is Array:
		for entry: Variant in saved:
			var skin_id := StringName(str(entry))
			if _skins_by_id.has(skin_id) and not skin_id in result:
				result.append(skin_id)
	return result


func _emit_coins_changed() -> void:
	coins_changed.emit(get_total_coins())
