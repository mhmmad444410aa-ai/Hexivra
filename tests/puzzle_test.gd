extends SceneTree
const Puzzle = preload("res://scripts/puzzle.gd")
func _initialize() -> void:
	var p = Puzzle.new()
	for radius in [2,3,4]:
		for seed_value in range(1,151):
			p.generate(radius,seed_value)
			if p.is_solved():
				push_error("Generated puzzle already solved")
				quit(1)
				return
			for cell in p.cells:
				var valid = false
				for step in range(6):
					if p.rotate_mask(p.masks[cell],step) == p.solved[cell]:
						valid = true
				if not valid:
					push_error("Unreachable solution")
					quit(1)
					return
			p.masks = p.solved.duplicate()
			if not p.is_solved():
				push_error("Invalid solution")
				quit(1)
				return
	print("450 generated puzzles verified")
	quit(0)
