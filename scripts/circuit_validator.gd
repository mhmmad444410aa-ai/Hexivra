extends RefCounted

const DIRS = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]

static func inspect(masks: Dictionary, sources: Array[Vector2i], broken: Dictionary,
		open_switches: Dictionary, laser_inputs: Dictionary) -> Dictionary:
	var energy := {}
	var distances := {}
	var leaks := 0
	var collision := false
	for p: Vector2i in masks:
		for d in range(6):
			if int(masks[p]) & (1 << d):
				var n: Vector2i = p + DIRS[d]
				if not (int(masks.get(n, 0)) & (1 << ((d + 3) % 6))):
					leaks += 1
	for channel in range(sources.size()):
		var source := sources[channel]
		var queue: Array[Vector2i] = [source]
		var seen := {source: 0}
		var index := 0
		while index < queue.size():
			var p := queue[index]
			index += 1
			if broken.has(p) or open_switches.has(p):
				continue
			if energy.has(p) and energy[p] != channel:
				collision = true
			else:
				energy[p] = channel
				distances[p] = seen[p]
			for d in range(6):
				var n: Vector2i = p + DIRS[d]
				if seen.has(n) or not (int(masks[p]) & (1 << d)):
					continue
				if not (int(masks.get(n, 0)) & (1 << ((d + 3) % 6))):
					continue
				if not laser_inputs.is_empty():
					var entrance := int(laser_inputs.get(n, -1))
					if entrance != -2 and entrance != (d + 3) % 6:
						continue
				seen[n] = int(seen[p]) + 1
				queue.append(n)
	return {"energy": energy, "distance": distances, "leaks": leaks, "collision": collision}

static func port_count(mask: int) -> int:
	var total := 0
	for d in range(6):
		total += (mask >> d) & 1
	return total

static func complete(state: Dictionary, zones: Dictionary) -> bool:
	if state.collision or state.leaks or state.energy.size() != zones.size():
		return false
	for p in zones:
		if state.energy.get(p, -1) != zones[p]:
			return false
	return true
