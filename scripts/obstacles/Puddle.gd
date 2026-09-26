@tool
class_name Puddle
extends Area2D
## Charco: mientras un cuerpo está dentro, su velocidad horizontal se
## multiplica por [member speed_multiplier].
##
## No toca la física del cuerpo directamente: registra un modificador en él
## (add_speed_modifier / remove_speed_modifier). Si Felix pisa dos charcos a la
## vez, cada uno registra el suyo y no se pisan entre sí.
##
## El agua usa un CanvasTexture con mapa especular alto: refleja las farolas y
## la luz del Refugio gracias al sistema de luces 2D.

@export_range(0.1, 1.0, 0.05) var speed_multiplier: float = 0.5
## Ancho del charco en píxeles (ajusta colisión y visual).
@export var width: float = 48.0:
	set(value):
		width = maxf(value, 16.0)
		if is_node_ready():
			_apply_width()
@export var splash_scene: PackedScene

var _bodies: Array[Node2D] = []

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var surface: NinePatchRect = %Surface


func _ready() -> void:
	# La forma de colisión tiene resource_local_to_scene = true en Puddle.tscn:
	# cada instancia recibe su propia copia y puede tener un ancho distinto.
	_apply_width()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	for body in _bodies:
		if is_instance_valid(body) and body.has_method(&"remove_speed_modifier"):
			body.call(&"remove_speed_modifier", self)
	_bodies.clear()


func _apply_width() -> void:
	var rect := collision_shape.shape as RectangleShape2D
	if rect != null:
		rect.size = Vector2(width - 6.0, 8.0)
	surface.position.x = -width * 0.5
	surface.size.x = width


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"add_speed_modifier"):
		return
	body.call(&"add_speed_modifier", self, speed_multiplier)
	_bodies.append(body)
	_splash(body.global_position.x)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method(&"remove_speed_modifier"):
		body.call(&"remove_speed_modifier", self)
	_bodies.erase(body)


func _splash(at_x: float) -> void:
	if splash_scene == null:
		return
	var splash := splash_scene.instantiate() as Node2D
	splash.position = Vector2(to_local(Vector2(at_x, global_position.y)).x, -2.0)
	add_child.call_deferred(splash)
