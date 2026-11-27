extends RefCounted
# Axial hex grid. Each mask contains six directional ports.
const DIRS = [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
var cells: Array[Vector2i] = []
var masks: Dictionary = {}
var solved: Dictionary = {}
var source := Vector2i.ZERO

func rotate_mask(mask: int, steps: int = 1) -> int:
	for i in range(posmod(steps,6)):
		mask = ((mask << 1) | (mask >> 5)) & 63
	return mask

func generate(radius: int, seed_value: int) -> void:
	cells.clear()
	masks.clear()
	solved.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for q in range(-radius,radius+1):
		for r in range(-radius,radius+1):
			if abs(q+r) <= radius:
				var p := Vector2i(q,r)
				cells.append(p)
				solved[p] = 0
	var visited := {source:true}
	var stack: Array[Vector2i] = [source]
	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var choices: Array[int] = []
		for d in range(6):
			var n: Vector2i = p + DIRS[d]
			if solved.has(n) and not visited.has(n):
				choices.append(d)
		if choices.is_empty():
			stack.pop_back()
			continue
		var d: int = choices[rng.randi_range(0,choices.size()-1)]
		var n: Vector2i = p + DIRS[d]
		solved[p] = int(solved[p]) | (1 << d)
		solved[n] = int(solved[n]) | (1 << ((d+3)%6))
		visited[n] = true
		stack.append(n)
	for p in cells:
		masks[p] = rotate_mask(solved[p],rng.randi_range(0,5))
	if is_solved():
		for p in cells:
			if rotate_mask(masks[p]) != masks[p]:
				masks[p] = rotate_mask(masks[p])
				break

func powered() -> Dictionary:
	var seen := {source:true}
	var queue: Array[Vector2i] = [source]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in range(6):
			var n: Vector2i = p + DIRS[d]
			if (int(masks[p]) & (1<<d)) != 0 and masks.has(n) and (int(masks[n]) & (1<<((d+3)%6))) != 0 and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen

func is_solved() -> bool:
	if masks.is_empty() or powered().size() != cells.size():
		return false
	for p in cells:
		for d in range(6):
			if (int(masks[p]) & (1<<d)) != 0:
				var n: Vector2i = p + DIRS[d]
				if not masks.has(n) or (int(masks[n]) & (1<<((d+3)%6))) == 0:
					return false
	return true
