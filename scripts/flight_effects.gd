extends Node3D
## Bounded world-space acceleration ribbons and craft-specific power exhaust.
const MAX_SAMPLES = 64
const TRAIL_LIFETIME = 1.4
const SAMPLE_INTERVAL = 1.0 / 30.0
const TRIANGLE_ORDER = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
var active = false
var vehicle = 0
var span = 4.4
var samples: Array[Dictionary] = []
var ribbons: Array[MeshInstance3D] = []
var plumes: Array[MeshInstance3D] = []
var plume_root: Node3D
var plume_material: StandardMaterial3D
var trail_material: StandardMaterial3D
var engine_level = 0.0
var trail_level = 0.0
var phase = 0.0
var sample_clock = 0.0
var chain = 0
var was_emitting = false

func _ready():
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in range(2):
		var ribbon = MeshInstance3D.new()
		ribbon.mesh = ImmediateMesh.new()
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbon)
		ribbons.append(ribbon)
	plume_root = Node3D.new()
	add_child(plume_root)

func configure(kind: int, wing_span: float):
	vehicle = clampi(kind, 0, 2)
	span = wing_span
	for plume in plumes:
		plume_root.remove_child(plume)
		plume.queue_free()
	plumes.clear()
	plume_material = StandardMaterial3D.new()
	plume_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plume_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plume_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plume_material.emission_enabled = vehicle != 0
	for index in range(2 if vehicle == 2 else 1):
		var plume = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.015
		cone.bottom_radius = [0.16, 0.28, 0.32][vehicle]
		cone.height = 1.0
		cone.radial_segments = 8
		plume.mesh = cone
		plume.rotation_degrees.x = 90
		plume.material_override = plume_material
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume_root.add_child(plume)
		plumes.append(plume)
	reset()

func reset():
	samples.clear()
	engine_level = 0
	trail_level = 0
	phase = 0
	sample_clock = 0
	chain = 0
	was_emitting = false
	for ribbon in ribbons:
		ribbon.mesh.clear_surfaces()
	for plume in plumes:
		plume.visible = false

func set_active(enabled: bool, clear: bool = false):
	active = enabled
	visible = enabled
	if clear:
		reset()

func step(pose: Transform3D, speed: float, power: float, acceleration: float, cruise: float, maximum: float, dt: float):
	if not active or not is_finite(dt) or dt <= 0 or dt > 0.1 or not pose.origin.is_finite() or not pose.basis.is_finite() or not is_finite(cruise) or not is_finite(maximum) or not is_finite(speed) or not is_finite(power) or not is_finite(acceleration):
		return
	phase += dt
	plume_root.transform = pose
	engine_level = lerpf(engine_level, clampf(power, 0, 1), 1.0 - exp(-dt * 8))
	_update_plumes()
	var speed_fraction = clampf((speed - cruise * 0.9) / maxf(1, maximum - cruise * 0.9), 0, 1)
	var target = (0.35 + speed_fraction * 0.65) * smoothstep(0.15, 2.0, acceleration) if speed > cruise * 0.55 else 0.0
	trail_level = lerpf(trail_level, target, 1.0 - exp(-dt * 10))
	for point in samples:
		point.age += dt
	while not samples.is_empty() and samples[0].age >= TRAIL_LIFETIME:
		samples.pop_front()
	sample_clock += dt
	if sample_clock < SAMPLE_INTERVAL:
		return
	sample_clock = fmod(sample_clock, SAMPLE_INTERVAL)
	var emitting = target > 0.02 and trail_level > 0.02
	if emitting:
		if not was_emitting:
			chain += 1
		samples.append({"left": pose * Vector3(-span, 0, 1.7), "right": pose * Vector3(span, 0, 1.7), "axis": pose.basis.x.normalized(), "age": 0.0, "strength": trail_level, "chain": chain})
		if samples.size() > MAX_SAMPLES:
			samples.pop_front()
	was_emitting = emitting
	_rebuild_ribbons()

func _update_plumes():
	var length = lerpf([0.12, 0.25, 0.3][vehicle], [1.0, 2.8, 3.8][vehicle], engine_level)
	length *= 1.0 + sin(phase * 29) * 0.035 * engine_level
	var color = Color("d5e4db") if vehicle == 0 else Color("59b9ff").lerp(Color("f2fbff"), engine_level)
	color.a = engine_level * (0.16 if vehicle == 0 else 0.9)
	plume_material.albedo_color = color
	plume_material.emission = Color(color, 1.0)
	plume_material.emission_energy_multiplier = engine_level * 3.0
	for i in range(plumes.size()):
		var plume = plumes[i]
		plume.visible = engine_level > 0.02
		plume.position = Vector3((-0.65 if i == 0 else 0.65) if vehicle == 2 else 0, 0, 2.6 + length * 0.5)
		plume.scale = Vector3(0.55 + engine_level * 0.65, length, 0.55 + engine_level * 0.65)

func _rebuild_ribbons():
	for side in range(2):
		var mesh: ImmediateMesh = ribbons[side].mesh
		mesh.clear_surfaces()
		if samples.size() < 2:
			continue
		var key = "left" if side == 0 else "right"
		var started = false
		for i in range(1, samples.size()):
			var a = samples[i - 1]
			var b = samples[i]
			if a.chain != b.chain:
				continue
			if not started:
				mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, trail_material)
				started = true
			for vertex in TRIANGLE_ORDER:
				var point: Dictionary = a if vertex.x == 0 else b
				var fraction = clampf(point.age / TRAIL_LIFETIME, 0, 1)
				var alpha = pow(1.0 - fraction, 2) * point.strength * 0.75
				mesh.surface_set_color(Color(0.85, 0.95, 1.0, alpha))
				mesh.surface_add_vertex(point[key] + point.axis * float(vertex.y) * (0.12 + fraction * 0.18))
		if started:
			mesh.surface_end()
