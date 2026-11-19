extends RefCounted
## Mode 2 semantics: (aileron right X, elevator right Y, rudder left X, throttle left Y).
## USB HID axis indices vary. Select and calibrate each axis; never auto-fallback.
## One selected input authority. No automatic fallback or resume.
const CHANNELS = ["Aileron / right X", "Elevator / right Y", "Rudder / left X", "Throttle / left Y"]
var device = -1
var keyboard = true
var touch_mode = false
var touch_command = Vector4(0, 0, 0, 0.35)
var mapping: Array = []
var captured_min: Array = []
var captured_max: Array = []
var capturing = false
var calibrated = false
var throttle = 0.35
var guid = ""
var signature = ""

func _init():
	defaults()

func defaults():
	mapping = []
	for axis in range(4):
		mapping.append({"axis": axis, "min": -1.0, "center": 0.0, "max": 1.0, "invert": axis == 1, "deadzone": 0.04, "expo": 0.0, "rate": 1.0})
	calibrated = false

func apply_hall_gimbal_tuning(high_rate: bool = false):
	var deadzones = [0.01, 0.01, 0.015, 0.0]
	var expos = [0.25, 0.25, 0.20, 0.0]
	var rates = [1.15 if high_rate else 1.0, 1.15 if high_rate else 1.0, 1.10 if high_rate else 1.0, 1.0]
	for i in range(mini(mapping.size(), 4)):
		mapping[i]["deadzone"] = deadzones[i]
		mapping[i]["expo"] = expos[i]
		mapping[i]["rate"] = rates[i]

func select_touch():
	keyboard = false
	touch_mode = true
	device = -1
	calibrated = false
	touch_command = Vector4(0, 0, 0, 0.35)

func select_keyboard():
	keyboard = true
	touch_mode = false
	device = -1
	calibrated = false

func set_touch_command(value: Vector4):
	if touch_mode and value.is_finite():
		touch_command = value.clamp(Vector4(-1, -1, -1, 0), Vector4.ONE)

func select_radio(id: int):
	touch_mode = false
	keyboard = false
	device = id
	guid = Input.get_joy_guid(id) if id in Input.get_connected_joypads() else ""
	signature = guid + ":" + Input.get_joy_name(id) if id in Input.get_connected_joypads() else ""
	defaults()

func connected() -> bool:
	return touch_mode or keyboard or (device in Input.get_connected_joypads() and Input.get_joy_guid(device) == guid and guid + ":" + Input.get_joy_name(device) == signature)

func valid_mapping(candidate) -> bool:
	if not candidate is Array or candidate.size() != 4:
		return false
	var used = []
	for m in candidate:
		if not m is Dictionary:
			return false
		for key in ["axis", "min", "center", "max", "deadzone", "invert"]:
			if not m.has(key):
				return false
		if not (m.axis is float or m.axis is int) or int(m.axis) != m.axis or int(m.axis) < 0 or int(m.axis) >= JOY_AXIS_MAX or int(m.axis) in used:
			return false
		used.append(int(m.axis))
		if not m.invert is bool:
			return false
		for key in ["min", "center", "max", "deadzone"]:
			if not (m[key] is float or m[key] is int) or not is_finite(m[key]):
				return false
		if m.min < -1.01 or m.max > 1.01 or m.center - m.min < 0.15 or m.max - m.center < 0.15 or m.deadzone < 0 or m.deadzone > 0.25:
			return false
		if m.has("expo"):
			if not (m.expo is float or m.expo is int) or not is_finite(m.expo) or m.expo < 0.0 or m.expo > 0.85:
				return false
		if m.has("rate"):
			if not (m.rate is float or m.rate is int) or not is_finite(m.rate) or m.rate < 0.35 or m.rate > 1.5:
				return false
	return true

static func normalized(raw: float, m: Dictionary, throttle_axis: bool = false) -> float:
	if not is_finite(raw):
		return 0.0
	if throttle_axis:
		var value = clampf((raw - m.min) / maxf(0.01, m.max - m.min), 0, 1)
		return 1.0 - value if m.invert else value
	var centered: float = raw - m.center
	var span: float = m.max - m.center if centered >= 0 else m.center - m.min
	var value = clampf(centered / maxf(0.01, span), -1, 1)
	value = signf(value) * maxf(0, (absf(value) - m.deadzone) / (1.0 - m.deadzone))
	var expo: float = clampf(float(m.get("expo", 0.0)), 0.0, 0.85)
	var rate: float = clampf(float(m.get("rate", 1.0)), 0.35, 1.5)
	value = value * ((1.0 - expo) + expo * value * value)
	value = clampf(value * rate, -1.0, 1.0)
	return -value if m.invert else value

func read(dt: float) -> Vector4:
	if not connected():
		return Vector4.ZERO
	if touch_mode:
		return touch_command
	if keyboard:
		throttle = clampf(throttle + (float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))) * dt * 0.4, 0, 1)
		# OR aliases before subtracting: duplicate directions never double output;
		# opposing directions cancel even when mixed across the two key sets.
		var right = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
		var left = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
		var nose_up = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
		var nose_down = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
		var yaw = float(Input.is_physical_key_pressed(KEY_C)) - float(Input.is_physical_key_pressed(KEY_Z))
		return Vector4(float(right) - float(left), float(nose_up) - float(nose_down), yaw, throttle)
	var values = Vector4.ZERO
	for i in range(4):
		values[i] = normalized(Input.get_joy_axis(device, int(mapping[i].axis)), mapping[i], i == 3)
	return values

func begin_capture():
	captured_min = [1.0, 1.0, 1.0, 1.0]
	captured_max = [-1.0, -1.0, -1.0, -1.0]
	capturing = true
	calibrated = false

func sample_capture():
	if not capturing or not connected():
		return
	for i in range(4):
		var value = Input.get_joy_axis(device, int(mapping[i].axis))
		captured_min[i] = minf(captured_min[i], value)
		captured_max[i] = maxf(captured_max[i], value)

func finish_capture() -> bool:
	capturing = false
	if not connected():
		return false
	var candidate = mapping.duplicate(true)
	for i in range(4):
		candidate[i].min = captured_min[i]
		candidate[i].max = captured_max[i]
		candidate[i].center = Input.get_joy_axis(device, int(candidate[i].axis)) if i < 3 else (captured_min[i] + captured_max[i]) / 2.0
	if not valid_mapping(candidate):
		return false
	mapping = candidate
	calibrated = true
	return true

func ready_to_fly() -> bool:
	if touch_mode:
		return true
	if keyboard:
		return true
	if not connected() or not calibrated or not valid_mapping(mapping):
		return false
	var c = read(0)
	return absf(c.x) < 0.12 and absf(c.y) < 0.12 and absf(c.z) < 0.12 and c.w < 0.12
