extends Node
## Bus de eventos global (Autoload "EventBus").
##
## Solo declara señales: no guarda estado ni tiene lógica. Cualquier nodo puede
## emitirlas o escucharlas sin conocer a los demás, lo que desacopla gameplay,
## cámara, UI y audio. Regla de oro: el emisor nunca depende de que haya
## oyentes; si nadie escucha, el juego sigue funcionando igual.
##
## Las relaciones con un dueño claro (HUD <-> Player) usan señales directas del
## propio nodo. El bus se reserva para eventos transversales.

## Felix recogió [param amount] monedas en [param world_position].
signal coin_collected(amount: int, world_position: Vector2)

## Un enemigo fue derrotado en [param world_position].
signal enemy_defeated(enemy: Node2D, world_position: Vector2)

## Felix murió. El nivel decide cómo reiniciar.
signal player_died

## Felix entró en el Refugio de Gatos: el nivel está completado.
signal level_completed

## Pide un temblor de cámara. [param trauma] va de 0 a 1 y se acumula.
signal camera_shake_requested(trauma: float)

## Pide congelar la acción [param duration] segundos (hitstop) para dar peso a un golpe.
signal hitstop_requested(duration: float)
