class_name KillZone
extends Area2D
## Zona letal bajo el nivel (normalmente un WorldBoundaryShape2D: una línea
## infinita). Quien caiga aquí muere; lo que no pueda morir se libera.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Diferido: estamos dentro de un callback del servidor de física y matar
	# a un cuerpo cambia sus capas de colisión.
	if body.has_method(&"kill"):
		body.call_deferred(&"kill")
	else:
		body.queue_free()
