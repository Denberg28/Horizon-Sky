extends Control
var command = Vector4.ZERO
var bank = 0.0
var flying = false
var accent = Color("b4ffcc")

func _draw():
	if not flying:
		return
	var mid = size * Vector2(0.5, 0.46)
	draw_arc(mid, 21, PI * 0.15, PI * 0.85, 18, Color(1, 1, 1, 0.65), 1.2, true)
	draw_line(mid - Vector2(40, 0), mid - Vector2(11, 0), Color(1, 1, 1, 0.7), 1.2, true)
	draw_line(mid + Vector2(11, 0), mid + Vector2(40, 0), Color(1, 1, 1, 0.7), 1.2, true)
	draw_circle(mid, 2, accent)
	# Two familiar stick monitors keep radio feedback visible without clutter.
	for i in range(2):
		var center = Vector2(size.x - 190 + i * 105, size.y - 90)
		draw_rect(Rect2(center - Vector2(35, 35), Vector2(70, 70)), Color(0.03, 0.09, 0.14, 0.45))
		draw_line(center - Vector2(29, 0), center + Vector2(29, 0), Color(1, 1, 1, 0.3))
		draw_line(center - Vector2(0, 29), center + Vector2(0, 29), Color(1, 1, 1, 0.3))
		var value = Vector2(command.z, 1 - command.w * 2) if i == 0 else Vector2(command.x, -command.y)
		draw_circle(center + value * 29, 4, accent)
