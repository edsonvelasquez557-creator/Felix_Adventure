@tool
class_name TutorialSign
extends Node2D
## Cartel de tutorial con texto distinto según el dispositivo.
##
## En móvil no tiene sentido decir "pulsa K": en Android/iOS se muestra
## [member touch_text] (si no está vacío); en escritorio, [member text].
## Se usa OS.has_feature("mobile") y no is_touchscreen_available(): con
## "Emulate Touch From Mouse" activo el escritorio también dice tener pantalla táctil.
## El texto usa un material "unshaded" para leerse aunque el nivel esté oscuro.

## Texto para teclado / mando.
@export_multiline var text: String = "":
	set(value):
		text = value
		_refresh()
## Texto alternativo para pantallas táctiles.
@export_multiline var touch_text: String = "":
	set(value):
		touch_text = value
		_refresh()

@onready var label: Label = %Label


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var use_touch := not Engine.is_editor_hint() and OS.has_feature("mobile")
	label.text = touch_text if use_touch and not touch_text.is_empty() else text
