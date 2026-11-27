extends SceneTree

const Puzzle = preload("res://scripts/puzzle.gd")
var signatures := {}
var tested := 0

func _initialize() -> void:
	for mode in range(6):
		for level in range(1, Puzzle.COUNTS[mode] + 1):
			if not verify(mode, level, "", true):
				quit(1)
				return
	for mode in range(8):
		for i in range(125):
			var date := Time.get_date_string_from_unix_time(1767225600 + i * 86400)
			if not verify(mode, 301 + i, date):
				quit(1)
				return
	print("%d puzzles verified (400 campaign + 1000 additional)" % tested)
	quit(0)

func verify(mode: int, level: int, date: String, campaign := false) -> bool:
	var puzzle := Puzzle.new()
	puzzle.generate_level(mode, level, date)
	var duplicate := Puzzle.new()
	duplicate.generate_level(mode, level, date)
	if puzzle.cells.is_empty() or puzzle.is_solved() or duplicate.masks != puzzle.masks:
		return fail(mode, level, "invalid or nondeterministic starting board")
	var signature := var_to_str([mode, puzzle.masks, puzzle.broken, puzzle.switches, puzzle.locked])
	if campaign and signatures.has(signature):
		return fail(mode, level, "duplicate starting board")
	signatures[signature] = true
	var moves := 0
	while not puzzle.is_solved() and moves <= puzzle.par:
		var hint := puzzle.hint()
		if hint.is_empty():
			break
		for i in range(hint.steps):
			if puzzle.act(hint.cell, hint.action) != hint.action:
				return fail(mode, level, "invalid hint")
			moves += 1
	if not puzzle.is_solved() or moves > puzzle.par:
		return fail(mode, level, "hint chain did not solve within par")
	if mode == 4 and puzzle.time_limit < 30 + 3 * moves:
		return fail(mode, level, "timer below minimum budget")
	tested += 1
	return true

func fail(mode: int, level: int, reason: String) -> bool:
	push_error("Mode %d, level %d: %s" % [mode, level, reason])
	return false
