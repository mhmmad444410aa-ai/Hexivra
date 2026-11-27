extends RefCounted

const FILE := "user://progress.cfg"
const BACKUP := "user://progress.backup.cfg"
const TEMP := "user://progress.next.cfg"

var data := {
	"progress": {}, "stars": {}, "crystals": 0, "xp": 0, "wins": 0,
	"locale": 0, "quality": 1, "sound": true, "vibration": true,
	"skin": 0, "mission": {}, "active": {}, "petal_consent": false,
}

func load_profile() -> void:
	for path in [FILE, BACKUP]:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK or not cfg.has_section("game"):
			continue
		for key in data:
			var value: Variant = cfg.get_value("game", key, data[key])
			if typeof(value) == typeof(data[key]):
				data[key] = value
		return

func store() -> void:
	var cfg := ConfigFile.new()
	for key in data:
		cfg.set_value("game", key, data[key])
	if cfg.save(TEMP) != OK:
		push_warning("Could not write Hexivra progress")
		return
	var current := ProjectSettings.globalize_path(FILE)
	var backup := ProjectSettings.globalize_path(BACKUP)
	var previous := ConfigFile.new()
	if previous.load(FILE) == OK:
		DirAccess.copy_absolute(current, backup)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP), current) != OK:
		push_warning("Could not replace Hexivra progress")

func reward(key: String, mode: int, level: int, rating: int, date: String, cap: int) -> int:
	var previous := int(data.stars.get(key, 0))
	var gain := maxi(rating - previous, 0)
	if previous == 0:
		data.wins += 1
		data.xp += 30
		if data.mission.get("day") != date:
			data.mission = {"day": date, "wins": 0}
		data.mission.wins += 1
		if data.mission.wins == 3:
			gain += 5
	data.stars[key] = maxi(rating, previous)
	if mode != 7:
		var unlocked := level + 1 if cap == 0 else mini(level + 1, cap)
		data.progress[str(mode)] = maxi(int(data.progress.get(str(mode), 1)), unlocked)
	data.crystals += gain
	data.active = {}
	store()
	return gain
