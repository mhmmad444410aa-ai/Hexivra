extends RefCounted

const Validator = preload("res://scripts/circuit_validator.gd")
const DIRS = Validator.DIRS
const COUNTS = [100, 80, 60, 60, 50, 50, 0, 0]

var cells: Array[Vector2i] = []
var sources: Array[Vector2i] = []
var reactors: Array[Vector2i] = []
var masks := {}
var solved := {}
var zones := {}
var broken := {}
var switches := {}
var locked := {}
var laser_inputs := {}
var activated := 0
var repairs := 0
var mode := 0
var par := 0
var time_limit := 0

static func rotate_mask(mask: int, steps: int = 1) -> int:
	for i in range(posmod(steps, 6)):
		mask = ((mask << 1) | (mask >> 5)) & 63
	return mask

static func campaign_seed(game_mode: int, level: int, date: String = "") -> int:
	if game_mode == 7:
		return int(date.replace("-", "")) * 127 + 71
	return level * 7187 + game_mode * 99991

func generate_level(game_mode: int, level: int, date: String = "") -> void:
	var tier := clampi((level - 1) / 12, 0, 2)
	var radius := 1 + tier
	if game_mode == 6 and level >= 70:
		radius = 4
	if game_mode == 7:
		radius = 2
	if game_mode == 1 or game_mode == 2 or game_mode == 3:
		radius = maxi(radius, 2)
	for attempt in range(64):
		generate(radius, campaign_seed(game_mode, level, date) + attempt * 43019, game_mode)
		if not is_solved() and Validator.complete(
			Validator.inspect(solved, sources, {}, {}, laser_inputs), zones
		) and (mode != 2 or reactors.size() >= 2):
			return
	# A failed validation is surfaced to the caller rather than displaying a broken board.
	cells.clear()

func generate(radius: int, seed_value: int, game_mode: int = 0) -> void:
	mode = game_mode
	cells.clear()
	sources.clear()
	reactors.clear()
	for dictionary in [masks, solved, zones, broken, switches, locked, laser_inputs]:
		dictionary.clear()
	activated = 0
	repairs = 0
	par = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) <= radius:
				var p := Vector2i(q, r)
				cells.append(p)
				zones[p] = int(q >= 0) if mode == 1 else 0
				solved[p] = 0
	if mode == 1:
		sources.append(Vector2i(-1, 0))
	sources.append(Vector2i.ZERO)
	for channel in range(sources.size()):
		_grow(sources[channel], channel, rng)
		if mode == 3:
			# Degree-constrained growth may trap an unvisited cell. Reject this seed.
			for p in cells:
				if solved[p] == 0:
					return
	var feature_cells: Array[Vector2i] = []
	for p in cells:
		if not sources.has(p):
			feature_cells.append(p)
	for i in range(feature_cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var cell := feature_cells[i]
		feature_cells[i] = feature_cells[j]
		feature_cells[j] = cell
	if mode == 2:
		for p in feature_cells:
			if Validator.port_count(solved[p]) == 1:
				reactors.append(p)
				if reactors.size() == 3:
					break
		var state := Validator.inspect(solved, sources, {}, {}, {})
		reactors.sort_custom(func(a, b): return state.distance[a] < state.distance[b])
	if mode == 5:
		repairs = clampi(radius, 1, 3)
		for i in range(repairs):
			broken[feature_cells[i]] = true
		switches[feature_cells[repairs]] = true
	if radius >= 2:
		for p in feature_cells:
			if not broken.has(p) and not switches.has(p) and not reactors.has(p):
				locked[p] = true
				break
	for p in cells:
		var step := 0 if locked.has(p) else rng.randi_range(0, 5)
		masks[p] = rotate_mask(solved[p], step)
		var score := _rotations_to_solution(p)
		par += score
	if par == 0:
		for p in cells:
			if not locked.has(p) and rotate_mask(solved[p]) != solved[p]:
				masks[p] = rotate_mask(solved[p])
				par = _rotations_to_solution(p)
				break
	par += broken.size() + switches.size() + reactors.size()
	time_limit = 30 + par * 4

func _grow(source: Vector2i, channel: int, rng: RandomNumberGenerator) -> void:
	var visited := {source: true}
	var stack: Array[Vector2i] = [source]
	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var choices: Array[int] = []
		for d in range(6):
			var n: Vector2i = p + DIRS[d]
			if zones.get(n, -1) != channel or visited.has(n):
				continue
			var ports := int(solved[p]) | (1 << d)
			if mode == 3 and ports in [21, 42]:
				continue
			choices.append(d)
		if choices.is_empty() or (mode == 3 and Validator.port_count(solved[p]) >= 3):
			stack.pop_back()
			continue
		var d := choices[rng.randi_range(0, choices.size() - 1)]
		var n: Vector2i = p + DIRS[d]
		solved[p] = int(solved[p]) | (1 << d)
		solved[n] = 1 << ((d + 3) % 6)
		if mode == 3:
			laser_inputs[n] = (d + 3) % 6
		visited[n] = true
		stack.append(n)
	if mode != 3:
		# Additional reciprocal edges introduce closed loops and four-way junctions.
		for p: Vector2i in visited:
			for d in range(3):
				var n: Vector2i = p + DIRS[d]
				if visited.has(n) and rng.randf() < 0.18:
					solved[p] = int(solved[p]) | (1 << d)
					solved[n] = int(solved[n]) | (1 << ((d + 3) % 6))

func laser_input(p: Vector2i) -> int:
	if not laser_inputs.has(p):
		return -1
	return posmod(int(laser_inputs[p]) - _rotations_to_solution(p), 6)

func state() -> Dictionary:
	var inputs := {}
	for p in laser_inputs:
		var input := laser_input(p)
		var mask: int = masks[p]
		inputs[p] = -2 if mask in [9, 18, 36] else input
	return Validator.inspect(masks, sources, broken, switches, inputs)

func is_solved() -> bool:
	return not masks.is_empty() and activated == reactors.size() and Validator.complete(state(), zones)

func _rotations_to_solution(p: Vector2i) -> int:
	for step in range(6):
		if rotate_mask(masks[p], step) == solved[p]:
			return step
	return -1

func hint() -> Dictionary:
	for p in broken:
		return {"cell": p, "action": "repair", "steps": 1}
	for p in switches:
		return {"cell": p, "action": "switch", "steps": 1}
	for p in cells:
		var steps := _rotations_to_solution(p)
		if steps > 0:
			return {"cell": p, "action": "rotate", "steps": steps}
	if activated < reactors.size():
		return {"cell": reactors[activated], "action": "activate", "steps": 1}
	return {}

func act(p: Vector2i, action: String = "") -> String:
	if not masks.has(p) or locked.has(p):
		return ""
	if broken.has(p):
		if repairs < 1 or action not in ["", "repair"]:
			return ""
		repairs -= 1
		broken.erase(p)
		return "repair"
	if switches.has(p):
		if action not in ["", "switch"]:
			return ""
		switches.erase(p)
		return "switch"
	if p in reactors and action in ["", "activate"]:
		if Validator.complete(state(), zones):
			if activated < reactors.size() and reactors[activated] == p:
				activated += 1
				return "activate"
			return ""
		if action == "activate":
			return ""
	if action not in ["", "rotate"] or rotate_mask(masks[p]) == masks[p]:
		return ""
	masks[p] = rotate_mask(masks[p])
	activated = 0
	return "rotate"
