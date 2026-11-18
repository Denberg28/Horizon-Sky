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
var airspeed = 0.0
var altitude = 0.0
var vertical_speed = 0.0
var heading = 0.0
var acceleration = 0.0
var safe_bounds = Rect2()
var accent = Color("b4ffcc")

func _draw():
	if not flying or size.x < 200 or size.y < 200:
		return
	var mid = size * Vector2(0.5, 0.47)
	var white = Color(0.91, 0.98, 0.97, 0.72)
	var dim = Color(0.8, 0.94, 0.94, 0.25)
	# Keep the flight-path aim clear; attitude instruments live below the scene.

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
	draw_instruments()
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

# Lower-center fighter-style panel: compass, attitude, speed/altitude and power.
func instrument_rect() -> Rect2:
	var area = safe_bounds if safe_bounds.size.x > 0 else Rect2(Vector2.ZERO, size)
	var width = minf(380, area.size.x * 0.34)
	return Rect2(area.get_center().x - width * 0.5, area.end.y - 184, width, 148)

func hud_text(value: String, at: Vector2, font_size: int, color: Color):
	var font = ThemeDB.fallback_font
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02, 0.07, 0.10, 0.95))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_instruments():
	var rect = instrument_rect()
	var center = rect.get_center()
	var glow = Color("b4ffcc")
	var pale = Color("e4fff2")
	draw_rect(rect, Color(0.025, 0.08, 0.11, 0.62))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward = (center - corner).sign()
		draw_line(corner, corner + Vector2(inward.x * 18, 0), glow, 2, true)
		draw_line(corner, corner + Vector2(0, inward.y * 18), glow, 2, true)
	var degrees = fposmod(rad_to_deg(heading), 360)
	for mark in [-1, 0, 1]:
		var at = Vector2(center.x + mark * 55, rect.position.y + 14)
		draw_line(at, at + Vector2(0, 6 if mark != 0 else 10), glow, 1.5, true)
		hud_text("%03d" % int(fposmod(degrees + mark * 20, 360)), at + Vector2(-14, 24), 14, pale)
	var attitude = center + Vector2(0, 6)
	var horizontal = Vector2(cos(bank), sin(bank))
	var vertical = Vector2(-horizontal.y, horizontal.x)
	for level in [-20, -10, 0, 10, 20]:
		var rung = attitude + vertical * clampf((deg_to_rad(level) - pitch) * 65, -28, 28)
		var half = 27 if level == 0 else 15
		draw_line(rung - horizontal * half, rung + horizontal * half, Color(glow, 0.7), 1.5, true)
	draw_line(attitude - Vector2(32, 0), attitude - Vector2(10, 0), pale, 2, true)
	draw_line(attitude + Vector2(10, 0), attitude + Vector2(32, 0), pale, 2, true)
	draw_circle(attitude, 2.5, pale)
	hud_text("SPD", rect.position + Vector2(14, 49), 13, glow)
	hud_text("%.0f" % airspeed, rect.position + Vector2(12, 78), 26, pale)
	hud_text("m/s", rect.position + Vector2(14, 97), 13, glow)
	hud_text("ALT", Vector2(rect.end.x - 63, rect.position.y + 49), 13, glow)
	hud_text("%.0f" % altitude, Vector2(rect.end.x - 65, rect.position.y + 78), 26, pale)
	hud_text("m", Vector2(rect.end.x - 63, rect.position.y + 97), 13, glow)
	hud_text("PWR %02d%%   V/S %+.1f" % [roundi(command.w * 100), vertical_speed], rect.position + Vector2(14, 124), 16, pale)
	hud_text("%+.1f m/s²" % acceleration, Vector2(rect.end.x - 102, rect.position.y + 124), 14, glow)
