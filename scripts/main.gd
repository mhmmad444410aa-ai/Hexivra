extends Node3D

const Puzzle = preload("res://scripts/puzzle.gd")
var puzzle = Puzzle.new()
var board := Node3D.new()
var tiles := {}
var tracks := {}
var rotations := {}
var camera := Camera3D.new()
var status := Label.new()
var level := 1
var moves := 0
var locked := false

func material(c: Color, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.45
	m.roughness = 0.35
	if emission:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	return m

func _ready() -> void:
	add_child(board)
	add_child(camera)
	camera.position = Vector3(0,12,0)
	camera.rotation_degrees = Vector3(-90,0,0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#080d1d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b1c8ff")
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60,25,0)
	add_child(light)
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu := VBoxContainer.new()
	layer.add_child(menu)
	menu.position = Vector2(24,24)
	var title := Label.new()
	title.text = "HEXIVRA"
	title.add_theme_font_size_override("font_size",48)
	menu.add_child(title)
	status.add_theme_font_size_override("font_size",24)
	menu.add_child(status)
	var retry := Button.new()
	retry.text = "Restart"
	retry.custom_minimum_size = Vector2(160,54)
	menu.add_child(retry)
	retry.pressed.connect(start_level)
	var next := Button.new()
	next.text = "Next level"
	next.custom_minimum_size = Vector2(160,54)
	menu.add_child(next)
	next.pressed.connect(func():
		if puzzle.is_solved():
			level += 1
			start_level()
	)
	start_level()

func world_pos(p: Vector2i) -> Vector3:
	return Vector3(1.732 * (p.x + p.y * 0.5),0,1.5*p.y)

func start_level() -> void:
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	tiles.clear()
	tracks.clear()
	rotations.clear()
	moves = 0
	locked = false
	puzzle.generate(2 if level < 5 else 3, level * 7187)
	camera.size = 16 if level < 5 else 22
	for p in puzzle.cells:
		var tile := Node3D.new()
		board.add_child(tile)
		tile.position = world_pos(p)
		tiles[p] = tile
		rotations[p] = 0.0
		var base := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.top_radius = 0.96
		mesh.bottom_radius = 0.96
		mesh.height = 0.24
		base.mesh = mesh
		base.material_override = material(Color("#28364f"))
		tile.add_child(base)
		var arms: Array[MeshInstance3D] = []
		for d in range(6):
			if (int(puzzle.masks[p]) & (1 << d)) == 0:
				continue
			var direction := world_pos(puzzle.DIRS[d]).normalized()
			var track := MeshInstance3D.new()
			var line := BoxMesh.new()
			line.size = Vector3(0.14,0.075,0.82)
			track.mesh = line
			track.position = direction * 0.41 + Vector3(0,0.16,0)
			track.rotation.y = atan2(direction.x,direction.z)
			tile.add_child(track)
			arms.append(track)
		tracks[p] = arms
	refresh()

func refresh() -> void:
	var power: Dictionary = puzzle.powered()
	var on := material(Color("#00eaff"),true)
	var off := material(Color("#536181"))
	for p in tracks:
		for arm in tracks[p]:
			arm.material_override = on if power.has(p) else off
	status.text = "Level %d | Moves %d | Power %d/%d" % [level,moves,power.size(),puzzle.cells.size()]
	if puzzle.is_solved():
		status.text += " | COMPLETE"

func _unhandled_input(event: InputEvent) -> void:
	var point: Vector2
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	else:
		return
	if locked or puzzle.is_solved():
		return
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var hit = Plane(Vector3.UP,0).intersects_ray(origin,direction)
	if hit == null:
		return
	for p in tiles:
		if world_pos(p).distance_to(hit) < 0.9:
			locked = true
			puzzle.masks[p] = puzzle.rotate_mask(puzzle.masks[p])
			moves += 1
			rotations[p] = float(rotations[p]) - PI/3
			var tween := create_tween()
			tween.tween_property(tiles[p],"rotation:y",rotations[p],0.16)
			await tween.finished
			locked = false
			refresh()
			break
