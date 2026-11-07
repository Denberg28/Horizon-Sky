extends RefCounted
const TEST_MODE = "--test"
var path = "user://pilot.json"
var backup = "user://pilot.backup.json"

func _init():
	if TEST_MODE in OS.get_cmdline_user_args():
		path = "user://test-pilot.json"
		backup = "user://test-pilot.backup.json"
var data: Dictionary = {"schema": 1, "controllers": {}, "records": {}}
var warning = ""

func load_profile():
	if not FileAccess.file_exists(path):
		return
	var loaded = _read(path)
	if not _valid(loaded):
		loaded = _read(backup)
		warning = "Profile was damaged. Backup loaded." if _valid(loaded) else "Profile unreadable. Using defaults; damaged file retained."
	if _valid(loaded):
		data = loaded

func _read(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return null
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func _valid(value) -> bool:
	if not (value is Dictionary and value.get("schema") == 1 and value.get("controllers") is Dictionary and value.get("records") is Dictionary):
		return false
	for key in value.records:
		var entry = value.records[key]
		if not entry is Dictionary or not entry.get("last") is Dictionary:
			return false
		for field in ["best", "attempts"]:
			if not (entry.get(field) is int or entry.get(field) is float) or not is_finite(entry[field]):
				return false
		if entry.best < 0 or entry.best > 100 or entry.attempts < 1 or entry.attempts > 10000000:
			return false
	return true

func save_profile() -> bool:
	var temp = path + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		warning = "Could not save profile. Session remains usable."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if not _valid(_read(temp)):
		warning = "Save verification failed. Previous profile retained."
		return false
	if _valid(_read(path)):
		DirAccess.copy_absolute(path, backup)
	var error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		warning = "Could not replace profile. Previous profile retained."
		return false
	warning = ""
	return true

func record(key: String, result: Dictionary):
	var previous = data.records.get(key, {})
	var attempts = int(previous.get("attempts", 0)) + 1
	var best = maxf(float(previous.get("best", 0)), float(result.get("score", 0)))
	data.records[key] = {"attempts": attempts, "best": best, "last": result}
	return save_profile()
