class_name ParticleBurst
extends CPUParticles2D
## Ráfaga de partículas de un solo disparo que se libera sola al terminar.
## Útil para polvo, chispas, destellos de monedas o muertes de enemigos.
##
## Se usan CPUParticles2D a propósito: en móvil evitan el tirón de compilación
## de shaders de la primera emisión y funcionan igual en todos los renderers.


func _ready() -> void:
	one_shot = true
	emitting = true
	finished.connect(queue_free)
