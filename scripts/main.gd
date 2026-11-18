extends Node3D
const FlightModel = preload("res://scripts/flight_model.gd")
const RadioInput = preload("res://scripts/radio_input.gd")
const ProfileStore = preload("res://scripts/profile_store.gd")
const Course = preload("res://scripts/course.gd")
const HUD = preload("res://scripts/hud.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const FlightAudio = preload("res://scripts/flight_audio.gd")
const VERSION = "0.1.0-rc.6"
const INK = Color("101e2c")
const MINT = Color("b4ffcc")
var flight = FlightModel.new()
var radio = RadioInput.new()
var profile = ProfileStore.new()
var audio: Node
var course: Node3D
var craft: Node3D
var engine_flare: MeshInstance3D
var camera: Camera3D
var environment: WorldEnvironment
var ui: Control
var overlay: Control
var hud: Control
var touch_controls: Control
var mobile_pause: Button
var last_pause_reason = "Paused"
var relayout_pending = false
var telemetry_back: ColorRect
var telemetry: Label
var progress_label: Label
var notice: Label
var config_status: Label
var config_rows: Array = []
var state = "MENU"
var planet = 0
var vehicle = 0
var stage = 0
var streak = 0
var best_streak = 0
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
var shutting_down = false

func _ready():
	get_tree().auto_accept_quit = false
	profile.load_profile()
	audio = FlightAudio.new()
	add_child(audio)
	audio.set_volume(profile.audio_volume())
	if OS.get_name() == "Android" or "--touch-preview" in OS.get_cmdline_user_args():
		radio.select_touch()
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
	get_viewport().size_changed.connect(queue_layout)
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
	course.build(planet, stage)
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
	engine_flare = engine

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
	theme.default_font_size = 20
	for type in ["Button", "OptionButton", "SpinBox"]:
		for style in ["normal", "hover", "pressed", "focus"]:
			var box = StyleBoxFlat.new()
			box.bg_color = Color("31576a") if style == "hover" else Color("172d3b")
			box.border_color = MINT if style == "focus" else Color("436373")
			box.set_border_width_all(1)
			box.set_corner_radius_all(9)
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
	telemetry_back = ColorRect.new()
	telemetry_back.color = Color(INK, 0.8)
	telemetry_back.anchor_right = 1.0
	telemetry_back.offset_left = 24
	telemetry_back.offset_top = 20
	telemetry_back.offset_right = -24
	telemetry_back.offset_bottom = 102
	telemetry_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(telemetry_back)
	telemetry = text(hud, "", 20)
	telemetry.position = Vector2(40, 30)
	telemetry.anchor_right = 1
	telemetry.offset_right = -180
	telemetry.clip_text = true
	progress_label = text(hud, "", 20)
	progress_label.position = Vector2(40, 64)
	progress_label.anchor_right = 1
	progress_label.offset_right = -180
	progress_label.clip_text = true
	notice = text(hud, "", 20, MINT)
	notice.position = Vector2(40, 116)
	notice.anchor_right = 1
	notice.offset_right = -40
	notice.clip_text = true
	touch_controls = TouchControls.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.visible = false
	ui.add_child(touch_controls)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	mobile_pause = button(ui, "PAUSE", func(): pause_run("Ready when you are."))
	mobile_pause.anchor_left = 1
	mobile_pause.anchor_right = 1
	mobile_pause.offset_left = -175
	mobile_pause.offset_right = -28
	mobile_pause.offset_top = 34
	mobile_pause.offset_bottom = 92
	mobile_pause.visible = false
	layout_hud()

func sync_flight_state():
	if audio != null:
		audio.set_flying(state == "FLYING" and focus_ok)
	if touch_controls == null:
		return
	hud.visible = state == "FLYING"
	hud.flying = state == "FLYING"
	hud.show_input_monitors = not radio.touch_mode
	var playing = state == "FLYING" and radio.touch_mode
	touch_controls.visible = playing
	mobile_pause.visible = state == "FLYING"
	if not playing:
		touch_controls.clear_gestures()


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
	box.border_color = Color("4f7180", 0.52)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 24
	box.content_margin_top = 20
	box.content_margin_right = 24
	box.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", box)
	parent.add_child(frame)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if parent is VBoxContainer else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.12, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func button(parent: Node, value: String, callback: Callable) -> Button:
	var result = Button.new()
	result.text = value
	result.custom_minimum_size.y = 48
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func gap(parent: Node, height: float):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

# Shared hangar/pause sound control: choices persist on selection, never per frame.
func choice(parent: Node, items: Array, selected: int = 0) -> OptionButton:
	var select = OptionButton.new()
	select.fit_to_longest_item = false
	select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select.custom_minimum_size = Vector2(0, 48)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		select.add_item(str(item))
	select.select(selected)
	parent.add_child(select)
	return select

func sound_control(parent: Node):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label = text(row, "Sound", 18)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size.x = 72
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var levels = [0.0, 0.2, 0.45, 0.75, 1.0]
	var nearest = 0
	for i in range(levels.size()):
		if absf(levels[i] - audio.volume) < absf(levels[nearest] - audio.volume):
			nearest = i
	var select = choice(row, ["Muted", "Quiet", "Balanced", "Loud", "Full"], nearest)
	var status = text(parent, "", 16, Color("ffbe91"))
	status.visible = false
	select.item_selected.connect(func(i):
		audio.set_volume(levels[i])
		status.visible = not profile.set_audio_volume(levels[i])
		status.text = profile.warning)

# Expand the canvas, then keep interactive content inside display cutout margins.
func safe_rect() -> Rect2:
	var view = get_viewport().get_visible_rect().size
	if OS.get_name() == "Android":
		var safe = DisplayServer.get_display_safe_area()
		var physical = Vector2(DisplayServer.window_get_size())
		if safe.size.x > 0 and safe.size.y > 0 and physical.x > 0 and physical.y > 0:
			return Rect2(Vector2(safe.position) * view / physical, Vector2(safe.size) * view / physical).grow(-16)
	return Rect2(Vector2.ZERO, view).grow(-20)

func layout_hud():
	var safe = safe_rect()
	telemetry_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	telemetry_back.position = safe.position
	telemetry_back.size = Vector2(safe.size.x, 84)
	for label in [telemetry, progress_label, notice]:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = Vector2(safe.size.x - 170, 30)
	telemetry.position = safe.position + Vector2(16, 10)
	progress_label.position = safe.position + Vector2(16, 44)
	notice.position = safe.position + Vector2(16, 98)
	notice.size.x = safe.size.x - 32
	mobile_pause.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mobile_pause.position = Vector2(safe.end.x - 120, safe.position.y + 12)
	mobile_pause.size = Vector2(104, 56)

func queue_layout():
	if relayout_pending or ui == null:
		return
	relayout_pending = true
	call_deferred("refresh_layout")

func refresh_layout():
	relayout_pending = false
	var safe = safe_rect()
	touch_controls.safe_bounds = safe
	layout_hud()
	if state == "MENU":
		if calibration_open:
			show_calibration()
		else:
			show_menu()
	elif state == "PAUSED":
		pause_run(last_pause_reason)
	elif state == "RESULTS":
		show_debrief()

func record_key(tier: int) -> String:
	var base = Course.PLANETS[planet].name + " / " + FlightModel.VEHICLES[vehicle].name
	return base if tier == 0 else base + " / " + Course.STAGES[tier].name

func unlocked_stage_count() -> int:
	var available = 1
	if float(profile.data.records.get(record_key(0), {}).get("best", 0)) >= 55.0:
		available = 2
	if float(profile.data.records.get(record_key(1), {}).get("best", 0)) >= 65.0:
		available = 3
	return available

func show_menu():
	state = "MENU"
	sync_flight_state()
	clear_overlay()
	var safe = safe_rect()
	touch_controls.safe_bounds = safe
	var width = minf(450, safe.size.x)
	var col = panel(overlay, Rect2(safe.position, Vector2(width, safe.size.y)), 0.96, true)
	text(col, "HORIZON SKY", 32, MINT)
	text(col, "World", 16, Color("a9bbc4"))
	var world_names = []
	for world in Course.PLANETS:
		world_names.append(world.name.capitalize())
	var world_select = choice(col, world_names, planet)
	world_select.item_selected.connect(func(i):
		planet = i
		stage = 0
		call_deferred("show_menu"))
	text(col, "Aircraft", 16, Color("a9bbc4"))
	var craft_names = []
	for v in FlightModel.VEHICLES:
		craft_names.append(v.name + " · " + v.role)
	var craft_select = choice(col, craft_names, vehicle)
	craft_select.item_selected.connect(func(i):
		vehicle = i
		stage = 0
		build_craft()
		flight.reset(vehicle)
		call_deferred("show_menu"))
	text(col, "Stage", 16, Color("a9bbc4"))
	stage = mini(stage, unlocked_stage_count() - 1)
	var stage_select = choice(col, ["1 · Foundations", "2 · Crosswind", "3 · Debris Run"], stage)
	for i in range(Course.STAGES.size()):
		stage_select.set_item_disabled(i, i >= unlocked_stage_count())
	stage_select.item_selected.connect(func(i):
		if i < unlocked_stage_count():
			stage = i
			course.build(planet, stage))
	var launch = button(col, "FLY", start_run)
	launch.custom_minimum_size.y = 56
	button(col, "Controls" if radio.touch_mode else "Controls · " + ("Keyboard" if radio.keyboard else "USB radio"), show_calibration)
	sound_control(col)
	if not profile.warning.is_empty():
		text(col, profile.warning, 16, Color("ffbe91"))
	text(col, "TEST BUILD · " + VERSION, 14, Color("8ca4b1"))
	if safe.size.x > 960:
		var log_width = minf(330, safe.size.x - width - 28)
		var info = panel(overlay, Rect2(safe.end.x - log_width, safe.position.y, log_width, 250), 0.82, true)
		text(info, "FLIGHT LOG", 18, MINT)
		for i in range(Course.STAGES.size()):
			var record = profile.data.records.get(record_key(i), {})
			var score = float(record.get("best", 0))
			var status = "Locked" if i >= unlocked_stage_count() else "%.0f / 100" % score
			text(info, "%d  %s · %s" % [i + 1, ["Foundations", "Crosswind", "Debris"][i], status], 18)
	course.build(planet, stage)
	flight.reset(vehicle)
	update_palette()
	update_camera(1.0)

func authority_name() -> String:
	if radio.touch_mode:
		return "Touch"
	if radio.keyboard:
		return "Keyboard"
	return Input.get_joy_name(radio.device) if radio.connected() else "Radio disconnected — select device again"

func show_calibration():
	if radio.touch_mode:
		show_touch_guide()
		return
	state = "MENU"
	sync_flight_state()
	hud.visible = false
	clear_overlay()
	calibration_open = true
	config_rows.clear()
	var view = get_viewport().get_visible_rect().size
	var width = minf(1060.0, view.x - 36.0)
	var col = panel(overlay, Rect2((view.x - width) * 0.5, 18, width, view.y - 36), 0.96, true)
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

func show_touch_guide():
	state = "MENU"
	sync_flight_state()
	hud.visible = false
	clear_overlay()
	var view = get_viewport().get_visible_rect().size
	var width = minf(760.0, view.x - 36.0)
	var col = panel(overlay, Rect2((view.x - width) * 0.5, 18, width, view.y - 36), 0.96, true)
	text(col, "TOUCH FLIGHT CONTROLS", 30, MINT)
	text(col, "Left: power ↑↓ · rudder ←→", 24)
	text(col, "Right: elevator ↑↓ · aileron ←→", 24)
	text(col, "Pull down to raise the nose. Power holds on release.", 20)
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
	if stage >= unlocked_stage_count():
		stage = 0
	if not radio.ready_to_fly():
		show_calibration()
		config_status.text = "Before launch: connect, calibrate, center roll/pitch/yaw, and lower throttle."
		return
	flight.reset(vehicle)
	radio.throttle = 0.35
	touch_controls.reset_for_run()
	radio.set_touch_command(touch_controls.command())
	next_gate = 0
	hits = 0
	streak = 0
	best_streak = 0
	accuracy_total = 0
	minimum_clearance = 999
	command_variation = 0
	last_command = Vector4.ZERO
	message = "STAGE %d · %s" % [stage + 1, Course.STAGES[stage].name]
	message_time = 5
	course.build(planet, stage)
	update_palette()
	state = "FLYING"
	recovering = false
	clear_overlay()
	hud.visible = true
	sync_flight_state()
	hud.flying = true
	update_camera(1.0)

func pause_run(reason: String):
	last_pause_reason = reason
	if state != "FLYING" and state != "PAUSED":
		return
	state = "PAUSED"
	sync_flight_state()
	clear_overlay()
	var view = get_viewport().get_visible_rect().size
	var width = minf(650.0, view.x - 40.0)
	var col = panel(overlay, Rect2((view.x - width) * 0.5, maxf(16, (view.y - 460) * 0.5), width, minf(460.0, view.y - 32.0)), 0.97, true)
	text(col, "PAUSED", 32, MINT)
	text(col, reason, 18)

	button(col, "Resume", resume_run)
	button(col, "Restart", start_run)
	sound_control(col)
	button(col, "Hangar", show_menu)

func resume_run():
	if not focus_ok or not radio.ready_to_fly():
		pause_run("Input not ready. Reconnect the same radio, center sticks,\nand lower throttle; or return to hangar for setup.")
		return
	state = "FLYING"
	recovering = false
	last_command = Vector4.ZERO
	clear_overlay()
	sync_flight_state()

func finish_run(reason: String, completed: bool):
	if state != "FLYING":
		return
	state = "RESULTS"
	sync_flight_state()
	audio.play_cue("complete" if completed else "impact")
	var precision = accuracy_total / Course.GATE_COUNT * 100.0
	var smoothness = clampf(100 - command_variation / maxf(flight.time, 1.0) * 6, 0, 100)
	var score = clampf(hits / float(Course.GATE_COUNT) * 65 + precision * 0.25 + smoothness * 0.1, 0, 100)
	if not completed:
		score *= 0.5
	last_result = {"score": snappedf(score, 0.1), "hits": hits, "precision": snappedf(precision, 0.1), "seconds": snappedf(flight.time, 0.1), "clearance": snappedf(minimum_clearance, 0.1), "smoothness": snappedf(smoothness, 0.1), "completed": completed, "stage": stage + 1, "streak": best_streak, "reason": reason.get_slice(".", 0)}
	profile.record(record_key(stage), last_result)
	show_debrief()

func show_debrief():
	clear_overlay()
	var safe = safe_rect()
	var width = minf(580, safe.size.x)
	var col = panel(overlay, Rect2(safe.get_center().x - width * 0.5, safe.position.y, width, safe.size.y), 0.97, true)
	text(col, "STAGE %02d · RESULT" % (stage + 1), 18, MINT)
	text(col, "%.0f / 100" % last_result.score, 44)
	text(col, str(last_result.get("reason", "Flight ended")), 22)
	text(col, "%d / %d gates · %.1f s" % [last_result.hits, Course.GATE_COUNT, last_result.seconds], 24)
	text(col, "Precision %.0f%% · Smoothness %.0f%%" % [last_result.precision, last_result.smoothness], 20)
	text(col, "Best streak %d · Clearance %.1f m" % [last_result.streak, last_result.clearance], 20)
	if not profile.warning.is_empty():
		text(col, profile.warning, 16, Color("ffbe91"))
	if stage + 1 < Course.STAGES.size() and stage + 1 < unlocked_stage_count():
		button(col, "Next stage", func():
			stage += 1
			start_run())
	button(col, "Fly again", start_run)
	button(col, "Hangar", show_menu)

func _physics_process(dt: float):
	if state != "FLYING":
		return
	if not radio.connected():
		recovering = true
		pause_run("Controller disconnected. No keyboard takeover.")
		return
	if radio.touch_mode:
		radio.set_touch_command(touch_controls.command())
	var command = radio.read(dt)
	if demo:
		# Automated visual smoke only, explicitly enabled by command-line flag.
		var target: Vector3 = course.gates[mini(next_gate, Course.GATE_COUNT - 1)]
		command = Vector4(clampf((target.x - flight.position.x) * 0.012 - flight.heading * 1.6, -1, 1), clampf((target.y - flight.position.y) * 0.018 - flight.pitch * 1.5, -1, 1), 0, 0.45)
	command_variation += (command - last_command).length()
	last_command = command
	var previous: Vector3 = flight.position
	flight.step(command, dt, course.wind_strength())
	course.update_hazards(dt)
	minimum_clearance = minf(minimum_clearance, flight.position.y - Course.ground_height(flight.position.x, flight.position.z))
	if course.collision(flight.position):
		finish_run("Debris impact. Scan ahead and leave a wider margin." if course.debris_collision(flight.position) else "Terrain contact. Reset and build clearance.", false)
		return
	if absf(flight.position.x) > 145 or flight.position.y > 180:
		finish_run("Outside training airspace. Keep the course in view.", false)
		return
	var distance = FlightModel.crossing_distance(previous, flight.position, course.gates[next_gate])
	if distance >= 0:
		var radius = course.gate_radius()
		var success = distance <= radius - 1.5
		if success:
			hits += 1
			streak += 1
			best_streak = maxi(best_streak, streak)
			accuracy_total += 1.0 - distance / radius
		else:
			streak = 0
		course.mark_gate(next_gate, success)
		audio.play_cue("pass" if success else "miss")
		next_gate += 1
		message = ("CENTERED" if distance < radius * 0.35 else "PASS") + "  /  STREAK %d" % streak if success else "MISSED"
		message_time = 2.0
		if next_gate == Course.GATE_COUNT:
			finish_run("Course complete. Make the next line cleaner.", true)
			return
	if flight.time > 180:
		finish_run("Session time limit reached. Try a more direct line.", false)
	hud.command = command
	hud.bank = flight.roll
	hud.pitch = flight.pitch
	hud.progress = float(next_gate) / float(Course.GATE_COUNT)

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
		audio.update_engine(last_command.w, flight.speed / FlightModel.VEHICLES[vehicle].max_speed, vehicle, dt)
		update_camera(dt)
		message_time -= dt
		telemetry.text = "%.0f m/s   ·   ALT %.0f m   ·   POWER %.0f%%" % [flight.speed, flight.position.y, last_command.w * 100]
		progress_label.text = "GATE %02d / %02d   ·   %d passed   ·   %.0f s" % [mini(next_gate + 1, Course.GATE_COUNT), Course.GATE_COUNT, hits, flight.time]
		if next_gate < course.gates.size():
			hud.target_visible = not camera.is_position_behind(course.gates[next_gate])
			hud.target_screen = camera.unproject_position(course.gates[next_gate]) if hud.target_visible else Vector2.ZERO
		notice.text = "STALL · Lower nose" if flight.stalled else (message if message_time > 0 else "")
	elif state == "MENU":
		update_camera(dt)
	if is_instance_valid(engine_flare):
		var thrust = last_command.w if state == "FLYING" else 0.28
		engine_flare.scale.y = 0.6 + thrust * 1.35 + sin(float(frames) * 0.34) * 0.08
	hud.queue_redraw()
	if not capture_path.is_empty() and frames == 30:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
	if exit_after > 0 and frames >= exit_after:
		request_quit()

func request_quit():
	if shutting_down:
		return
	shutting_down = true
	state = "EXITING"
	sync_flight_state()
	# Retire audio playback before engine teardown, including automated smoke exits.
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()

func update_camera(dt: float):
	craft.position = flight.position + (Vector3(20, 1, -8) if state == "MENU" else Vector3.ZERO)
	craft.rotation = Vector3(flight.pitch, -flight.heading, flight.roll)
	var offset = Vector3(-sin(flight.heading) * 17, 5, cos(flight.heading) * 17)
	if state == "MENU":
		offset = Vector3(13, 7, 19)
	var target = flight.position + offset
	camera.position = camera.position.lerp(target, clampf(dt * 5, 0, 1)) if dt < 1 else target
	camera.look_at(flight.position + flight.forward_vector() * 14 + Vector3.UP)

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.keycode == KEY_ESCAPE:
		if state == "FLYING":
			pause_run("Ready when you are.")
		elif state == "PAUSED":
			resume_run()
		elif state == "RESULTS" or calibration_open:
			show_menu()

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_ok = false
		if audio != null:
			audio.set_flying(false)
		if touch_controls != null:
			touch_controls.clear_gestures()
		if state == "FLYING":
			pause_run("Window lost focus. Resume when ready.")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_ok = true

func _device_changed(device: int, connected: bool):
	if not radio.keyboard and not radio.touch_mode and device == radio.device and not connected:
		radio.capturing = false
		if state == "FLYING":
			recovering = true
			pause_run("Controller disconnected. Reconnect and explicitly resume.")
	if calibration_open:
		show_calibration()
