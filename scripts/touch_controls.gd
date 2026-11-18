extends Control
## Android touch pads. Owns gestures, not the flight model or selected authority.
const RADIUS = 78.0
var left_id = -1
var right_id = -1
var yaw = 0.0
var throttle = 0.35
var roll = 0.0
var pitch = 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func left_center() -> Vector2:
	return Vector2(132.0, size.y - 121.0)

func right_center() -> Vector2:
	return Vector2(size.x - 132.0, size.y - 121.0)

func command() -> Vector4:
	return Vector4(roll, pitch, yaw, throttle)

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
			yaw = clampf((pos.x - left_center().x) / RADIUS, -1, 1)
			throttle = clampf(0.5 - (pos.y - left_center().y) / (2.0 * RADIUS), 0, 1)
		elif right_id == index:
			roll = clampf((pos.x - right_center().x) / RADIUS, -1, 1)
			pitch = clampf((pos.y - right_center().y) / RADIUS, -1, 1)
		elif left_id == -1 and pos.distance_to(left_center()) <= RADIUS * 1.4:
			left_id = index
			return touch(index, true, pos)
		elif right_id == -1 and pos.distance_to(right_center()) <= RADIUS * 1.4:
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
		if touch(event.index, event.pressed, event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if touch(event.index, true, event.position):
			get_viewport().set_input_as_handled()

func _draw():
	if not visible:
		return
	for pad in range(2):
		var center = left_center() if pad == 0 else right_center()
		var axis = Vector2(yaw, 1.0 - throttle * 2.0) if pad == 0 else Vector2(roll, pitch)
		draw_circle(center, RADIUS + 14, Color(0.04, 0.13, 0.18, 0.35))
		draw_arc(center, RADIUS, 0.0, TAU, 40, Color(0.75, 0.98, 0.84, 0.7), 2.0, true)
		draw_line(center - Vector2(RADIUS, 0), center + Vector2(RADIUS, 0), Color(1, 1, 1, 0.25), 1.0, true)
		draw_line(center - Vector2(0, RADIUS), center + Vector2(0, RADIUS), Color(1, 1, 1, 0.25), 1.0, true)
		draw_circle(center + axis * RADIUS, 20, Color(0.71, 1.0, 0.8, 0.85))
