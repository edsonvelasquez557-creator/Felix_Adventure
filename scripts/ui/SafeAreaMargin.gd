class_name SafeAreaMargin
extends MarginContainer
## Convierte el "safe area" del dispositivo (muescas, cámaras perforadas,
## bordes curvos) en márgenes, más un margen base. Así el HUD y los botones
## táctiles nunca quedan debajo de la muesca del teléfono.

@export var base_margin: int = 8


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var left := base_margin
	var top := base_margin
	var right := base_margin
	var bottom := base_margin
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe_area := Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0.0 and window_size.y > 0.0 and safe_area.has_area():
			# El safe area viene en píxeles de pantalla: se pasa a unidades del viewport.
			var ratio := get_viewport_rect().size / window_size
			left += int(safe_area.position.x * ratio.x)
			top += int(safe_area.position.y * ratio.y)
			right += int((window_size.x - safe_area.end.x) * ratio.x)
			bottom += int((window_size.y - safe_area.end.y) * ratio.y)
	add_theme_constant_override(&"margin_left", left)
	add_theme_constant_override(&"margin_top", top)
	add_theme_constant_override(&"margin_right", right)
	add_theme_constant_override(&"margin_bottom", bottom)
