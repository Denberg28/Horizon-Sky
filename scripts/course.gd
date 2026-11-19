extends Node3D
const PLANETS = [
	{"name": "TERRA", "subtitle": "Verdant passage", "lesson": "Read terrain. Hold a clean line.", "sky": Color("b9d7d9"), "ground": Color("548d79"), "rock": Color("355868"), "accent": Color("b4ffcc"), "wind": 0.0, "sky_top": Color("4a84ad"), "sky_horizon": Color("d9ece8"), "cloud": Color("f3f9fa")},
	{"name": "ARES", "subtitle": "The red escarpment", "lesson": "Anticipate turns. Correct for crosswind.", "sky": Color("d6a797"), "ground": Color("b76348"), "rock": Color("773e43"), "accent": Color("ffe0a6"), "wind": 3.0, "sky_top": Color("6a3d46"), "sky_horizon": Color("ebb698"), "cloud": Color("f0cbb4")},
	{"name": "EUROPA", "subtitle": "Blue silence", "lesson": "Manage momentum. Protect your clearance.", "sky": Color("172b48"), "ground": Color("81b9cf"), "rock": Color("385875"), "accent": Color("93ebff"), "wind": 1.0, "sky_top": Color("091224"), "sky_horizon": Color("2a5c85"), "cloud": Color("8dc5e8")}
]
const GATE_COUNT = 16
const RADIUS = 10.0
# Each stage preserves sixteen gates and the legacy save schema.
const STAGES = [
	{"name": "FOUNDATIONS", "subtitle": "Read the line", "brief": "Wide gates, steady conditions and basic terrain awareness.", "radius": 10.0},
	{"name": "CROSSWIND", "subtitle": "Anticipate drift", "brief": "Narrower gates, stronger drift and sharper changes of elevation.", "radius": 9.0},
	{"name": "DEBRIS RUN", "subtitle": "Precision under pressure", "brief": "Tight gates, moving polygon debris and demanding route geometry.", "radius": 8.0}
]
const PATTERNS = ["Weave", "Long arcs", "Climb run", "Chicane", "Rolling hills"]
var route_seed = 0
var pattern = 0
var stage = 0
var elapsed = 0.0
var hazards: Array[Dictionary] = []

func gate_radius() -> float:
	return float(STAGES[stage].radius)

func wind_strength() -> float:
	return float(PLANETS[planet].wind) + [0.0, 2.0, 3.5][stage]

var gates: Array[Vector3] = []
var rings: Array[MeshInstance3D] = []
var obstacles: Array[Dictionary] = []
var planet = 0
var root: Node3D

static func ground_height(x: float, z: float) -> float:
	return -1.0 + sin(z * 0.012) * 5.0 + maxf(0, absf(x) - 55.0) * 0.34

# Independent route RNG makes a displayed seed reproducible across scenery rebuilds.
static func generate_route(kind: int, tier: int, seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else 501 + kind + tier * 100
	var family = rng.randi_range(0, PATTERNS.size() - 1)
	var phase = rng.randf_range(-PI, PI) + kind * 0.35
	var amplitude = rng.randf_range(22, 36) + tier * 5 + kind * 3
	var cadence = [0.65, 0.29, 0.43, 1.05, 0.48][family]
	var points: Array[Vector3] = []
	var previous = Vector3(0, 45, -75)
	for i in range(GATE_COUNT):
		var x = sin(phase + i * cadence) * amplitude + rng.randf_range(-4, 4)
		var y = 45 + sin(i * 0.65 + phase) * (10 + tier * 3)
		if family == 2:
			y = 42 + sin(float(i) / (GATE_COUNT - 1) * PI) * (24 + tier * 3)
		elif family == 4:
			y = 48 + sin(i * 0.33 + phase) * 20
		var step_x = 13.0 + tier * 4
		var step_y = 7.0 + tier * 2
		var point = Vector3(move_toward(previous.x, x, step_x), move_toward(previous.y, y, step_y), previous.z - rng.randf_range(98, 126))
		if i == 0:
			point = Vector3(rng.randf_range(-4, 4), rng.randf_range(43, 47), -75)
		point.y = maxf(point.y, ground_height(point.x, point.z) + 24)
		points.append(point)
		previous = point
	return {"seed": rng.seed, "pattern": family, "gates": points}

func build(kind: int, tier: int = 0, seed_value: int = 0):
	planet = clampi(kind, 0, 2)
	stage = clampi(tier, 0, STAGES.size() - 1)
	elapsed = 0.0
	var route = generate_route(planet, stage, seed_value)
	route_seed = route.seed
	pattern = route.pattern
	hazards.clear()
	for child in get_children():
		child.queue_free()
	gates.clear()
	rings.clear()
	obstacles.clear()
	root = Node3D.new()
	add_child(root)
	var palette = PLANETS[planet]
	var terrain = SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng = RandomNumberGenerator.new()
	rng.seed = route_seed + 7919
	for zi in range(82):
		for xi in range(16):
			var x = -240.0 + xi * 30
			var z = 120.0 - zi * 26
			var points = [Vector3(x, ground_height(x, z), z), Vector3(x + 30, ground_height(x + 30, z), z), Vector3(x, ground_height(x, z - 26), z - 26), Vector3(x + 30, ground_height(x + 30, z - 26), z - 26)]
			for indices in [[0, 1, 2], [1, 3, 2]]:
				var color: Color = palette.ground.lightened(rng.randf_range(-0.12, 0.14))
				for index in indices:
					terrain.set_color(color)
					terrain.add_vertex(points[index])
	terrain.generate_normals()
	var land = MeshInstance3D.new()
	land.mesh = terrain.commit()
	var land_material = material(Color.WHITE)
	land_material.vertex_color_use_as_albedo = true
	land.material_override = land_material
	root.add_child(land)
	for i in range(GATE_COUNT):
		var gate: Vector3 = route.gates[i]
		gates.append(gate)
		var ring = MeshInstance3D.new()
		ring.mesh = ring_mesh(gate_radius(), 0.6, 24)
		ring.position = gate
		ring.material_override = material(palette.accent if i == 0 else palette.accent.darkened(0.55), true)
		root.add_child(ring)
		rings.append(ring)
		# Tall low-poly pylons flank the route; a readable corridor remains open.
		for side in [-1, 1]:
			var rock_pos = Vector3(gate.x + side * (25 + rng.randf_range(0, 18)), 0, gate.z - 35)
			var height = rng.randf_range(22, 50)
			var rock = MeshInstance3D.new()
			var radius = rng.randf_range(6, 11)
			rock.mesh = cone_mesh(radius, height, 5)
			rock.position = rock_pos + Vector3(0, ground_height(rock_pos.x, rock_pos.z) + height / 2, 0)
			rock.material_override = material(palette.rock.lightened(rng.randf_range(-0.12, 0.1)))
			root.add_child(rock)
			# Cone envelope plus craft clearance is used for contact.
			obstacles.append({"x": rock_pos.x, "z": rock_pos.z, "base": ground_height(rock_pos.x, rock_pos.z), "height": height, "radius": radius})
	# Distant silhouettes build scale without textures or external assets.
	for side in [-1, 1]:
		for i in range(25):
			var mountain = MeshInstance3D.new()
			var peak_radius = rng.randf_range(45, 90)
			var peak_height = rng.randf_range(65, 150)
			mountain.mesh = cone_mesh(peak_radius, peak_height, 4)
			mountain.position = Vector3(side * rng.randf_range(250, 320), peak_height / 2 - 5, 120 - i * 90)
			mountain.material_override = material(palette.rock.lightened(0.15))
			root.add_child(mountain)
	var cloud_material = material(palette.cloud)
	for i in range(18):
		var cluster = Node3D.new()
		cluster.position = Vector3(rng.randf_range(-240.0, 240.0), rng.randf_range(198.0, 255.0), rng.randf_range(-1900.0, 60.0))
		root.add_child(cluster)
		for puff_idx in range(3):
			var puff = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(rng.randf_range(26.0, 52.0), rng.randf_range(7.0, 14.0), rng.randf_range(18.0, 36.0))
			puff.mesh = mesh
			puff.position = Vector3((puff_idx - 1) * rng.randf_range(14.0, 24.0), rng.randf_range(-4.0, 5.0), rng.randf_range(-10.0, 10.0))
			puff.material_override = cloud_material
			cluster.add_child(puff)

	# Stage-three hazards share the route seed, so a retry keeps its obstacles.
	# Debris never spawns inside the gate plane; the pilot has room to anticipate it.
	if stage == 2:
		for i in range(GATE_COUNT - 1):
			var middle: Vector3 = gates[i].lerp(gates[i + 1], 0.5)
			var debris = MeshInstance3D.new()
			var shape = SphereMesh.new()
			shape.radius = rng.randf_range(3.8, 5.2)
			shape.height = shape.radius * 2
			shape.radial_segments = 7
			shape.rings = 3
			debris.mesh = shape
			debris.material_override = material(palette.rock.lightened(0.32))
			root.add_child(debris)
			var center = middle + Vector3(12.0 if i % 2 == 0 else -12.0, 2.5, 0)
			var obstacle = {"mesh": debris, "center": center, "phase": rng.randf_range(0, TAU), "radius": shape.radius, "frequency": rng.randf_range(0.65, 0.95), "sweep": rng.randf_range(8, 12)}
			hazards.append(obstacle)
		update_hazards(0.0)

func update_hazards(dt: float):
	if stage != 2:
		return
	elapsed += maxf(0.0, dt)
	for hazard in hazards:
		var debris: MeshInstance3D = hazard.mesh
		var center: Vector3 = hazard.center
		debris.position = center + Vector3(sin(elapsed * hazard.frequency + hazard.phase) * hazard.sweep, cos(elapsed * 0.65 + hazard.phase) * 2.5, 0)
		debris.rotation.y = elapsed * 0.22 + hazard.phase

func debris_collision(position: Vector3) -> bool:
	for hazard in hazards:
		var debris: MeshInstance3D = hazard.mesh
		if position.distance_to(debris.position) < float(hazard.radius) + 2.0:
			return true
	return false

func mark_gate(index: int, success: bool):
	rings[index].material_override = material(Color("72f4b6") if success else Color("fa785e"), true)
	if index + 1 < rings.size():
		rings[index + 1].material_override = material(PLANETS[planet].accent, true)

func collision(position: Vector3) -> bool:
	if position.y < ground_height(position.x, position.z) + 2.0 or debris_collision(position):
		return true
	for obstacle in obstacles:
		var fraction = clampf((position.y - obstacle.base) / obstacle.height, 0, 1)
		var envelope = obstacle.radius * (1.0 - fraction) + 1.5
		if position.y < obstacle.base + obstacle.height + 1.5 and Vector2(position.x - obstacle.x, position.z - obstacle.z).length() < envelope:
			return true
	return false

static func cone_mesh(radius: float, height: float, sides: int) -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sides):
		var a = TAU * i / sides
		var b = TAU * (i + 1) / sides
		for point in [Vector3(cos(a) * radius, -height / 2, sin(a) * radius), Vector3(0, height / 2, 0), Vector3(cos(b) * radius, -height / 2, sin(b) * radius)]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

static func ring_mesh(radius: float, width: float, segments: int) -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a = i * TAU / segments
		var b = (i + 1) * TAU / segments
		var points = [Vector3(cos(a), sin(a), 0) * radius, Vector3(cos(b), sin(b), 0) * radius, Vector3(cos(a), sin(a), 0) * (radius + width), Vector3(cos(b), sin(b), 0) * (radius + width)]
		for n in [0, 2, 1, 1, 2, 3]:
			surface.add_vertex(points[n])
	surface.generate_normals()
	return surface.commit()

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.roughness = 0.9
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result
