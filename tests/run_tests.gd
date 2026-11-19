extends SceneTree
const Flight = preload("res://scripts/flight_model.gd")
const Radio = preload("res://scripts/radio_input.gd")
const Course = preload("res://scripts/course.gd")
const Store = preload("res://scripts/profile_store.gd")
const Main = preload("res://scripts/main.gd")
const Touch = preload("res://scripts/touch_controls.gd")
const FlightEffects = preload("res://scripts/flight_effects.gd")
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
	check(Radio.CHANNELS == ["Aileron / right X", "Elevator / right Y", "Rudder / left X", "Throttle / left Y"], "fixed-wing Mode 2 semantic channel labels")
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
	touch.reset_for_run()
	touch.touch(3, true, touch.right_center() + Vector2(touch.travel(), touch.travel()))
	check(touch.command().x == 1 and touch.command().y == 1, "line endpoints reach full aileron/elevator travel")
	touch.touch(3, false, Vector2.ZERO)
	touch.touch(4, true, touch.left_center() - Vector2(0, touch.travel()))
	check(touch.command().w == 1, "top of power line reaches full throttle")
	touch.clear_gestures()
	touch.reset_for_run()
	check(touch.command() == Vector4(0, 0, 0, 0.35), "new flight resets held power and clears all gesture ownership")
	touch.free()
	radio.select_radio(99)
	radio.calibrated = true
	send_key(KEY_RIGHT, true)
	check(not radio.ready_to_fly() and radio.read(0.01) == Vector4.ZERO, "device loss ignores held keyboard input with no fallback")
	send_key(KEY_RIGHT, false)
	var model = Flight.new()
	model.reset(0)
	for n in range(120):
		model.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
	check(model.position.z < 10 and absf(model.position.x) < 0.01 and is_equal_approx(model.position.y, 45), "neutral flight tracks straight and level")
	model.reset(0)
	for n in range(240):
		model.step(Vector4(0.6, 0.4, 0, 0.5), 1.0 / 120)
	check(model.position.x > 2 and model.position.y > 47 and model.roll < 0, "bank right turns right; pitch climbs")
	var before: Vector3 = model.position
	model.step(Vector4(INF, 0, 0, 0), 0.01)
	model.step(Vector4.ONE, 1.0)
	check(model.position == before, "nonfinite input and excessive timestep rejected")
	for kind in range(3):
		model.reset(kind)
		for n in range(12000):
			model.step(Vector4(sin(n * 0.01), cos(n * 0.02), sin(n * 0.03), 0.7), 1.0 / 120)
		check(model.position.is_finite() and absf(model.pitch) <= 1.301 and model.speed <= Flight.VEHICLES[kind].max_speed + 0.001, "vehicle %d bounded 100-second soak" % kind)
	# Force-model regressions: energy, stall, bank and distinct vehicle response.
	for kind in range(2):
		model.reset(kind)
		var cruise = model.speed
		for n in range(720):
			model.step(Vector4(0, 0, 0, 0), 1.0 / 120)
		check(model.speed < cruise - 2 and model.position.y < 43, "aircraft %d power-off loses energy and glides" % kind)
		model.reset(kind)
		model.velocity = Vector3(0, 0, -4)
		model.step(Vector4.ZERO, 1.0 / 120)
		check(model.stalled and model.velocity.y < 0 and model.speed < 5, "aircraft %d low airspeed loses lift without a speed floor" % kind)
		model.reset(kind)
		model.pitch = 0.1
		model.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
		var attached_lift = model.lift_acceleration
		model.reset(kind)
		model.pitch = 0.8
		model.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
		check(model.stalled and model.lift_acceleration < attached_lift, "aircraft %d separated flow reduces lift" % kind)
		model.reset(kind)
		model.roll = -0.7
		for n in range(120):
			model.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
		check(model.position.x > 1 and model.position.y < 45, "aircraft %d bank turns trajectory and reduces vertical lift" % kind)
	var trainer = Flight.new()
	var jet = Flight.new()
	trainer.reset(0)
	jet.reset(1)
	for n in range(60):
		trainer.step(Vector4(0.3, 0, 0, 1), 1.0 / 120)
		jet.step(Vector4(0.3, 0, 0, 1), 1.0 / 120)
	check(absf(jet.roll) > absf(trainer.roll) * 1.5, "jet has faster aileron response than trainer")
	check(trainer.engine_power > jet.engine_power + 0.15, "jet turbine spools more slowly than trainer propeller")
	trainer.reset(0)
	jet.reset(1)
	trainer.roll = -0.6
	jet.roll = -0.6
	for n in range(120):
		trainer.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
		jet.step(Vector4(0, 0, 0, 0.35), 1.0 / 120)
	check(absf(trainer.roll) < absf(jet.roll) - 0.1, "trainer dihedral recovers bank while jet retains attitude")
	model.reset(2)
	var coasting = model.velocity
	for n in range(120):
		model.step(Vector4(0.5, 0, 0, 0.35), 1.0 / 120, 6)
	check(model.velocity == coasting and model.position.y == 45, "spacecraft holds cruise without wing lift, bank turning, wind or gravity")
	model.reset(2)
	for n in range(120):
		model.step(Vector4(0, 0, 0, 1), 1.0 / 120)
	check(model.speed > 40, "spacecraft thrust accelerates along its facing direction")
	model.reset(2)
	for n in range(240): model.step(Vector4.ZERO, 1.0 / 120)
	check(model.speed < 5 and model.position.y == 45, "spacecraft low throttle engages assisted deceleration without gravity")
	for kind in range(2):
		var accelerated = Flight.new()
		var slowed = Flight.new()
		accelerated.reset(kind)
		slowed.reset(kind)
		var initial = accelerated.speed
		for n in range(240):
			accelerated.step(Vector4(0, 0, 0, 1), 1.0 / 120)
			slowed.step(Vector4.ZERO, 1.0 / 120)
		check(accelerated.speed > initial + 3 and slowed.speed < initial - 2, "aircraft %d throttle clearly accelerates and decelerates over two seconds" % kind)
		check(accelerated.longitudinal_acceleration > 0 and slowed.longitudinal_acceleration < 0, "aircraft %d HUD acceleration sign follows actual speed change" % kind)
	var coarse = Flight.new()
	var fine = Flight.new()
	coarse.reset(0)
	fine.reset(0)
	for n in range(120): coarse.step(Vector4(0.12, 0.08, 0, 0.4), 1.0 / 60)
	for n in range(240): fine.step(Vector4(0.12, 0.08, 0, 0.4), 1.0 / 120)
	check(coarse.position.distance_to(fine.position) < 0.5, "force integration stays consistent across 60/120 Hz")
	# Craft-specific speed envelopes: trainer is slower; speed limits still hold in dives.
	check(Flight.VEHICLES[0].cruise_speed < Flight.VEHICLES[1].cruise_speed and Flight.VEHICLES[0].max_speed < Flight.VEHICLES[1].max_speed and Flight.VEHICLES[1].max_speed < Flight.VEHICLES[2].max_speed, "trainer, jet and spacecraft have distinct speed envelopes")
	for kind in range(3):
		model.reset(kind)
		model.velocity = Vector3(0, -150, -150)
		for n in range(120): model.step(Vector4(0, -0.2, 0, 1), 1.0 / 120)
		check(model.speed <= Flight.VEHICLES[kind].max_speed + 0.001, "craft %d dive remains inside configured speed limit" % kind)
	var fx = FlightEffects.new()
	root.add_child(fx)
	fx.configure(1, 3.2)
	fx.set_active(true)
	var pose = Transform3D(Basis.IDENTITY, Vector3(0, 45, 30))
	for n in range(60): fx.step(pose, 50, 0.1, 0, 50, 96, 1.0 / 120)
	var low_length: float = fx.plumes[0].scale.y
	var low_alpha: float = fx.plume_material.albedo_color.a
	for n in range(240):
		pose.origin.z -= 0.5
		fx.step(pose, 64, 1, 3, 50, 96, 1.0 / 120)
	check(fx.plumes[0].scale.y > low_length and fx.plume_material.albedo_color.a > low_alpha and fx.plume_material.emission_energy_multiplier > 2, "jet exhaust length, opacity and emission rise with actual engine power")
	check(fx.samples.size() > 2 and fx.ribbons[0].mesh.get_surface_count() > 0 and fx.ribbons[1].mesh.get_surface_count() > 0, "speed-up generates both world-space contrail ribbons")
	check(fx.samples[0].left.z > fx.samples[-1].left.z, "contrails retain the travelled path behind the aircraft")
	check(fx.samples.size() <= FlightEffects.MAX_SAMPLES and fx.samples[0].age < FlightEffects.TRAIL_LIFETIME, "contrail sample count and lifetime stay bounded")
	var paused_phase: float = fx.phase
	var paused_age: float = fx.samples[0].age
	fx.set_active(false)
	fx.step(pose, 70, 1, 4, 50, 96, 0.1)
	check(fx.phase == paused_phase and fx.samples[0].age == paused_age and not fx.visible, "paused effects freeze without advancing exhaust or trail age")
	fx.set_active(true)
	for n in range(240): fx.step(pose, 50, 0.1, -2, 50, 96, 1.0 / 120)
	check(fx.samples.is_empty() and fx.ribbons[0].mesh.get_surface_count() == 0, "deceleration stops new contrails and old ribbons fade away")
	fx.reset()
	for n in range(120): fx.step(pose, 96, 1, 0, 50, 96, 1.0 / 120)
	check(fx.samples.is_empty() and fx.engine_level > 0.9, "steady maximum speed keeps powered exhaust without false speed-up trails")
	fx.reset()
	for n in range(120): fx.step(pose, 0, 1, 4, 50, 96, 1.0 / 120)
	check(fx.samples.is_empty() and fx.plumes[0].visible, "stationary power can light exhaust without painting a contrail")
	fx.configure(0, 4.4)
	for n in range(120): fx.step(pose, 32, 1, 4, 24, 42, 1.0 / 120)
	check(not fx.plume_material.emission_enabled and fx.plume_material.albedo_color.a <= 0.161, "trainer uses subtle propwash rather than a jet flame")
	fx.configure(2, 3.6)
	for n in range(120): fx.step(pose, 64, 1, 4, 42, 115, 1.0 / 120)
	check(fx.plumes.size() == 2 and fx.plumes[0].position.x < 0 and fx.plumes[1].position.x > 0, "spacecraft has paired high-power exhaust plumes")
	fx.set_active(false, true)
	check(fx.samples.is_empty() and fx.engine_level == 0 and fx.trail_level == 0, "menu/results/restart clears all prior flight effects")
	fx.set_active(true)
	fx.step(pose, INF, 1, 3, 50, 96, 0.01)
	check(fx.phase == 0, "nonfinite visual inputs are rejected without geometry corruption")
	fx.queue_free()
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
	# Many seeds exercise route families without allocating terrain meshes per sample.
	var patterns = {}
	var fingerprints = {}
	var bounded_routes = true
	for seed_value in range(1, 251):
		for world in range(3):
			for tier in range(3):
				var generated = Course.generate_route(world, tier, seed_value)
				var points: Array = generated.gates
				patterns[generated.pattern] = true
				fingerprints[points.hash()] = true
				bounded_routes = bounded_routes and points.size() == Course.GATE_COUNT
				for i in range(points.size()):
					bounded_routes = bounded_routes and absf(points[i].x) < 65 and points[i].y - Course.ground_height(points[i].x, points[i].z) >= 23.99
					if i > 0:
						var delta: Vector3 = points[i] - points[i - 1]
						bounded_routes = bounded_routes and absf(delta.x) <= 13.01 + tier * 4 and absf(delta.y) <= 7.01 + tier * 2 and delta.z <= -97.99 and delta.z >= -126.01
	check(bounded_routes, "2250 seeded route configurations keep gate count, turn/climb limits and terrain clearance")
	check(patterns.size() == Course.PATTERNS.size() and fingerprints.size() > 600, "random routes cover all five families with varied geometry")
	check(Course.generate_route(1, 2, 12345).gates == Course.generate_route(1, 2, 12345).gates, "same route seed exactly reproduces gate coordinates")
	for seed_value in [7, 42, 12345]:
		course.build(1, 2, seed_value)
		var gates_clear = true
		for gate in course.gates: gates_clear = gates_clear and not course.collision(gate)
		check(gates_clear, "seed %d generated gate planes clear pylons and moving debris" % seed_value)
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
	check(sound.engines.size() == 3 and sound.cues.size() == 4 and sound.tracks.size() == 3, "sampled engines, event cues and three original focus pieces load")
	for stream in sound.engines + sound.cues.values() + sound.tracks:
		check((stream is AudioStreamOggVorbis or stream is AudioStreamWAV) and stream.get_length() > 0.1, "effects and original WAV tracks decode with positive duration")
	sound.set_flying(true)
	sound.update_engine(0, 0, 0, 1)
	sound._process(0)
	await process_frame
	var idle_pitch: float = sound.engine.pitch_scale
	sound.update_engine(1, 1, 0, 1)
	sound._process(0)
	check(sound.engine.playing and sound.engine.pitch_scale > idle_pitch, "engine responds to thrust and speed")
	sound.play_cue("pass")
	sound._process(0)
	check(not sound.feedback.playing, "successful gate passes produce no repeating chirp")
	check(sound.music.playing, "flight starts evolving ambient focus score")
	sound.set_volume(0)
	check(not sound.engine.playing and not sound.feedback.playing and not sound.music.playing, "mute immediately stops engine and cues")
	sound.set_volume(0.45)
	sound.update_engine(0.5, 0.5, 2, 1)
	sound._process(0)
	await process_frame
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
	sound._process(0)
	check(not sound.engine.playing and not sound.feedback.playing, "volume changes never restart paused flight audio")
	sound.start_session(2)
	check(sound.current_stage == 2 and sound.music.stream == sound.tracks[2] and not sound.music.playing, "next stage selects its own music without paused playback")
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
	game.audio._process(0)
	await process_frame
	check(game.audio.engine.playing, "game flight starts engine audio")
	var replay_seed = game.route_seed
	var replay_gates = game.course.gates.duplicate()
	game.start_run(false)
	check(game.route_seed == replay_seed and game.course.gates == replay_gates, "retry keeps route seed and exact gate layout")
	game.start_run(true)
	check(game.route_seed != replay_seed and game.course.gates != replay_gates, "new route changes seed and track geometry")
	game.pause_run("test")
	check(not game.audio.engine.playing, "game pause stops engine immediately")
	var paused_position: Vector3 = game.flight.position
	for n in range(20):
		game._physics_process(1.0 / 120)
	check(game.state == "PAUSED" and game.flight.position == paused_position, "pause freezes movement")
	check(not game.effects.active and not game.effects.visible, "game pause hides and suspends flight effects")
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
	check(game.effects.samples.is_empty() and not game.effects.visible, "debrief clears active trail/exhaust output")
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
	# Reproduce the phone text-width failure at wide, standard and compact canvases.
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960), Vector2i(960, 540)]:
		var viewport = SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var layout = Main.new()
		viewport.add_child(layout)
		await process_frame
		await process_frame
		var readable = true
		var bounded_choices = true
		for label in layout.ui.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and not label.text.is_empty():
				readable = readable and label.size.x > 40 and label.get_line_count() <= 3
		for option in layout.ui.find_children("*", "OptionButton", true, false):
			bounded_choices = bounded_choices and option.size.y >= 48 and option.size.y <= 64
		check(readable and bounded_choices, "canvas %s menu keeps readable text and bounded selectors" % dimensions)
		var sticks = layout.touch_controls
		var hit_size = Vector2.ONE * (sticks.travel() + 24) * 2
		var left_hit = Rect2(sticks.left_center() - hit_size * 0.5, hit_size)
		var right_hit = Rect2(sticks.right_center() - hit_size * 0.5, hit_size)
		var panel = layout.hud.instrument_rect()
		check(not panel.intersects(left_hit) and not panel.intersects(right_hit) and not left_hit.intersects(right_hit), "canvas %s enlarged sticks clear central flight instruments" % dimensions)
		layout.start_run()
		layout._process(0.01)
		await process_frame
		check(layout.telemetry.get_line_count() == 1 and layout.progress_label.get_line_count() == 1 and layout.telemetry.size.x > 400, "canvas %s HUD never wraps into a text column" % dimensions)
		check(layout.telemetry.get_global_rect().end.x < layout.mobile_pause.get_global_rect().position.x, "canvas %s telemetry clears pause button" % dimensions)
		layout.finish_run("Test end", false)
		var attempts = layout.profile.data.records[layout.record_key(layout.stage)].attempts
		layout.refresh_layout()
		check(not layout.hud.visible and layout.profile.data.records[layout.record_key(layout.stage)].attempts == attempts, "canvas %s debrief hides HUD and resizing does not save another attempt" % dimensions)
		viewport.queue_free()
		layout.audio._process(0)
		check(layout.audio.pending_cue.is_empty() and not layout.audio.feedback.playing and not layout.audio.music.playing, "queued scene removal cancels native cue/music dispatch")
		await process_frame
	game.queue_free()
	await process_frame
	# Let the audio server retire stopped playback objects before the test process exits.
	await create_timer(0.05).timeout
	DirAccess.remove_absolute(store.path)
	DirAccess.remove_absolute(store.backup)
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
