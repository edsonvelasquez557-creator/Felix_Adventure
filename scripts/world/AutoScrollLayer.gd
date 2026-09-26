class_name AutoScrollLayer
extends ParallaxLayer
## Capa de ParallaxBackground con desplazamiento automático (nubes que se
## mueven solas aunque la cámara esté quieta). Se suma al parallax normal.

@export var scroll_velocity: Vector2 = Vector2(-6.0, 0.0)


func _process(delta: float) -> void:
	motion_offset += scroll_velocity * delta
	# Mantener el desplazamiento acotado evita perder precisión en sesiones largas.
	if motion_mirroring.x > 0.0:
		motion_offset.x = fposmod(motion_offset.x, motion_mirroring.x)
	if motion_mirroring.y > 0.0:
		motion_offset.y = fposmod(motion_offset.y, motion_mirroring.y)
