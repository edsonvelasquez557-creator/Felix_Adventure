extends SceneTree
## Construye las escenas de nivel (Level_N.tscn) a partir de los mapas ASCII
## de tools/levels/level_XX.txt.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tools/LevelBuilder.gd            (todos)
##   godot --headless --path . --script res://tools/LevelBuilder.gd -- 3       (solo el nivel 3)
##
## Los niveles generados son "greybox" jugables: la estructura de nodos es la
## definitiva (ver docs/01_Arquitectura_y_Escenas.md) y se pueden seguir
## editando en el editor. ¡Regenerar un nivel sobrescribe sus cambios manuales!
## Excluye la carpeta tools/ al exportar (filtro "tools/*" en el preset).

const TILE := 16
const LEVELS_DIR := "res://tools/levels/"
const OUTPUT_DIR := "res://scenes/levels/"
const TILESET := "res://resources/tilesets/city_tileset.tres"

const SCENES := {
	"player": "res://scenes/player/Player.tscn",
	"dog": "res://scenes/enemies/StrayDog.tscn",
	"crow": "res://scenes/enemies/Crow.tscn",
	"vacuum": "res://scenes/enemies/RobotVacuum.tscn",
	"puddle": "res://scenes/obstacles/Puddle.tscn",
	"hanging_crate": "res://scenes/obstacles/FallingCrate.tscn",
	"crates": "res://scenes/obstacles/CrateSpawner.tscn",
	"yarn": "res://scenes/obstacles/YarnBallSpawner.tscn",
	"coin": "res://scenes/world/Coin.tscn",
	"lamp": "res://scenes/world/StreetLamp.tscn",
	"sign": "res://scenes/world/TutorialSign.tscn",
	"shelter": "res://scenes/world/CatShelter.tscn",
	"kill_zone": "res://scenes/world/KillZone.tscn",
	"background": "res://scenes/world/ParallaxCity.tscn",
	"hud": "res://scenes/ui/HUD.tscn",
	"pause": "res://scenes/ui/PauseMenu.tscn",
}

## Tiles del atlas (columna, fila) por tema: [superficie, relleno].
const THEMES := {
	"street": [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]],
	"roof": [[Vector2i(4, 0)], [Vector2i(4, 1)]],
	"brick": [[Vector2i(3, 0)], [Vector2i(3, 1)]],
	"metal": [[Vector2i(3, 2)], [Vector2i(3, 2)]],
}
const SOLID_CHARS := "#BM"

var _tileset: TileSet
var _scenes := {}


func _initialize() -> void:
	_tileset = load(TILESET)
	for key: String in SCENES:
		_scenes[key] = load(SCENES[key])
	var only := -1
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = int(args[0])
	var dir := DirAccess.open(LEVELS_DIR)
	var files := Array(dir.get_files()).filter(func(f: String) -> bool: return f.begins_with("level_") and f.ends_with(".txt"))
	files.sort()
	for file: String in files:
		var number := int(file.get_basename().get_slice("_", 1))
		if only == -1 or only == number:
			_build_level(number, LEVELS_DIR + file)
	quit()


func _build_level(number: int, path: String) -> void:
	var data := _parse(path)
	var level_root := Node2D.new()
	level_root.name = "Level_%d" % number
	level_root.set_script(load("res://scripts/world/Level.gd"))
	level_root.set("level_index", number - 1)
	level_root.set("level_name", "Nivel %d\n%s" % [number, data.name])

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = load("res://resources/environments/level_environment.tres")
	level_root.add_child(env)
	var ambient := CanvasModulate.new()
	ambient.name = "CanvasModulate"
	ambient.color = Color(data.ambient)
	level_root.add_child(ambient)

	var background := _instance("background", level_root, "ParallaxCity")
	# El ParallaxBackground es un CanvasLayer propio: el CanvasModulate del
	# mundo no le afecta, así que lleva su propio tinte.
	var tint := CanvasModulate.new()
	tint.name = "BackgroundTint"
	tint.color = Color(data.background_tint)
	background.add_child(tint)

	var world := _group(level_root, "World")
	var back_layer := _tile_layer(world, "BackWall", -1, false)
	var ground := _tile_layer(world, "Ground", 0, true)
	var front_layer := _tile_layer(world, "Foreground", 2, false)
	var decor := _group(level_root, "Decor")
	var obstacles := _group(level_root, "Obstacles")
	var pickups := _group(level_root, "Pickups")
	var enemies := _group(level_root, "Enemies")

	var rows: Array = data.map
	var themes: Array = THEMES.get(data.theme, THEMES.street)
	var sign_index := 0
	var player: Node2D
	for y in rows.size():
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			var ch := row[x]
			var cell := Vector2i(x, y)
			var bottom := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			var center := Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			match ch:
				"#":
					var variants: Array = themes[0] if not _is_solid(rows, x, y - 1) else themes[1]
					ground.set_cell(cell, 0, variants[(x * 7 + y * 13) % variants.size()])
				"B":
					ground.set_cell(cell, 0, Vector2i(3, 0) if not _is_solid(rows, x, y - 1) else Vector2i(3, 1))
				"M":
					ground.set_cell(cell, 0, Vector2i(3, 2))
				"=":
					var left := x > 0 and row[x - 1] == "="
					var right := x + 1 < row.length() and row[x + 1] == "="
					var col := 1
					if not left and right:
						col = 0
					elif left and not right:
						col = 2
					ground.set_cell(cell, 0, Vector2i(col, 2))
				"g":
					front_layer.set_cell(cell, 0, Vector2i(7, 0))
				"P":
					player = _instance("player", level_root, "Player", bottom)
				"c":
					_instance("coin", pickups, "Coin", center)
				"D":
					_apply_overrides(_instance("dog", enemies, "StrayDog", bottom), data.overrides, "dog")
				"C", "W":
					var crow := _instance("crow", enemies, "Crow", center)
					_apply_overrides(crow, data.overrides, "crow")
					if ch == "W":
						crow.set("can_swoop", true)
				"V":
					_apply_overrides(_instance("vacuum", enemies, "RobotVacuum", bottom), data.overrides, "vacuum")
				"~":
					var run := 0
					while x + run < row.length() and row[x + run] == "~":
						run += 1
					var puddle := _instance("puddle", obstacles, "Puddle", Vector2((x + run * 0.5) * TILE, (y + 1) * TILE))
					puddle.set("width", run * TILE)
					x += run - 1
				"X":
					_apply_overrides(_instance("hanging_crate", obstacles, "FallingCrate", bottom), data.overrides, "hanging_crate")
				"K":
					_apply_overrides(_instance("crates", obstacles, "CrateSpawner", center), data.overrides, "crates")
				"Y":
					_apply_overrides(_instance("yarn", obstacles, "YarnBallSpawner", bottom), data.overrides, "yarn")
				"L":
					_instance("lamp", decor, "StreetLamp", bottom)
				"T":
					var sign_node := _instance("sign", decor, "TutorialSign", bottom)
					if sign_index < data.signs.size():
						var sign_text: String = data.signs[sign_index]
						var parts := sign_text.split("|")
						sign_node.set("text", parts[0].strip_edges())
						sign_node.set("touch_text", parts[1].strip_edges() if parts.size() > 1 else "")
					sign_index += 1
				"S":
					_instance("shelter", decor, "CatShelter", bottom)
			x += 1

	var back_rows: Array = data.background
	for y in back_rows.size():
		var back_row: String = back_rows[y]
		for x in back_row.length():
			match back_row[x]:
				"w":
					back_layer.set_cell(Vector2i(x, y), 0, Vector2i(5, (x + y) % 2))
				"o":
					back_layer.set_cell(Vector2i(x, y), 0, Vector2i(6, 1))
				"n":
					back_layer.set_cell(Vector2i(x, y), 0, Vector2i(6, 0))

	# Felix va después de enemigos y obstáculos: se dibuja por delante.
	if player != null:
		level_root.move_child(player, -1)
	var effects := _group(level_root, "Effects")
	effects.add_to_group(&"effects_layer", true)
	_instance("kill_zone", level_root, "KillZone", Vector2(0, rows.size() * TILE + 48))

	var camera := Camera2D.new()
	camera.name = "GameCamera"
	camera.set_script(load("res://scripts/world/GameCamera.gd"))
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_smoothed = true
	level_root.add_child(camera)
	_instance("hud", level_root, "HUD")
	_instance("pause", level_root, "PauseMenu")

	for unique_node: Node in [player, ground, camera, level_root.get_node("HUD")]:
		unique_node.owner = level_root
	_set_owner(level_root, level_root)
	# Los nodos añadidos DENTRO de una instancia (el tinte del fondo) no los
	# recorre _set_owner: hay que asignarles el dueño a mano o no se guardan.
	tint.owner = level_root
	for unique_node: Node in [player, ground, camera, level_root.get_node("HUD")]:
		unique_node.unique_name_in_owner = true

	var packed := PackedScene.new()
	packed.pack(level_root)
	var out_path := OUTPUT_DIR + "Level_%d.tscn" % number
	var err := ResourceSaver.save(packed, out_path)
	print("%s (%s) -> %s" % [out_path, data.name, error_string(err)])
	level_root.free()


func _parse(path: String) -> Dictionary:
	var data := {
		"name": "", "theme": "street", "ambient": "#ffffff", "background_tint": "#ffffff",
		"overrides": [], "signs": [], "map": [], "background": [],
	}
	var section := "header"
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges(false, true)
		if line.begins_with("--- mapa"):
			section = "map"
		elif line.begins_with("--- fondo"):
			section = "background"
		elif section == "header" and "=" in line:
			var key := line.get_slice("=", 0)
			var value := line.substr(key.length() + 1)
			match key:
				"sign":
					data.signs.append(value)
				"name", "theme", "ambient", "background_tint":
					data[key] = value
				_:
					data.overrides.append([key, value])
		elif section == "map" and not line.is_empty():
			data.map.append(line)
		elif section == "background" and not line.is_empty():
			data.background.append(line)
	return data


func _apply_overrides(target: Node, overrides: Array, prefix: String) -> void:
	for entry: Array in overrides:
		var key: String = entry[0]
		if key.begins_with(prefix + "."):
			target.set(key.substr(prefix.length() + 1), str_to_var(entry[1]))


func _is_solid(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size():
		return false
	var row: String = rows[y]
	return x < row.length() and SOLID_CHARS.contains(row[x])


func _group(parent: Node, group_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = group_name
	parent.add_child(n)
	return n


func _tile_layer(parent: Node, layer_name: String, z: int, solid: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _tileset
	layer.z_index = z
	layer.collision_enabled = solid
	layer.occlusion_enabled = solid
	parent.add_child(layer)
	return layer


func _instance(key: String, parent: Node, node_name: String, at := Vector2.ZERO) -> Node:
	var inst: Node = (_scenes[key] as PackedScene).instantiate()
	inst.name = node_name
	parent.add_child(inst, true)
	if inst is Node2D:
		(inst as Node2D).position = at
	return inst


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			_set_owner(child, owner_node)
