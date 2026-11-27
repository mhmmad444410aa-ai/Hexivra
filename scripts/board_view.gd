extends Node3D

const TILE = preload("res://assets/models/grass.glb")
const FLOOR = preload("res://assets/models/floor-panel.glb")
const RING = preload("res://assets/models/pipe-ring.glb")
const CORE = preload("res://assets/models/energy-core.glb")
const PROJECTOR = preload("res://assets/models/molecule-hologram-projector.glb")
const ARC = preload("res://assets/vfx/lightning_arc.gdshader")
const SPARK = preload("res://assets/vfx/spark.png")
const PIPES = preload("res://assets/models/Column_Pipes.gltf")
const Puzzle = preload("res://scripts/puzzle.gd")
const Validator = Puzzle.Validator

var camera := Camera3D.new()
var board := Node3D.new()
var station := Node3D.new()
var reactor := Node3D.new()
var tiles := {}
var traces := {}
var markers := {}
var hint_marker: MeshInstance3D
var deck: StandardMaterial3D
var idle: StandardMaterial3D
var metal: StandardMaterial3D
var alert: StandardMaterial3D
var colours: Array[StandardMaterial3D] = []
var trace_mesh := BoxMesh.new()
var pulse: ShaderMaterial
var phase := 0.0
var sparks := CPUParticles3D.new()
var rotors: Array[Node3D] = []
var holograms: Array[Node3D] = []
var last_power := {}
var wave := MeshInstance3D.new()
var wave_material: StandardMaterial3D
var wave_tween: Tween
var arc := MeshInstance3D.new()
var arc_material := ShaderMaterial.new()
var arc_time := 0.0
var quality := 1
var light := DirectionalLight3D.new()
var highlight: Vector2i
var highlighted := false

func alloy(colour: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.55
	material.roughness = 0.38
	if emissive:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 1.2
	return material

func _ready() -> void:
	deck = alloy(Color("#142038"))
	metal = alloy(Color("#364965"))
	idle = alloy(Color("#6e819d"))
	alert = alloy(Color("#ff906d"), true)
	colours = [alloy(Color("#28e6f5"), true), alloy(Color("#b780ff"), true)]
	trace_mesh.size = Vector3(0.11, 0.025, 0.84)
	var shader := Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode unshaded;
		instance uniform vec4 channel : source_color = vec4(0.15, 0.90, 0.97, 1.0);
		instance uniform float step_distance = 0.0;
		uniform float animate = 1.0;
		void fragment() {
			float t = sin(TIME * 4.0 - step_distance * 1.2 - UV.x * 6.0);
			ALBEDO = channel.rgb * (0.58 + animate * 0.42 * smoothstep(0.0, 1.0, t));
		}
	"""
	pulse = ShaderMaterial.new()
	pulse.shader = shader
	add_child(board)
	add_child(station)
	station.add_child(reactor)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#070e1d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#ccd8ff")
	environment.environment.ambient_light_energy = 0.95
	add_child(environment)
	light.rotation_degrees = Vector3(-65, -20, 0)
	light.light_color = Color("#bddeff")
	light.light_energy = 2.0
	add_child(light)
	for x in [-5.8, 5.8]:
		for z in [-3.0, 3.0]:
			var pipes := model(PIPES, station, metal, Vector3(x, -1.3, z), Vector3.ONE * 0.7)
			pipes.rotation.z = PI / 2.0
	for z in [-3.2, 0.0, 3.2]:
		model(FLOOR, station, deck, Vector3(0, -1.05, z), Vector3(11.5, 1, 3.2))
	model(RING, reactor, metal, Vector3(0, -0.1, 0), Vector3(8, 2, 8))
	var core: Node3D = CORE.instantiate()
	reactor.add_child(core)
	core.scale = Vector3.ONE * 2.55
	for rotor_name in ["Ring_1", "Ring_2", "Crystal"]:
		var rotor := core.find_child(rotor_name, true, false) as Node3D
		if rotor:
			rotors.append(rotor)
	for x in [-4.8, 4.8]:
		var projector: Node3D = PROJECTOR.instantiate()
		station.add_child(projector)
		projector.position = Vector3(x, -0.68, -3.1)
		projector.scale = Vector3.ONE * 0.75
		var molecule := projector.find_child("Molecule", true, false) as Node3D
		if molecule:
			holograms.append(molecule)
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.29, 0.29)
	var particle_material := StandardMaterial3D.new()
	particle_material.albedo_texture = SPARK
	particle_material.albedo_color = Color("#7cfaff")
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_mesh.material = particle_material
	sparks.mesh = particle_mesh
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 12
	sparks.lifetime = 0.55
	sparks.explosiveness = 1.0
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0, -5, 0)
	sparks.direction = Vector3.UP
	sparks.spread = 80
	add_child(sparks)
	var wave_mesh := TorusMesh.new()
	wave_mesh.inner_radius = 0.83
	wave_mesh.outer_radius = 0.9
	wave_mesh.rings = 48
	wave_mesh.ring_segments = 6
	wave.mesh = wave_mesh
	wave.position.y = 0.36
	wave_material = alloy(Color("#50efef"), true)
	wave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = wave_material
	add_child(wave)
	wave.hide()
	var strip := QuadMesh.new()
	strip.size = Vector2(0.14, 1.35)
	strip.subdivide_depth = 11
	arc.mesh = strip
	arc.rotation_degrees.x = -90
	arc_material.shader = ARC
	var pattern := FastNoiseLite.new()
	pattern.frequency = 0.16
	var noise := ImageTexture.create_from_image(pattern.get_image(32, 64))
	arc_material.set_shader_parameter("displacement_noise", noise)
	arc.material_override = arc_material
	add_child(arc)
	arc.hide()
	preview()

func model(scene: PackedScene, parent: Node3D, material: Material, location: Vector3, dimensions: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate()
	parent.add_child(node)
	node.position = location
	node.scale = dimensions
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	return node

func set_quality(value: int) -> void:
	quality = value
	light.shadow_enabled = value == 2
	pulse.set_shader_parameter("animate", float(value > 0))

func _process(delta: float) -> void:
	if reactor.visible:
		reactor.rotation.y += delta * 0.27
		for i in range(rotors.size()):
			rotors[i].rotate_y(delta * (0.5 if i != 1 else -0.7))
	for molecule in holograms:
		molecule.rotate_y(delta * 0.42)
	phase += delta
	if arc.visible:
		arc_time -= delta
		arc_material.set_shader_parameter("strength", clampf(arc_time / 0.45, 0.0, 0.85))
		if arc_time <= 0.0:
			arc.hide()
	if highlighted and is_instance_valid(hint_marker):
		hint_marker.position.y = 0.42 + sin(phase * 4.0) * 0.06

func preview() -> void:
	board.hide()
	arc.hide()
	reactor.show()
	camera.position = Vector3(0, 12, 8)
	camera.look_at(Vector3(0, 0, 2))
	camera.size = 12.5

func world_pos(p: Vector2i) -> Vector3:
	return Vector3(1.73205 * (p.x + p.y * 0.5), 0, 1.5 * p.y)

func build(puzzle: RefCounted, skin: int) -> void:
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	tiles.clear()
	traces.clear()
	markers.clear()
	highlighted = false
	board.show()
	reactor.hide()
	last_power.clear()
	wave.hide()
	arc.hide()
	var width := 0.0
	for p in puzzle.cells:
		width = maxf(width, absf(world_pos(p).x))
	camera.position = Vector3(0, 15, 6)
	camera.look_at(Vector3.ZERO)
	camera.size = maxf(11.0, (width * 2.0 + 2.4) / 0.5625)
	for p in puzzle.cells:
		var tile := Node3D.new()
		board.add_child(tile)
		tile.position = world_pos(p)
		tiles[p] = tile
		model(TILE, tile, deck if skin == 0 else metal, Vector3.ZERO, Vector3(1.61, 0.94, 1.61))
		var inset := model(TILE, tile, metal if skin == 0 else deck, Vector3(0, 0.185, 0), Vector3(1.48, 0.35, 1.48))
		inset.rotation.y = 0.0
		var arms: Array[MeshInstance3D] = []
		for d in range(6):
			if not (int(puzzle.masks[p]) & (1 << d)):
				continue
			var direction := world_pos(Puzzle.DIRS[d]).normalized()
			var arm := MeshInstance3D.new()
			arm.mesh = trace_mesh
			arm.position = direction * 0.41 + Vector3(0, 0.27, 0)
			arm.rotation.y = atan2(direction.x, direction.z)
			tile.add_child(arm)
			arms.append(arm)
			if puzzle.laser_input(p) == d and int(puzzle.masks[p]) not in [9, 18, 36]:
				var input_marker := MeshInstance3D.new()
				input_marker.mesh = trace_mesh
				input_marker.scale = Vector3(1.9, 1.0, 0.12)
				input_marker.rotation.y = arm.rotation.y
				input_marker.position = direction * 0.67 + Vector3(0, 0.299, 0)
				input_marker.material_override = colours[1]
				tile.add_child(input_marker)
		traces[p] = arms
		var marker := Label3D.new()
		marker.font_size = 60
		marker.pixel_size = 0.01
		marker.outline_size = 12
		marker.position = tile.position + Vector3(0, 0.35, 0)
		marker.rotation_degrees.x = -90
		board.add_child(marker)
		markers[p] = marker
	hint_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.64
	ring.outer_radius = 0.71
	ring.rings = 24
	ring.ring_segments = 6
	hint_marker.mesh = ring
	hint_marker.material_override = colours[1]
	board.add_child(hint_marker)
	hint_marker.hide()

func refresh(puzzle: RefCounted, state: Dictionary) -> void:
	if quality > 0 and not last_power.is_empty():
		for p in state.energy:
			if not last_power.has(p):
				sparks.position = world_pos(p) + Vector3.UP * 0.35
				sparks.restart()
				arc.position = world_pos(p) + Vector3.UP * 0.32
				arc_material.set_shader_parameter("tint", colours[state.energy[p]].albedo_color)
				arc_time = 0.45
				arc.show()
				break
	last_power = state.energy.duplicate()
	for p in traces:
		var channel := int(state.energy.get(p, -1))
		for arm: MeshInstance3D in traces[p]:
			arm.material_override = pulse if channel >= 0 else idle
			if channel >= 0:
				arm.set_instance_shader_parameter("channel", colours[channel].albedo_color)
				arm.set_instance_shader_parameter("step_distance", float(state.distance.get(p, 0)))
		var marker: Label3D = markers[p]
		var reactor_index: int = puzzle.reactors.find(p)
		if puzzle.sources.has(p):
			marker.text = "◆"
			marker.modulate = colours[puzzle.sources.find(p)].albedo_color
		elif puzzle.broken.has(p) or puzzle.switches.has(p):
			marker.text = "×" if puzzle.broken.has(p) else "◌"
			marker.modulate = alert.albedo_color
		elif reactor_index >= 0:
			marker.text = "✓" if reactor_index < puzzle.activated else str(reactor_index + 1)
			marker.modulate = colours[0].albedo_color
		elif puzzle.locked.has(p):
			marker.text = "▣"
		elif Validator.port_count(puzzle.masks[p]) == 1:
			marker.text = "◇"
			marker.modulate = colours[puzzle.zones[p]].albedo_color
		else:
			marker.text = ""

func show_hint(p: Vector2i) -> void:
	highlighted = true
	hint_marker.position = world_pos(p)
	hint_marker.show()

func clear_hint() -> void:
	highlighted = false
	hint_marker.hide()

func spin(p: Vector2i) -> Tween:
	var tile: Node3D = tiles[p]
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "rotation:y", tile.rotation.y - PI / 3.0, 0.15)
	return tween

func cell_at(point: Vector2) -> Variant:
	var hit: Variant = Plane(Vector3.UP, 0.25).intersects_ray(
		camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return null
	var nearest: Variant = null
	var distance := 0.92
	for p in tiles:
		var tile_distance := world_pos(p).distance_to(Vector3(hit.x, 0, hit.z))
		if tile_distance < distance:
			distance = tile_distance
			nearest = p
	return nearest

func celebrate() -> void:
	if quality == 0:
		return
	if wave_tween:
		wave_tween.kill()
	wave.scale = Vector3.ONE
	wave_material.albedo_color.a = 0.86
	wave.show()
	wave_tween = create_tween().set_parallel()
	wave_tween.tween_property(wave, "scale", Vector3(8, 0.45, 8), 0.78)
	wave_tween.tween_property(wave_material, "albedo_color:a", 0.0, 0.78)
	wave_tween.chain().tween_callback(wave.hide)
