extends SceneTree

const MAIN = preload("res://Main.tscn")
var game: Node3D

class TestAds extends RefCounted:
	var loaded := false
	var banner_visible := false

	func showBanner(visible: bool) -> void:
		banner_visible = visible

	func bannerHeightPx() -> int:
		return 0

	func betweenLevels() -> bool:
		return loaded

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func run() -> void:
	game = MAIN.instantiate()
	root.add_child(game)
	game.profile.data.vibration = false
	game.profile.data.sound = false
	if not require(game.audio.size() == 5, "Audio event resources did not load"):
		return
	if not require(game.screen == "home", "Main menu did not load"):
		return
	game.show_modes()
	if not require(game.screen == "modes", "Mode selection did not open"):
		return
	game.show_levels(0)
	if not require(game.screen == "levels", "Level selection did not open"):
		return
	game.start_level(1)
	var hint: Dictionary = game.puzzle.hint()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.view.camera.unproject_position(game.view.world_pos(hint.cell) + Vector3.UP * 0.25)
	game._unhandled_input(touch)
	var deadline := Time.get_ticks_msec() + 3000
	while game.moving and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(not game.moving, "Tile rotation tween did not finish"):
		return
	if not require(game.moves == 1, "Projected touch did not rotate one tile"):
		return
	game.pause_game()
	if not require(game.screen == "pause", "Pause did not open"):
		return
	var saved: Dictionary = game.profile.data.active.duplicate(true)
	var loaded = game.Profile.new()
	loaded.load_profile()
	if not require(loaded.data.active == saved, "Progress was not persisted"):
		return
	game.show_home()
	game.resume_saved()
	if not require(game.moves == 1 and game.puzzle.masks == saved.masks, "Continue did not restore the board"):
		return
	for i in range(3):
		game.profile.data.locale = i
		game.show_settings()
		if not require(game.overlay.is_layout_rtl() == (i == 1), "Wrong RTL layout for locale"):
			return
		if not require(game.ui.get_child(0).text == game.tr_key("settings"), "Wrong settings translation"):
			return
	game.show_achievements()
	if not require(game.screen == "achievements", "Achievements did not open"):
		return
	for mode in range(8):
		game.mode = mode
		game.start_level(1)
		game.show_hint()
		if not require(game.screen == "game" and game.view.highlighted, "Mode or hint did not load"):
			return
		while not game.puzzle.is_solved():
			hint = game.puzzle.hint()
			for step in range(hint.steps):
				game.puzzle.act(hint.cell, hint.action)
		var prior: int = game.profile.data.wins
		game.finish()
		if not require(game.screen == "victory" and game.profile.data.wins == prior + 1, "Victory grant failed"):
			return
		var funds: int = game.profile.data.crystals
		game.finish()
		if not require(game.profile.data.crystals == funds, "Victory paid twice"):
			return
	game.mode = 4
	game.start_level(1)
	game.elapsed = game.puzzle.time_limit
	game._process(0.0)
	if not require(game.screen == "timeout", "Timer did not expire"):
		return
	var test_ads := TestAds.new()
	game.ads = test_ads
	game.profile.data.wins = 9
	game.mode = 0
	game.level = 1
	game.screen = "victory"
	game.continue_to_next()
	if not require(game.screen == "game" and game.level == 2 and test_ads.banner_visible,
			"An unavailable ad interrupted the next level"):
		return
	test_ads.loaded = true
	game.screen = "victory"
	game.continue_to_next()
	if not require(game.screen == "transition" and game.level == 2 and not test_ads.banner_visible,
			"The ad did not stay between levels"):
		return
	game.finish_ad_transition()
	if not require(game.screen == "game" and game.level == 3, "Ad dismissal did not resume play"):
		return
	print("Screens, 8 mode entry points, synthetic touch, pause, persistence, translations, RTL, rewards, timeout and ad transition fallback passed")
	game.queue_free()
	await process_frame
	quit(0)
