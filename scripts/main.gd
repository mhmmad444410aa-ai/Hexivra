extends Node3D

const Puzzle = preload("res://scripts/puzzle.gd")
const BoardView = preload("res://scripts/board_view.gd")
const Profile = preload("res://scripts/profile.gd")
const Strings = preload("res://scripts/strings.gd")
const BUTTONS = [
	preload("res://assets/ui/btn_large.png"),
	preload("res://assets/ui/btn_large_hover.png"),
	preload("res://assets/ui/btn_large_click.png"),
]
const LEVEL_STYLES = [
	preload("res://assets/ui/level-open.png"),
	preload("res://assets/ui/level-hover.png"),
	preload("res://assets/ui/level-locked.png"),
]
const PRIVACY_URL := "https://raw.githubusercontent.com/mhmmad444410aa-ai/Hexivra/34974c64257a812bd4710bcbe6e2e29fe155025b/docs/PRIVACY.md"
const MODE_COLOURS = ["#7af2ff", "#ae9cff", "#ffcc82", "#fa87b9", "#9be5ae", "#ff9f85", "#79adf9", "#7debe0"]
const LANGUAGES = ["English (UK)", "العربية", "Português (Brasil)"]
const ACCENT := Color("#76f4ff")
const INK := Color("#dcf1ff")

var puzzle := Puzzle.new()
var view := BoardView.new()
var profile := Profile.new()
var overlay := Control.new()
var ui: VBoxContainer
var screen := ""
var mode := 0
var level := 1
var date := ""
var moves := 0
var elapsed := 0.0
var moving := false
var hint_count := 0
var move_label: Label
var energy_label: Label
var task_label: Label
var hint_label: Label
var progress_bar: ProgressBar
var sound := AudioStreamPlayer.new()
var last_save_second := -1
var audio: Dictionary = {}

func _ready() -> void:
	profile.load_profile()
	profile.data.locale = clampi(profile.data.locale, 0, 2)
	profile.data.quality = clampi(profile.data.quality, 0, 2)
	add_child(view)
	view.set_quality(profile.data.quality)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sound)
	sound.volume_db = -14
	for event in ["button", "rotate", "repair", "activate", "success"]:
		var path := "res://assets/audio/%s.ogg" % event
		if ResourceLoader.exists(path):
			audio[event] = load(path)
	show_home()

func tr_key(key: String) -> String:
	return Strings.TEXT[key][profile.data.locale]

func mode_title(index: int) -> String:
	return Strings.MODES[index][profile.data.locale]

func today() -> String:
	return Time.get_date_string_from_system()

func play_sound(event: String) -> void:
	if profile.data.sound and audio.has(event):
		sound.stop()
		sound.stream = audio[event]
		sound.play()

func label(parent: Control, value: String, size: int, colour := INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Control, value: String, callback: Callable, minimum := 67) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = minimum
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 27)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", ACCENT)
	for i in range(3):
		var style := StyleBoxTexture.new()
		style.texture = BUTTONS[i]
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 7)
		style.modulate_color = Color("#bbcfff") if i == 0 else Color("#7defff")
		node.add_theme_stylebox_override(["normal", "hover", "pressed"][i], style)
	node.pressed.connect(func(): play_sound("button"); callback.call())
	node.button_down.connect(func():
		node.pivot_offset = node.size * 0.5
		node.create_tween().tween_property(node, "scale", Vector2.ONE * 0.975, 0.08))
	node.button_up.connect(func():
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.11))
	parent.add_child(node)
	return node

func spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)

func page(name: String, title: String, gameplay := false) -> void:
	screen = name
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL if profile.data.locale == 1 else Control.LAYOUT_DIRECTION_LTR
	if not gameplay and name != "home":
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.025, 0.041, 0.075, 0.93)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(backdrop)
	ui = VBoxContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.offset_left = 36
	ui.offset_right = -36
	ui.offset_top = 42
	ui.offset_bottom = -44
	ui.add_theme_constant_override("separation", 13)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ui)
	var heading := label(ui, title, 73 if name == "home" else (52 if not gameplay else 38), ACCENT)
	heading.add_theme_constant_override("outline_size", 4)
	heading.add_theme_color_override("font_outline_color", Color("#071221"))

func scroll_content() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content

func show_home() -> void:
	view.preview()
	page("home", "HEXIVRA")
	label(ui, tr_key("subtitle"), 24)
	spacer(ui)
	if not profile.data.active.is_empty():
		button(ui, tr_key("continue"), resume_saved)
	button(ui, tr_key("play"), func(): show_levels(0))
	button(ui, tr_key("modes"), show_modes)
	button(ui, tr_key("achievements"), show_achievements)
	button(ui, tr_key("settings"), show_settings)
	label(ui, tr_key("crystals") % profile.data.crystals, 22, ACCENT)

func show_modes() -> void:
	page("modes", tr_key("modes"))
	var list := scroll_content()
	for index in range(8):
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#102139")
		style.border_color = Color(MODE_COLOURS[index])
		style.border_width_left = 4
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 11
		panel.add_theme_stylebox_override("panel", style)
		list.add_child(panel)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		panel.add_child(card)
		var entry := button(card, mode_title(index), func(): show_levels(index), 48)
		entry.add_theme_color_override("font_color", style.border_color)
		label(card, Strings.RULES[index][profile.data.locale], 20)
	button(ui, tr_key("back"), show_home)

func show_levels(index: int) -> void:
	mode = index
	if mode == 7:
		start_level(1)
		return
	if mode == 6:
		start_level(int(profile.data.progress.get(str(mode), 1)))
		return
	page("levels", mode_title(index))
	label(ui, tr_key("levels"), 25)
	label(ui, Strings.RULES[mode][profile.data.locale], 22)
	var list := scroll_content()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	var unlocked := int(profile.data.progress.get(str(mode), 1))
	for i in range(1, Puzzle.COUNTS[mode] + 1):
		var stars := int(profile.data.stars.get("%d:%d" % [mode, i], 0))
		var caption := "%02d\n%s" % [i, "★".repeat(stars) if i <= unlocked else "▣"]
		var entry := button(grid, caption, func(): start_level(i), 92)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxTexture.new()
			style.texture = LEVEL_STYLES[2 if state == "disabled" else int(state != "normal")]
			entry.add_theme_stylebox_override(state, style)
		entry.disabled = i > unlocked
	button(ui, tr_key("back"), show_modes)

func show_settings() -> void:
	page("settings", tr_key("settings"))
	var list := scroll_content()
	label(list, tr_key("language"), 24, ACCENT)
	for i in range(3):
		button(list, ("✓  " if i == profile.data.locale else "") + LANGUAGES[i], func():
			profile.data.locale = i
			profile.store()
			show_settings(), 56)
	label(list, tr_key("quality"), 24, ACCENT)
	var quality_row := HBoxContainer.new()
	list.add_child(quality_row)
	for i in range(3):
		var key: String = ["low", "medium", "high"][i]
		button(quality_row, ("✓  " if i == profile.data.quality else "") + tr_key(key), func():
			profile.data.quality = i
			view.set_quality(i)
			profile.store()
			show_settings(), 56)
	for key in ["sound", "vibration"]:
		var toggle := CheckButton.new()
		toggle.text = tr_key(key)
		toggle.button_pressed = profile.data[key]
		toggle.custom_minimum_size.y = 57
		toggle.add_theme_font_size_override("font_size", 26)
		toggle.toggled.connect(func(enabled): profile.data[key] = enabled; profile.store())
		list.add_child(toggle)
	button(list, tr_key("privacy"), func(): OS.shell_open(PRIVACY_URL), 58)
	label(list, tr_key("privacy_detail"), 20)
	label(list, "Hexivra 2.0.0", 20)
	button(list, "Sci-Fi Laboratory · vinish.dev · CC BY 4.0", func():
		OS.shell_open("https://vinish.dev/free-3d-models/sci-fi-laboratory"), 56)
	button(ui, tr_key("back"), show_home)

func show_achievements() -> void:
	page("achievements", tr_key("achievements"))
	label(ui, tr_key("wins") % profile.data.wins, 29)
	label(ui, tr_key("xp") % [profile.data.xp, 1 + int(profile.data.xp / 150)], 26)
	label(ui, tr_key("crystals") % profile.data.crystals, 26)
	var progress := int(profile.data.mission.get("wins", 0)) if profile.data.mission.get("day") == today() else 0
	label(ui, tr_key("mission") % mini(progress, 3), 24)
	for i in range(2):
		var earned: bool = profile.data.wins >= [1, 10][i]
		label(ui, ("★  " if earned else "▣  ") + tr_key(["badge", "badge_10"][i]), 27, ACCENT if earned else INK)
	spacer(ui)
	for i in range(2):
		var key: String = ["standard", "skin"][i]
		var node := button(ui, ("✓  " if profile.data.skin == i else "") + tr_key(key), func():
			profile.data.skin = i
			profile.store()
			show_achievements())
		node.disabled = i == 1 and profile.data.wins < 10
	button(ui, tr_key("back"), show_home)

func start_level(index: int, saved := {}) -> void:
	level = index
	date = str(saved.get("date", today()))
	moves = 0
	elapsed = 0.0
	hint_count = 0
	last_save_second = -1
	moving = false
	puzzle.generate_level(mode, level, date)
	if puzzle.cells.is_empty():
		page("invalid", tr_key("invalid"))
		button(ui, tr_key("back"), show_home)
		return
	if not saved.is_empty() and saved.get("masks", {}).size() == puzzle.cells.size():
		var valid := true
		for p in puzzle.cells:
			if not saved.masks.has(p):
				valid = false
				break
			var mask := int(saved.masks[p])
			if not range(6).any(func(step): return Puzzle.rotate_mask(puzzle.solved[p], step) == mask):
				valid = false
				break
		if valid:
			puzzle.masks = saved.masks.duplicate()
			puzzle.broken = saved.get("broken", puzzle.broken).duplicate()
			puzzle.switches = saved.get("switches", puzzle.switches).duplicate()
			puzzle.repairs = int(saved.get("repairs", puzzle.repairs))
			puzzle.activated = int(saved.get("activated", 0))
			moves = int(saved.get("moves", 0))
			hint_count = int(saved.get("hint_count", 0))
			elapsed = float(saved.get("elapsed", 0.0))
	view.build(puzzle, profile.data.skin)
	show_game()
	if puzzle.is_solved():
		finish()
	else:
		save_active()

func resume_saved() -> void:
	var saved: Dictionary = profile.data.active
	mode = clampi(int(saved.get("mode", 0)), 0, 7)
	start_level(maxi(int(saved.get("level", 1)), 1), saved)

func save_active() -> void:
	profile.data.active = {
		"mode": mode, "level": level, "date": date,
		"masks": puzzle.masks.duplicate(), "broken": puzzle.broken.duplicate(),
		"switches": puzzle.switches.duplicate(), "repairs": puzzle.repairs,
		"activated": puzzle.activated, "moves": moves, "elapsed": elapsed,
		"hint_count": hint_count,
	}
	profile.store()

func show_game() -> void:
	page("game", mode_title(mode) + ("  /  " + str(level) if mode != 7 else ""), true)
	label(ui, Strings.RULES[mode][profile.data.locale], 23)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 38)
	ui.add_child(stats)
	move_label = label(stats, "", 24)
	energy_label = label(stats, "", 24, ACCENT)
	move_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	energy_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 12
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	progress_bar.add_theme_stylebox_override("fill", fill)
	ui.add_child(progress_bar)
	task_label = label(ui, "", 24)
	spacer(ui)
	hint_label = label(ui, "", 25, ACCENT)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	ui.add_child(actions)
	button(actions, tr_key("hint"), show_hint)
	button(actions, tr_key("pause"), pause_game)
	refresh()

func refresh() -> void:
	var state := puzzle.state()
	view.refresh(puzzle, state)
	move_label.text = tr_key("moves") % moves
	energy_label.text = tr_key("energy") % [state.energy.size(), puzzle.cells.size()]
	progress_bar.max_value = puzzle.cells.size()
	progress_bar.value = state.energy.size()
	if mode == 2:
		task_label.text = tr_key("reactors") % [puzzle.activated, puzzle.reactors.size()]
	elif mode == 5:
		task_label.text = tr_key("repairs") % puzzle.repairs

func show_hint() -> void:
	if moving:
		return
	var hint := puzzle.hint()
	if hint.is_empty():
		return
	hint_count += 1
	view.show_hint(hint.cell)
	hint_label.text = tr_key(hint.action) % hint.steps if hint.action == "rotate" else tr_key(hint.action)
	save_active()

func pause_game() -> void:
	if moving:
		return
	save_active()
	page("pause", tr_key("pause"))
	spacer(ui)
	button(ui, tr_key("continue"), show_game)
	button(ui, tr_key("retry"), func(): start_level(level))
	button(ui, tr_key("back"), show_home)

func _process(delta: float) -> void:
	if screen == "game" and mode == 4 and not moving:
		elapsed += delta
		var remaining := maxi(0, ceili(puzzle.time_limit - elapsed))
		task_label.text = tr_key("timer") % remaining
		if remaining != last_save_second and remaining % 5 == 0:
			last_save_second = remaining
			save_active()
		if remaining == 0:
			page("timeout", tr_key("timeout"))
			spacer(ui)
			button(ui, tr_key("retry"), func(): start_level(level))
			button(ui, tr_key("back"), show_home)

func finish() -> void:
	var rating := 3 if moves <= puzzle.par and hint_count == 0 else (2 if moves <= puzzle.par * 2 else 1)
	var key := "%d:%s" % [mode, date if mode == 7 else str(level)]
	var gain := profile.reward(key, mode, level, rating, today(), Puzzle.COUNTS[mode])
	play_sound("success")
	view.celebrate()
	if profile.data.vibration:
		Input.vibrate_handheld(65)
	page("victory", tr_key("victory"), true)
	label(ui, "★".repeat(rating) + "☆".repeat(3 - rating), 63, Color("#ffd782"))
	label(ui, tr_key("gain") % gain, 27)
	label(ui, tr_key("moves") % moves, 24)
	spacer(ui)
	if mode == 6 or (mode < 6 and level < Puzzle.COUNTS[mode]):
		button(ui, tr_key("next"), func(): start_level(level + 1))
	button(ui, tr_key("retry"), func(): start_level(level))
	button(ui, tr_key("back"), show_home)

func interact(p: Vector2i) -> void:
	if screen != "game" or moving:
		return
	var action := puzzle.act(p)
	if action.is_empty():
		return
	moves += 1
	view.clear_hint()
	hint_label.text = ""
	play_sound(action if action != "switch" else "repair")
	if profile.data.vibration:
		Input.vibrate_handheld(24)
	if action == "rotate":
		moving = true
		await view.spin(p).finished
		moving = false
	refresh()
	if puzzle.is_solved():
		finish()
	else:
		save_active()

func _unhandled_input(event: InputEvent) -> void:
	if screen != "game" or moving:
		return
	var point: Vector2
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		point = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	else:
		return
	var cell: Variant = view.cell_at(point)
	if cell != null:
		interact(cell)
