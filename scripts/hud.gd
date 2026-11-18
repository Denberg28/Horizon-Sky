extends Control
## Lightweight responsive 2D flight symbology; no input or course authority.
var command = Vector4.ZERO
var bank = 0.0
var pitch = 0.0
var progress = 0.0
var target_screen = Vector2.ZERO
var target_visible = false
var flying = false
var show_input_monitors = true
var accent = Color("b4ffcc")

func _draw():
	if not flying or size.x < 200 or size.y < 200:
		return
	var mid = size * Vector2(0.5, 0.47)
	var white = Color(0.91, 0.98, 0.97, 0.72)
	var dim = Color(0.8, 0.94, 0.94, 0.25)
	# Roll-coupled artificial horizon and attitude reference.
	var direction = Vector2(cos(bank), sin(bank))
	var horizon = mid + Vector2(0, pitch * 92.0)
	draw_line(horizon - direction * 90, horizon + direction * 90, dim, 2.0, true)
	draw_line(mid - Vector2(46, 0), mid - Vector2(14, 0), white, 2.0, true)
	draw_line(mid + Vector2(14, 0), mid + Vector2(46, 0), white, 2.0, true)
	draw_line(mid + Vector2(0, -6), mid + Vector2(0, 8), white, 1.4, true)
	draw_circle(mid, 3.0, accent)
	# Screen-space next-gate cue is capped within safe HUD margins.
	if target_visible:
		var target = Vector2(clampf(target_screen.x, 34.0, size.x - 34.0), clampf(target_screen.y, 178.0, size.y - 44.0))
		draw_arc(target, 18.0, 0.0, TAU, 32, Color(accent, 0.75), 2.0, true)
		draw_line(target - Vector2(26, 0), target - Vector2(14, 0), accent, 1.6, true)
		draw_line(target + Vector2(14, 0), target + Vector2(26, 0), accent, 1.6, true)
	# Stage progress is a minimal unobtrusive footer.
	draw_rect(Rect2(24, size.y - 18, maxf(1, size.x - 48), 4), dim)
	draw_rect(Rect2(24, size.y - 18, maxf(0, size.x - 48) * clampf(progress, 0, 1), 4), accent)
	# Two stick monitors: yaw/throttle on left, roll/pitch on right.
	if size.x >= 650 and show_input_monitors:
		for i in range(2):
			var center = Vector2(size.x - 175 + i * 96, size.y - 91)
			draw_rect(Rect2(center - Vector2(33, 33), Vector2(66, 66)), Color(0.03, 0.09, 0.14, 0.48))
			draw_line(center - Vector2(29, 0), center + Vector2(29, 0), dim)
			draw_line(center - Vector2(0, 29), center + Vector2(0, 29), dim)
			var value = Vector2(command.z, 1.0 - command.w * 2.0) if i == 0 else Vector2(command.x, -command.y)
			draw_circle(center + value * 28, 4.0, accent)
