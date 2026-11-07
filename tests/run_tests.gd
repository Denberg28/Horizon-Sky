extends SceneTree
const Flight = preload("res://scripts/flight_model.gd")
const Radio = preload("res://scripts/radio_input.gd")
const Course = preload("res://scripts/course.gd")
const Store = preload("res://scripts/profile_store.gd")
const Main = preload("res://scripts/main.gd")
var failures = 0
var checks = 0

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _initialize():
	call_deferred("run")

func run():
	if not "--test" in OS.get_cmdline_user_args():
		push_error("Run with -- --test to isolate save data")
		quit(1)
		return
	var radio = Radio.new()
	check(radio.valid_mapping(radio.mapping), "default axis mapping schema")
	var m: Dictionary = radio.mapping[0]
	check(is_equal_approx(Radio.normalized(0, m), 0), "center is zero")
	check(is_equal_approx(Radio.normalized(1, m), 1) and is_equal_approx(Radio.normalized(-1, m), -1), "full range reaches endpoints")
	check(Radio.normalized(0.03, m) == 0 and Radio.normalized(0.06, m) > 0, "deadzone suppresses drift and preserves low input")
	check(is_equal_approx(Radio.normalized(0.52, m), 0.5), "linear travel after deadzone")
	check(Radio.normalized(-1, m, true) == 0 and Radio.normalized(1, m, true) == 1, "unipolar throttle range")
	m = m.duplicate()
	m.invert = true
	check(Radio.normalized(1, m) == -1 and Radio.normalized(-1, m, true) == 1, "reverse applies to centered and throttle axes")
	var bad = radio.mapping.duplicate(true)
	bad[1].axis = 0
	check(not radio.valid_mapping(bad), "duplicate channels rejected")
	bad = radio.mapping.duplicate(true)
	bad[0].min = -0.01
	check(not radio.valid_mapping(bad), "insufficient calibration travel rejected")
	bad[0].min = "bad"
	check(not radio.valid_mapping(bad), "malformed saved mapping rejected")
	radio.select_radio(99)
	radio.calibrated = true
	check(not radio.ready_to_fly() and radio.read(0.01) == Vector4.ZERO, "device loss freezes authority with no keyboard fallback")
	var model = Flight.new()
	model.reset(0)
	for n in range(120):
		model.step(Vector4(0, 0, 0, 0.5), 1.0 / 120)
	check(model.position.z < 0 and absf(model.position.x) < 0.01 and is_equal_approx(model.position.y, 45), "neutral flight tracks straight and level")
	model.reset(0)
	for n in range(240):
		model.step(Vector4(0.6, 0.4, 0, 0.5), 1.0 / 120)
	check(model.position.x > 2 and model.position.y > 50 and model.roll < 0, "bank right turns right; pitch climbs")
	var before: Vector3 = model.position
	model.step(Vector4(INF, 0, 0, 0), 0.01)
	model.step(Vector4.ONE, 1.0)
	check(model.position == before, "nonfinite input and excessive timestep rejected")
	for kind in range(3):
		model.reset(kind)
		for n in range(12000):
			model.step(Vector4(sin(n * 0.01), cos(n * 0.02), sin(n * 0.03), 0.7), 1.0 / 120)
		check(model.position.is_finite() and absf(model.pitch) <= 0.65 and model.speed <= Flight.VEHICLES[kind].max_speed, "vehicle %d bounded 100-second soak" % kind)
	check(Flight.crossing_distance(Vector3(0, 45, 1), Vector3(0, 45, -1), Vector3(0, 45, 0)) == 0, "swept gate crossing detects center pass")
	check(is_equal_approx(Flight.crossing_distance(Vector3(0, 0, 2), Vector3(4, 0, -2), Vector3.ZERO), 2), "gate crossing interpolates movement")
	check(Flight.crossing_distance(Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3.ZERO) == -1, "reverse crossing does not score")
	var course = Course.new()
	root.add_child(course)
	for world in range(3):
		course.build(world)
		check(course.gates.size() == 16 and course.rings.size() == 16, "world %d has complete route" % world)
		var clear = true
		for gate in course.gates:
			clear = clear and not course.collision(gate) and gate.y - Course.ground_height(gate.x, gate.z) > 15
		check(clear and course.collision(Vector3(0, -5, 0)), "world %d gates clear obstacles; terrain contact detected" % world)
	course.queue_free()
	var store = Store.new()
	check(store._valid({"schema": 1, "controllers": {}, "records": {}}), "profile schema accepted")
	check(not store._valid({"schema": 1, "controllers": [], "records": {}}), "corrupt profile shape rejected")
	check(not store._valid({"schema": 1, "controllers": {}, "records": {"x": {"best": "bad", "attempts": 1, "last": {}}}}), "malformed nested record rejected")
	# Keep test writes isolated in the command-line user-data directory.
	check(store.record("TEST", {"score": 35.0}) and store.record("TEST", {"score": 20.0}), "profile writes and replacement succeed")
	var reload_store = Store.new()
	reload_store.load_profile()
	check(reload_store.data.records.TEST.best == 35 and reload_store.data.records.TEST.attempts == 2, "best retained; attempts increment; disk reload")
	var file = FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	reload_store.load_profile()
	check(not reload_store.warning.is_empty() and reload_store.data.records.TEST.best == 35, "damaged profile recovers valid backup")
	DirAccess.remove_absolute(store.path)
	DirAccess.remove_absolute(store.backup)
	var game = Main.new()
	root.add_child(game)
	await process_frame
	check(game.state == "MENU", "game boots to hangar")
	game.start_run()
	check(game.state == "FLYING", "keyboard launch starts training")
	game.pause_run("test")
	var paused_position: Vector3 = game.flight.position
	for n in range(20):
		game._physics_process(1.0 / 120)
	check(game.state == "PAUSED" and game.flight.position == paused_position, "pause freezes movement")
	game.focus_ok = true
	game.resume_run()
	check(game.state == "FLYING", "explicit keyboard resume succeeds")
	game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == "PAUSED", "focus loss pauses flight")
	game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.state == "PAUSED", "focus return never resumes automatically")
	game.radio.select_radio(99)
	game.resume_run()
	check(game.state == "PAUSED", "missing selected radio blocks resume")
	game.radio.keyboard = true
	game.start_run()
	game.flight.position = Vector3(0, -10, 0)
	game._physics_process(1.0 / 120)
	check(game.state == "RESULTS" and not game.last_result.completed, "terrain impact produces debrief")
	game.start_run()
	for gate in range(16):
		game.flight.position = game.course.gates[gate] + Vector3(0, 0, 0.1)
		game.flight.velocity = Vector3(0, 0, -35)
		game.flight.heading = 0
		game.flight.pitch = 0
		game._physics_process(1.0 / 120)
	check(game.state == "RESULTS" and game.hits == 16 and game.last_result.completed, "complete route scores 16 gates and writes debrief")
	game.show_calibration()
	check(game.calibration_open, "controller lab opens")
	game.show_menu()
	check(game.state == "MENU", "debrief and calibration return to hangar")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(store.path)
	DirAccess.remove_absolute(store.backup)
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
