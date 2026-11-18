extends SceneTree
const Flight = preload("res://scripts/flight_model.gd")
const Radio = preload("res://scripts/radio_input.gd")
const Course = preload("res://scripts/course.gd")
const Store = preload("res://scripts/profile_store.gd")
const Main = preload("res://scripts/main.gd")
const Touch = preload("res://scripts/touch_controls.gd")
const FlightAudio = preload("res://scripts/flight_audio.gd")
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

func send_key(code: int, pressed: bool):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run():
	if not "--test" in OS.get_cmdline_user_args():
		push_error("Run with -- --test to isolate save data")
		quit(1)
		return
	var radio = Radio.new()
	var key_pairs = [[KEY_W, KEY_UP, 1, -1.0], [KEY_S, KEY_DOWN, 1, 1.0], [KEY_A, KEY_LEFT, 0, -1.0], [KEY_D, KEY_RIGHT, 0, 1.0]]
	for pair in key_pairs:
		send_key(pair[0], true)
		var wasd = radio.read(0)
		send_key(pair[0], false)
		send_key(pair[1], true)
		var arrow = radio.read(0)
		check(wasd == arrow and arrow[int(pair[2])] == pair[3], "WASD/arrow direction equivalence %s" % OS.get_keycode_string(pair[0]))
		send_key(pair[0], true)
		check(radio.read(0) == arrow, "same-direction alias does not double input %s" % OS.get_keycode_string(pair[0]))
		send_key(pair[0], false)
		send_key(pair[1], false)
	check(radio.read(0) == Vector4(0, 0, 0, 0.35), "released keys return centered axes; throttle holds")
	send_key(KEY_D, true)
	send_key(KEY_LEFT, true)
	send_key(KEY_W, true)
	send_key(KEY_DOWN, true)
	check(radio.read(0) == Vector4(0, 0, 0, 0.35), "mixed-layout opposing directions cancel")
	for code in [KEY_D, KEY_LEFT, KEY_W, KEY_DOWN]:
		send_key(code, false)
	send_key(KEY_RIGHT, true)
	send_key(KEY_S, true)
	check(radio.read(0) == Vector4(1, 1, 0, 0.35), "mixed-layout diagonal pitch/bank remain independent")
	send_key(KEY_RIGHT, false)
	send_key(KEY_S, false)
	for pair in [[KEY_Z, -1.0], [KEY_C, 1.0]]:
		send_key(pair[0], true)
		check(radio.read(0).z == pair[1], "Z/C yaw direction %s" % OS.get_keycode_string(pair[0]))
		send_key(pair[0], false)
	send_key(KEY_E, true)
	check(radio.read(10).w == 1, "keyboard throttle clamps at maximum")
	send_key(KEY_E, false)
	send_key(KEY_Q, true)
	check(radio.read(10).w == 0, "keyboard throttle clamps at minimum")
	send_key(KEY_Q, false)
	radio.throttle = 0.35
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
	radio.select_touch()
	check(radio.touch_mode and radio.connected() and not radio.keyboard, "touch authority explicitly selected")
	radio.set_touch_command(Vector4(2, -2, 2, 2))
	check(radio.read(0) == Vector4(1, -1, 1, 1), "touch input bounded")
	var touch = Touch.new()
	touch.size = Vector2(1280, 800)
	check(touch.touch(1, true, touch.left_center() + Vector2(35, -35)), "left pad responds")
	check(touch.touch(2, true, touch.right_center() + Vector2(35, 35)), "simultaneous right pad responds")
	check(touch.command().x > 0 and touch.command().y > 0 and touch.command().z > 0 and touch.command().w > 0.5, "four channels mapped independently")
	touch.touch(1, false, Vector2.ZERO)
	touch.touch(2, false, Vector2.ZERO)
	check(touch.command().x == 0 and touch.command().y == 0 and touch.command().z == 0 and touch.command().w > 0.5, "release centers axes and preserves throttle")
	touch.free()
	radio.select_radio(99)
	radio.calibrated = true
	send_key(KEY_RIGHT, true)
	check(not radio.ready_to_fly() and radio.read(0.01) == Vector4.ZERO, "device loss ignores held keyboard input with no fallback")
	send_key(KEY_RIGHT, false)
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
	# Every stage preserves route length, gate clearance and static collision safety.
	for world in range(3):
		for tier in range(3):
			course.build(world, tier)
			var clear_stage = course.gates.size() == Course.GATE_COUNT
			for gate in course.gates:
				clear_stage = clear_stage and not course.collision(gate)
			check(clear_stage and is_equal_approx(course.gate_radius(), float(Course.STAGES[tier].radius)), "world %d stage %d traversable target gates" % [world, tier])
			if tier == 2:
				check(course.hazards.size() == Course.GATE_COUNT - 1, "debris stage populates deterministic hazards")
				var moving = course.hazards[0].mesh.position
				course.update_hazards(0.5)
				check(course.hazards[0].mesh.position != moving, "debris advances with simulation clock")
				check(course.debris_collision(course.hazards[0].mesh.position), "debris impact detected")
	course.queue_free()
	var store = Store.new()
	check(store.audio_volume() == 0.45, "legacy profile uses balanced sound without migration")
	for settings in [null, [], {"audio_volume": "bad"}, {"audio_volume": INF}]:
		store.data["settings"] = settings
		check(store.audio_volume() == 0.45, "malformed optional sound setting falls back without losing records")
	check(store.set_audio_volume(0.2), "sound preference saves")
	var sound_reload = Store.new()
	sound_reload.load_profile()
	check(sound_reload.audio_volume() == 0.2, "sound preference survives disk reload")
	check(store.set_audio_volume(2) and store.audio_volume() == 1, "sound preference clamps out-of-range values")
	check(store.set_audio_volume(0) and store.audio_volume() == 0, "mute preference persists")
	var sound = FlightAudio.new()
	root.add_child(sound)
	check(sound.engines.size() == 3 and sound.cues.size() == 4, "three original engine loops and four flight cues generated")
	for wave in sound.engines + sound.cues.values():
		var bounded = true
		for sample in range(0, wave.data.size(), 2):
			bounded = bounded and abs(wave.data.decode_s16(sample)) < 11000
		check(bounded and wave.mix_rate == 22050 and wave.data.size() > 0, "generated PCM stays within mix headroom")
	sound.set_flying(true)
	sound.update_engine(0, 0, 0, 1)
	var idle_pitch: float = sound.engine.pitch_scale
	sound.update_engine(1, 1, 0, 1)
	check(sound.engine.playing and sound.engine.pitch_scale > idle_pitch, "engine responds to thrust and speed")
	sound.play_cue("pass")
	sound._process(0)
	check(sound.feedback.playing, "gate pass produces audible feedback")
	sound.set_volume(0)
	check(not sound.engine.playing and not sound.feedback.playing, "mute immediately stops engine and cues")
	sound.set_volume(0.45)
	sound.update_engine(0.5, 0.5, 2, 1)
	check(sound.engine.playing and sound.engine.stream == sound.engines[2], "unmuting active flight resumes correct craft engine")
	sound.play_cue("pass")
	sound.play_cue("miss")
	check(sound.pending_cue == "miss", "rapid cue events coalesce to the latest feedback")
	sound.set_flying(false)
	sound._process(0)
	check(sound.pending_cue.is_empty() and not sound.feedback.playing, "pause cancels a queued cue before playback")
	sound.play_cue("pass")
	check(not sound.engine.playing and not sound.feedback.playing, "paused audio rejects stale gate cues")
	sound.play_cue("complete")
	sound._process(0)
	check(sound.feedback.playing, "debrief can play completion cue with engine stopped")
	sound.set_flying(false)
	sound.set_volume(1)
	sound.update_engine(1, 1, 0, 1)
	check(not sound.engine.playing and not sound.feedback.playing, "volume changes never restart paused flight audio")
	sound.queue_free()
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
	check(game.unlocked_stage_count() == 1, "fresh profiles start with Foundations")
	game.profile.data.records[game.record_key(0)] = {"best": 60.0, "attempts": 1, "last": {}}
	check(game.unlocked_stage_count() == 2, "first-stage success unlocks Crosswind")
	game.profile.data.records[game.record_key(1)] = {"best": 68.0, "attempts": 1, "last": {}}
	check(game.unlocked_stage_count() == 3, "Crosswind success unlocks Debris Run")
	game.profile.data.records.clear()
	game.start_run()
	check(game.state == "FLYING", "keyboard launch starts training")
	game.audio.set_volume(0.45)
	game._process(0.02)
	check(game.audio.engine.playing, "game flight starts engine audio")
	game.pause_run("test")
	check(not game.audio.engine.playing, "game pause stops engine immediately")
	var paused_position: Vector3 = game.flight.position
	for n in range(20):
		game._physics_process(1.0 / 120)
	check(game.state == "PAUSED" and game.flight.position == paused_position, "pause freezes movement")
	game.focus_ok = true
	game.resume_run()
	check(game.state == "FLYING", "explicit keyboard resume succeeds")
	game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == "PAUSED", "focus loss pauses flight")
	check(not game.audio.engine.playing and not game.audio.feedback.playing, "focus loss silences all flight audio")
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
	# Let the audio server retire stopped playback objects before the test process exits.
	await create_timer(0.05).timeout
	DirAccess.remove_absolute(store.path)
	DirAccess.remove_absolute(store.backup)
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
