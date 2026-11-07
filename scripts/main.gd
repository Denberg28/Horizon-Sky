extends Node3D
const FlightModel = preload("res://scripts/flight_model.gd")
const RadioInput = preload("res://scripts/radio_input.gd")
const ProfileStore = preload("res://scripts/profile_store.gd")
const Course = preload("res://scripts/course.gd")
const HUD = preload("res://scripts/hud.gd")
const VERSION = "0.1.0-rc.2"
const INK = Color("101e2c")
const MINT = Color("b4ffcc")
var flight = FlightModel.new()
var radio = RadioInput.new()
var profile = ProfileStore.new()
var course: Node3D
var craft: Node3D
var camera: Camera3D
var environment: WorldEnvironment
var ui: Control
var overlay: Control
var hud: Control
var telemetry: Label
var progress_label: Label
var notice: Label
var config_status: Label
var config_rows: Array = []
var state = "MENU"
var planet = 0
var vehicle = 0
var next_gate = 0
var hits = 0
var accuracy_total = 0.0
var minimum_clearance = 999.0
var command_variation = 0.0
var last_command = Vector4.ZERO
var message = ""
var message_time = 0.0
var last_result: Dictionary = {}
var calibration_open = false
var recovering = false
var focus_ok = true
var demo = false
var capture_path = ""
var frames = 0
var exit_after = 0

func _ready():
	profile.load_profile()
	for argument in OS.get_cmdline_user_args():
		if argument == "--demo":
			demo = true
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--frames="):
			exit_after = int(argument.trim_prefix("--frames="))
	build_world()
	build_ui()
	show_menu()
	Input.joy_connection_changed.connect(_device_changed)
	if demo:
		start_run()

func build_world():
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d6e8eb")
	environment.environment.ambient_light_energy = 0.7
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -30, 0)
	light.light_energy = 1.5
	add_child(light)
	course = Course.new()
	add_child(course)
	course.build(planet)
	craft = Node3D.new()
	add_child(craft)
	build_craft()
	camera = Camera3D.new()
	camera.fov = 70
	camera.far = 3000
	add_child(camera)
	flight.reset(vehicle)
	update_palette()
	update_camera(1.0)

func build_craft():
	for child in craft.get_children():
		child.queue_free()
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span = [4.4, 3.2, 3.6][vehicle]
	var points = [Vector3(0, 0, -4), Vector3(-0.65, -0.15, 1.4), Vector3(0.65, -0.15, 1.4), Vector3(0, 0.6, 0), Vector3(-span, -0.1, 1.7), Vector3(span, -0.1, 1.7), Vector3(0, 1.3, 1.5), Vector3(0, 0, 2.7)]
	var faces = [[0, 1, 3], [0, 3, 2], [1, 2, 3], [0, 4, 1], [0, 2, 5], [1, 6, 7], [2, 7, 6], [1, 7, 2]]
	var colors = [Color("e7eff0"), Color("becbd2"), Color("7c96a3"), Color("90b7b4"), Color("d1e4dd"), Color("b4ffcc"), Color("76b7b2"), Color("597787")]
	for i in range(faces.size()):
		for point in faces[i]:
			surface.set_color(colors[i])
			surface.add_vertex(points[point])
	surface.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat = Course.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mesh.material_override = mat
	craft.add_child(mesh)
	var engine = MeshInstance3D.new()
	var flame = CylinderMesh.new()
	flame.top_radius = 0.22
	flame.bottom_radius = 0.03
	flame.height = 1.5
	flame.radial_segments = 6
	engine.mesh = flame
	engine.rotation_degrees.x = 90
	engine.position = Vector3(0, 0, 3)
	engine.material_override = Course.material(MINT, true)
	craft.add_child(engine)

func update_palette():
	environment.environment.background_color = Course.PLANETS[planet].sky
	if hud:
		hud.accent = Course.PLANETS[planet].accent

func build_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	var theme = Theme.new()
	theme.default_font_size = 18
	for type in ["Button", "OptionButton", "SpinBox"]:
		for style in ["normal", "hover", "pressed", "focus"]:
			var box = StyleBoxFlat.new()
			box.bg_color = Color("304c58") if style == "hover" else Color("1b303e")
			box.border_color = MINT if style == "focus" else Color("3c5963")
			box.set_border_width_all(1)
			box.set_corner_radius_all(5)
			box.content_margin_left = 16
			box.content_margin_right = 16
			box.content_margin_top = 10
			box.content_margin_bottom = 10
			theme.set_stylebox(style, type, box)
	ui.theme = theme
	hud = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var telemetry_back = ColorRect.new()
	telemetry_back.color = Color(INK, 0.8)
	telemetry_back.position = Vector2(24, 20)
	telemetry_back.size = Vector2(1040, 135)
	telemetry_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(telemetry_back)
	telemetry = text(hud, "", 20)
	telemetry.position = Vector2(40, 30)
	progress_label = text(hud, "", 20)
	progress_label.position = Vector2(40, 72)
	notice = text(hud, "", 22, MINT)
	notice.position = Vector2(40, 118)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

func clear_overlay():
	calibration_open = false
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

func panel(parent: Node, rect: Rect2, opacity: float = 0.96, scrollable: bool = false) -> VBoxContainer:
	var frame = PanelContainer.new()
	frame.position = rect.position
	frame.size = rect.size
	var box = StyleBoxFlat.new()
	box.bg_color = Color(INK, opacity)
	box.set_corner_radius_all(10)
	box.content_margin_left = 30
	box.content_margin_top = 26
	box.content_margin_right = 30
	box.content_margin_bottom = 26
	frame.add_theme_stylebox_override("panel", box)
	parent.add_child(frame)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	if scrollable:
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		frame.add_child(scroll)
		scroll.add_child(col)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		frame.add_child(col)
	return col

func text(parent: Node, value: String, font_size: int = 18, color: Color = Color("e2eded")) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.12, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func button(parent: Node, value: String, callback: Callable) -> Button:
	var result = Button.new()
	result.text = value
	result.custom_minimum_size.y = 44
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func gap(parent: Node, height: float):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func show_menu():
	state = "MENU"
	hud.visible = false
	clear_overlay()
	var col = panel(overlay, Rect2(35, 35, 565, 830))
	text(col, "H O R I Z O N   S K Y", 18, MINT)
	text(col, "Find your line.", 48)
	text(col, "A small world. A sharper pilot.", 21, Color("a9bbc4"))
	gap(col, 10)
	text(col, "01   CHOOSE YOUR WORLD", 14, MINT)
	var world_select = OptionButton.new()
	for p in Course.PLANETS:
		world_select.add_item(p.name + "  /  " + p.subtitle)
	world_select.select(planet)
	col.add_child(world_select)
	var lesson = text(col, Course.PLANETS[planet].lesson, 18)
	world_select.item_selected.connect(func(i):
		planet = i
		course.build(i)
		update_palette()
		lesson.text = Course.PLANETS[i].lesson)
	gap(col, 4)
	text(col, "02   CHOOSE YOUR CRAFT", 14, MINT)
	var craft_select = OptionButton.new()
	for v in FlightModel.VEHICLES:
		craft_select.add_item(v.name + "  /  " + v.role)
	craft_select.select(vehicle)
	col.add_child(craft_select)
	craft_select.item_selected.connect(func(i):
		vehicle = i
		build_craft()
		flight.reset(vehicle))
	gap(col, 4)
	text(col, "03   CHECK YOUR CONTROLS", 14, MINT)
	text(col, authority_name(), 18)
	button(col, "Controller setup & calibration", show_calibration)
	button(col, "Begin training   →", start_run)
	text(col, "W / S or ↑ / ↓  pitch     A / D or ← / →  bank\nZ / C  rudder     Q / E  throttle\nEsc  pause     F11  fullscreen", 16, Color("a9bbc4"))
	text(col, "16 gates • Fly through the center • Avoid terrain\nArcade handling; no real-aircraft qualification.", 16, Color("a9bbc4"))
	if not profile.warning.is_empty():
		text(col, profile.warning, 14, Color("ffbe91"))
	var footer = text(overlay, "PROCEDURAL WORLDS  /  USB RADIO READY\nTEST CANDIDATE " + VERSION, 16)
	footer.position = Vector2(865, 790)
	var best_text = "YOUR FLIGHT LOG\n"
	for key in profile.data.records:
		var record = profile.data.records[key]
		if record is Dictionary:
			best_text += "%s   best %.0f / 100\n" % [key, float(record.get("best", 0))]
	var log_label = text(overlay, best_text, 16, Color("e1f4ef"))
	log_label.position = Vector2(865, 60)
	flight.reset(vehicle)
	update_camera(1.0)

func authority_name() -> String:
	if radio.keyboard:
		return "Keyboard practice / WASD or arrow keys"
	return Input.get_joy_name(radio.device) if radio.connected() else "Radio disconnected — select device again"

func show_calibration():
	state = "MENU"
	hud.visible = false
	clear_overlay()
	calibration_open = true
	config_rows.clear()
	var col = panel(overlay, Rect2(170, 30, 1100, 840), 0.96, true)
	text(col, "CONTROLLER LAB", 32, MINT)
	text(col, "Connect a data USB cable. Select USB Joystick mode on the radio.", 18)
	var select = OptionButton.new()
	select.add_item("Keyboard practice", -1)
	var selection = 0
	for id in Input.get_connected_joypads():
		select.add_item("%s  /  device %d" % [Input.get_joy_name(id), id], id)
		if not radio.keyboard and id == radio.device:
			selection = select.item_count - 1
	select.select(selection if radio.connected() else -1)
	col.add_child(select)
	select.item_selected.connect(func(index):
		var id = select.get_item_id(index)
		if id == -1:
			radio.keyboard = true
		else:
			radio.select_radio(id)
			var saved = profile.data.controllers.get(radio.signature)
			if radio.valid_mapping(saved):
				radio.mapping = saved.duplicate(true)
				radio.calibrated = true
		show_calibration())
	text(col, "1   Map each channel to a distinct axis. Watch the live values; reverse if needed.", 17)
	text(col, "CHANNEL                 AXIS             REVERSE             LIVE INPUT", 14, Color("a9bbc4"))
	for i in range(4):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 25)
		col.add_child(row)
		var name_label = text(row, RadioInput.CHANNELS[i], 18)
		name_label.custom_minimum_size.x = 140
		var axis = SpinBox.new()
		axis.min_value = 0
		axis.max_value = JOY_AXIS_MAX - 1
		axis.value = radio.mapping[i].axis
		axis.custom_minimum_size.x = 115
		row.add_child(axis)
		var reverse = CheckBox.new()
		reverse.text = "Reverse"
		reverse.button_pressed = radio.mapping[i].invert
		row.add_child(reverse)
		var live = text(row, "0.00", 18, MINT)
		config_rows.append(live)
		axis.value_changed.connect(func(value):
			radio.mapping[i].axis = int(value)
			radio.calibrated = false
			radio.capturing = false)
		reverse.toggled.connect(func(value):
			radio.mapping[i].invert = value
			radio.calibrated = false
			radio.capturing = false)
	text(col, "2   Start range capture. Sweep all four channels fully, several times.", 17)
	button(col, "Start range capture", func():
		if not radio.keyboard and radio.connected():
			radio.begin_capture()
			config_status.text = "Capturing… sweep all channels; then center roll/pitch/yaw. Throttle anywhere."
		else:
			config_status.text = "Select a connected USB radio first.")
	text(col, "3   Center roll, pitch and yaw. Capture center & save. Then LOWER throttle.", 17)
	button(col, "Capture center & save calibration", save_calibration)
	config_status = text(col, "Calibrated. Confirm directions before flight." if radio.calibrated else "Not calibrated. Keyboard remains available.", 16, MINT)
	text(col, "Positive: roll → bank right; pitch → climb; yaw → turn right; throttle → faster.\nChannels must span both sides of center. Never calibrate with trim offsets.\nDevice loss or focus loss pauses flight; reconnect always requires explicit resume.", 16, Color("a9bbc4"))
	button(col, "Refresh device list", show_calibration)
	button(col, "Back to hangar", show_menu)

func save_calibration():
	if not radio.capturing:
		config_status.text = "Start a range capture before saving."
		return
	if not radio.finish_capture():
		config_status.text = "Capture rejected: use distinct axes, full travel and centered roll/pitch/yaw."
		return
	profile.data.controllers[radio.signature] = radio.mapping.duplicate(true)
	config_status.text = "Calibration saved. Lower throttle; confirm directions." if profile.save_profile() else profile.warning

func start_run():
	if not radio.ready_to_fly():
		show_calibration()
		config_status.text = "Before launch: connect, calibrate, center roll/pitch/yaw, and lower throttle."
		return
	flight.reset(vehicle)
	radio.throttle = 0.35
	next_gate = 0
	hits = 0
	accuracy_total = 0
	minimum_clearance = 999
	command_variation = 0
	last_command = Vector4.ZERO
	message = "LOOK AHEAD  /  Fly through the illuminated gate"
	message_time = 5
	course.build(planet)
	update_palette()
	state = "FLYING"
	recovering = false
	clear_overlay()
	hud.visible = true
	hud.flying = true
	update_camera(1.0)

func pause_run(reason: String):
	if state != "FLYING" and state != "PAUSED":
		return
	state = "PAUSED"
	clear_overlay()
	var col = panel(overlay, Rect2(400, 190, 640, 500))
	text(col, "Take a breath.", 38, MINT)
	text(col, reason, 18)
	text(col, "Flight time and movement are frozen.\nCenter controls and lower throttle before resuming.", 18)
	button(col, "Resume flight", resume_run)
	button(col, "Restart course", start_run)
	button(col, "Return to hangar", show_menu)

func resume_run():
	if not focus_ok or not radio.ready_to_fly():
		pause_run("Input not ready. Reconnect the same radio, center sticks,\nand lower throttle; or return to hangar for setup.")
		return
	state = "FLYING"
	recovering = false
	last_command = Vector4.ZERO
	clear_overlay()

func finish_run(reason: String, completed: bool):
	if state != "FLYING":
		return
	state = "RESULTS"
	var precision = accuracy_total / Course.GATE_COUNT * 100.0
	var smoothness = clampf(100 - command_variation / maxf(flight.time, 1.0) * 6, 0, 100)
	var score = clampf(hits / float(Course.GATE_COUNT) * 65 + precision * 0.25 + smoothness * 0.1, 0, 100)
	if not completed:
		score *= 0.5
	last_result = {"score": snappedf(score, 0.1), "hits": hits, "precision": snappedf(precision, 0.1), "seconds": snappedf(flight.time, 0.1), "clearance": snappedf(minimum_clearance, 0.1), "smoothness": snappedf(smoothness, 0.1), "completed": completed}
	var saved = profile.record(Course.PLANETS[planet].name + " / " + FlightModel.VEHICLES[vehicle].name, last_result)
	clear_overlay()
	var col = panel(overlay, Rect2(390, 100, 660, 700))
	text(col, "FLIGHT DEBRIEF", 18, MINT)
	text(col, "%.0f / 100" % score, 52)
	text(col, reason, 22)
	text(col, "%d / %d gates  •  %.1f s\nCenter precision  %.0f%%\nControl smoothness  %.0f%%\nMinimum terrain clearance  %.1f m" % [hits, Course.GATE_COUNT, flight.time, precision, smoothness, minimum_clearance], 22)
	gap(col, 8)
	var advice = "Look two gates ahead; turn before the gate fills your view."
	if minimum_clearance < 12:
		advice = "Protect your clearance. Establish altitude before the next turn."
	elif smoothness < 65:
		advice = "Use small corrections. Let the craft settle before reversing input."
	text(col, advice, 17, MINT)
	if not saved:
		text(col, profile.warning, 16, Color("ffbe91"))
	button(col, "Fly again", start_run)
	button(col, "Return to hangar", show_menu)

func _physics_process(dt: float):
	if state != "FLYING":
		return
	if not radio.connected():
		recovering = true
		pause_run("Controller disconnected. No keyboard takeover.")
		return
	var command = radio.read(dt)
	if demo:
		# Automated visual smoke only, explicitly enabled by command-line flag.
		var target: Vector3 = course.gates[mini(next_gate, Course.GATE_COUNT - 1)]
		command = Vector4(clampf((target.x - flight.position.x) * 0.012 - flight.heading * 1.6, -1, 1), clampf((target.y - flight.position.y) * 0.018 - flight.pitch * 1.5, -1, 1), 0, 0.45)
	command_variation += (command - last_command).length()
	last_command = command
	var previous: Vector3 = flight.position
	flight.step(command, dt, Course.PLANETS[planet].wind)
	minimum_clearance = minf(minimum_clearance, flight.position.y - Course.ground_height(flight.position.x, flight.position.z))
	if course.collision(flight.position):
		finish_run("Terrain contact. Reset and build clearance.", false)
		return
	if absf(flight.position.x) > 145 or flight.position.y > 180:
		finish_run("Outside training airspace. Keep the course in view.", false)
		return
	var distance = FlightModel.crossing_distance(previous, flight.position, course.gates[next_gate])
	if distance >= 0:
		var success = distance <= Course.RADIUS - 1.5
		if success:
			hits += 1
			accuracy_total += 1.0 - distance / Course.RADIUS
		course.mark_gate(next_gate, success)
		next_gate += 1
		message = "CLEAN PASS  /  Look for the next gate" if success else "GATE MISSED  /  Set up your next approach"
		message_time = 2.0
		if next_gate == Course.GATE_COUNT:
			finish_run("Course complete. Make the next line cleaner.", true)
			return
	if flight.time > 180:
		finish_run("Session time limit reached. Try a more direct line.", false)
	hud.command = command
	hud.bank = flight.roll

func _process(dt: float):
	frames += 1
	if radio.capturing:
		radio.sample_capture()
	if calibration_open:
		var values = radio.read(0)
		for i in range(config_rows.size()):
			var raw = Input.get_joy_axis(radio.device, int(radio.mapping[i].axis)) if not radio.keyboard and radio.connected() else 0.0
			config_rows[i].text = "%+.2f raw   →   %+.2f output" % [raw, values[i]]
	if state == "FLYING":
		update_camera(dt)
		message_time -= dt
		telemetry.text = "%s  /  %s       %.0f m/s       ALT %.0f m       THR %.0f%%" % [Course.PLANETS[planet].name, FlightModel.VEHICLES[vehicle].name, flight.speed, flight.position.y, last_command.w * 100]
		progress_label.text = "GATE %02d / %02d     PASSED %02d     %.1f s" % [mini(next_gate + 1, Course.GATE_COUNT), Course.GATE_COUNT, hits, flight.time]
		notice.text = message if message_time > 0 else ""
	elif state == "MENU":
		update_camera(dt)
	hud.queue_redraw()
	if not capture_path.is_empty() and frames == 30:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
	if exit_after > 0 and frames >= exit_after:
		get_tree().quit()

func update_camera(dt: float):
	craft.position = flight.position + (Vector3(20, 1, -8) if state == "MENU" else Vector3.ZERO)
	craft.rotation = Vector3(flight.pitch, -flight.heading, flight.roll)
	var offset = Vector3(-sin(flight.heading) * 17, 5, cos(flight.heading) * 17)
	if state == "MENU":
		offset = Vector3(13, 7, 19)
	var target = flight.position + offset
	camera.position = camera.position.lerp(target, clampf(dt * 5, 0, 1)) if dt < 1 else target
	camera.look_at(flight.position + Vector3(0, 1, -14))

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.keycode == KEY_ESCAPE:
		if state == "FLYING":
			pause_run("Paused by pilot.")
		elif state == "PAUSED":
			resume_run()
		elif state == "RESULTS" or calibration_open:
			show_menu()

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_ok = false
		if state == "FLYING":
			pause_run("Window lost focus. Resume when ready.")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_ok = true

func _device_changed(device: int, connected: bool):
	if not radio.keyboard and device == radio.device and not connected:
		radio.capturing = false
		if state == "FLYING":
			recovering = true
			pause_run("Controller disconnected. Reconnect and explicitly resume.")
	if calibration_open:
		show_calibration()
