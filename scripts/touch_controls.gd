extends Control
## Two independent line sticks: generous rectangular hit areas match visible travel.
const RADIUS = 90.0
var safe_bounds = Rect2()
var left_id = -1
var right_id = -1
var yaw = 0.0
var throttle = 0.35
var roll = 0.0
var pitch = 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bounds() -> Rect2:
	return safe_bounds if safe_bounds.size.x > 0 else Rect2(Vector2.ZERO, size)

func travel() -> float:
	return clampf(bounds().size.y * 0.145, 64, 100)

func left_center() -> Vector2:
	var area = bounds()
	return Vector2(area.position.x + minf(area.size.x * 0.17, 180), area.end.y - travel() - 36)

func right_center() -> Vector2:
	var area = bounds()
	return Vector2(area.end.x - minf(area.size.x * 0.17, 180), area.end.y - travel() - 36)

func command() -> Vector4:
	return Vector4(roll, pitch, yaw, throttle)

func reset_for_run():
	throttle = 0.35
	clear_gestures()

func clear_gestures():
	left_id = -1
	right_id = -1
	yaw = 0.0
	roll = 0.0
	pitch = 0.0
	queue_redraw()

func touch(index: int, pressed: bool, pos: Vector2) -> bool:
	if pressed:
		if left_id == index:
			yaw = clampf((pos.x - left_center().x) / travel(), -1, 1)
			throttle = clampf(0.5 - (pos.y - left_center().y) / (2.0 * travel()), 0, 1)
		elif right_id == index:
			roll = clampf((pos.x - right_center().x) / travel(), -1, 1)
			pitch = clampf((pos.y - right_center().y) / travel(), -1, 1)
		elif left_id == -1 and Rect2(left_center() - Vector2.ONE * (travel() + 24), Vector2.ONE * (travel() + 24) * 2).has_point(pos):
			left_id = index
			return touch(index, true, pos)
		elif right_id == -1 and Rect2(right_center() - Vector2.ONE * (travel() + 24), Vector2.ONE * (travel() + 24) * 2).has_point(pos):
			right_id = index
			return touch(index, true, pos)
		else:
			return false
	else:
		if index == left_id:
			left_id = -1
			yaw = 0.0
		elif index == right_id:
			right_id = -1
			roll = 0.0
			pitch = 0.0
		else:
			return false
	queue_redraw()
	return true

func _input(event: InputEvent):
	if not visible:
		return
	if event is InputEventScreenTouch:
		if touch(event.index, event.pressed and not event.canceled, event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index in [left_id, right_id]:
		if touch(event.index, true, event.position):
			get_viewport().set_input_as_handled()

# Gradient cross-lines, endpoint ticks and a small position light; no circular dial.
func _draw():
	if not visible:
		return
	var t = travel()
	var ink = Color(0.02, 0.07, 0.11, 0.8)
	var light = Color("9beeff")
	for pad in range(2):
		var center = left_center() if pad == 0 else right_center()
		var axis = Vector2(yaw, 1.0 - throttle * 2.0) if pad == 0 else Vector2(roll, pitch)
		for direction in [Vector2.RIGHT, Vector2.DOWN]:
			draw_line(center - direction * t, center + direction * t, ink, 5, true)
			for segment in range(20):
				var start = -1.0 + float(segment) * 0.1
				var alpha = 0.3 + (1.0 - absf(start)) * 0.55
				draw_line(center + direction * t * start, center + direction * t * (start + 0.1), Color(light, alpha), 2, true)
			var cross = Vector2(-direction.y, direction.x)
			for tick in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var at = center + direction * tick * t
				draw_line(at - cross * 5, at + cross * 5, ink, 4, true)
				draw_line(at - cross * 4, at + cross * 4, Color(light, 0.8), 1.4, true)
		var marker = center + axis * t
		draw_line(center, marker, Color(light, 0.65), 2.0, true)
		draw_circle(marker, 9, ink)
		draw_circle(marker, 5, light)
		draw_circle(marker, 2, Color.WHITE)
		var caption = "POWER / YAW" if pad == 0 else "PITCH / BANK"
		var font = ThemeDB.fallback_font
		var caption_pos = center + Vector2(-font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, t + 24)
		draw_string_outline(font, caption_pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, ink)
		draw_string(font, caption_pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9f6f8"))
