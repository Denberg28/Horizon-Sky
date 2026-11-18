extends RefCounted
## Reduced-order force model: metres, seconds, radians. Original, not an RC8 engine port.
const GRAVITY = 9.81
const DENSITY = 1.225
# Handling tuning: trainer stability, jet wing loading/spool, spacecraft thrusters.
const VEHICLES = [
	{"name": "Kestrel", "role": "Trainer", "cruise_speed": 32.0, "stall_speed": 14.0, "max_speed": 55.0, "mass": 8.0, "area": 0.5, "cl_alpha": 4.8, "cl_max": 1.35, "cd0": 0.045, "induced_drag": 0.07, "stall_angle": 0.28, "roll_rate": 1.5, "pitch_rate": 0.7, "yaw_rate": 0.35, "stability": 2.3, "dihedral": 0.45, "engine_response": 5.0, "side_damping": 2.8},
	{"name": "Peregrine", "role": "Jet", "cruise_speed": 50.0, "stall_speed": 25.0, "max_speed": 88.0, "mass": 14.0, "area": 0.32, "cl_alpha": 3.8, "cl_max": 1.15, "cd0": 0.03, "induced_drag": 0.08, "stall_angle": 0.23, "roll_rate": 2.8, "pitch_rate": 1.0, "yaw_rate": 0.22, "stability": 1.4, "dihedral": 0.025, "engine_response": 1.3, "side_damping": 3.8},
	{"name": "Nomad", "role": "Spacecraft", "cruise_speed": 30.0, "max_speed": 64.0, "roll_rate": 1.6, "pitch_rate": 0.9, "yaw_rate": 0.8}
]
var position = Vector3(0, 45, 30)
var pitch = 0.0
var roll = 0.0
var heading = 0.0
var velocity = Vector3.ZERO
var speed = 32.0
var time = 0.0
var vehicle = 0
var angular_velocity = Vector3.ZERO
var engine_power = 0.35
var angle_of_attack = 0.0
var stalled = false
var lift_acceleration = 0.0
var longitudinal_acceleration = 0.0

func reset(kind: int):
	vehicle = clampi(kind, 0, 2)
	position = Vector3(0, 45, 30)
	pitch = 0.0
	roll = 0.0
	heading = 0.0
	speed = VEHICLES[vehicle].cruise_speed
	velocity = Vector3(0, 0, -speed)
	time = 0.0
	angular_velocity = Vector3.ZERO
	engine_power = 0.35
	angle_of_attack = 0.0
	stalled = false
	lift_acceleration = 0.0
	longitudinal_acceleration = 0.0

func forward_vector() -> Vector3:
	return Vector3(sin(heading) * cos(pitch), sin(pitch), -cos(heading) * cos(pitch))

func step(command: Vector4, dt: float, wind: float = 0.0):
	if not is_finite(dt) or dt <= 0.0 or dt > 0.1 or not command.is_finite() or not is_finite(wind):
		return
	var c = command.clamp(Vector4(-1, -1, -1, 0), Vector4.ONE)
	var previous_speed = velocity.length()
	if vehicle == 2:
		_step_space(c, dt)
	else:
		_step_aircraft(c, dt, wind)
	position += velocity * dt
	speed = velocity.length()
	longitudinal_acceleration = (speed - previous_speed) / dt
	time += dt

func _step_aircraft(c: Vector4, dt: float, wind: float):
	var v = VEHICLES[vehicle]
	var wind_velocity = Vector3(sin(time * 0.7) * wind, 0, 0)
	var air_velocity = velocity - wind_velocity
	var airspeed = maxf(air_velocity.length(), 0.1)
	var flow = air_velocity / airspeed
	var flight_path = asin(clampf(flow.y, -1, 1))
	angle_of_attack = pitch - flight_path
	stalled = absf(angle_of_attack) > v.stall_angle or airspeed < v.stall_speed
	# Dynamic pressure limits surface authority; neutral damps rates, not velocity.
	var authority = clampf(pow(airspeed / v.cruise_speed, 2), 0.08, 1.5)
	var flow_heading = atan2(air_velocity.x, -air_velocity.z)
	var targets = Vector3(c.y * v.pitch_rate * authority - angle_of_attack * v.stability * authority,
		c.z * v.yaw_rate * authority + wrapf(flow_heading - heading, -PI, PI) * 2.0,
		-c.x * v.roll_rate * authority - roll * v.dihedral * (1.0 - absf(c.x)))
	angular_velocity = angular_velocity.lerp(targets, 1.0 - exp(-dt * 12.0))
	pitch = clampf(pitch + angular_velocity.x * dt, -1.3, 1.3)
	heading = wrapf(heading + angular_velocity.y * dt, -PI, PI)
	roll = wrapf(roll + angular_velocity.z * dt, -PI, PI)
	var spool = v.engine_response if c.w > engine_power else maxf(v.engine_response, 3.0)
	engine_power = lerpf(engine_power, c.w, 1.0 - exp(-spool * dt))
	# Trim at cruise / 35% power; power changes energy, elevator changes AoA.
	var trim_q = 0.5 * DENSITY * v.cruise_speed * v.cruise_speed
	var trim_cl = v.mass * GRAVITY / (trim_q * v.area)
	var max_thrust = trim_q * v.area * (v.cd0 + v.induced_drag * trim_cl * trim_cl) / 0.35
	var cl = clampf(trim_cl + v.cl_alpha * angle_of_attack, -v.cl_max, v.cl_max)
	var separation = maxf(0, absf(angle_of_attack) - v.stall_angle)
	cl *= maxf(0.12, 1.0 - separation * 3.5)
	var q_area = 0.5 * DENSITY * airspeed * airspeed * v.area
	var idle_drag = (0.025 if vehicle == 0 else 0.018) * clampf((0.35 - engine_power) / 0.35, 0, 1)
	var cd = v.cd0 + v.induced_drag * cl * cl + separation * 0.9 + idle_drag
	var unbanked_up = (Vector3.UP - flow * flow.y).normalized()
	var flow_right = flow.cross(Vector3.UP).normalized()
	var lift_direction = unbanked_up * cos(roll) - flow_right * sin(roll)
	lift_acceleration = q_area * cl / v.mass
	var body_right = Vector3(cos(heading), 0, sin(heading))
	var side_slip = air_velocity.dot(body_right)
	var acceleration = Vector3.DOWN * GRAVITY + lift_direction * lift_acceleration
	acceleration += forward_vector() * ((engine_power + maxf(0, engine_power - 0.35) * 0.8) * max_thrust / v.mass) - flow * (q_area * cd / v.mass)
	acceleration -= body_right * side_slip * v.side_damping
	velocity = (velocity + acceleration * dt).limit_length(v.max_speed)

func _step_space(c: Vector4, dt: float):
	var v = VEHICLES[vehicle]
	angular_velocity = angular_velocity.lerp(Vector3(c.y * v.pitch_rate, c.z * v.yaw_rate, -c.x * v.roll_rate), 1.0 - exp(-dt * 9.0))
	pitch = clampf(pitch + angular_velocity.x * dt, -1.3, 1.3)
	heading = wrapf(heading + angular_velocity.y * dt, -PI, PI)
	roll = wrapf(roll + angular_velocity.z * dt, -PI, PI)
	engine_power = c.w
	# Assisted spacecraft cruise: throttle sets axial speed; RCS brakes at low power.
	var forward = forward_vector()
	var target_speed = lerpf(0, v.cruise_speed, c.w / 0.35) if c.w <= 0.35 else lerpf(v.cruise_speed, v.max_speed, (c.w - 0.35) / 0.65)
	var axial_speed = velocity.dot(forward)
	var axial_acceleration = clampf((target_speed - axial_speed) * 2.0, -18, 14)
	var sideways = velocity - forward * axial_speed
	velocity = (velocity + (forward * axial_acceleration - sideways * 0.9) * dt).limit_length(v.max_speed)
	stalled = false
	lift_acceleration = 0

static func crossing_distance(previous: Vector3, current: Vector3, gate: Vector3) -> float:
	if previous.z > gate.z and current.z <= gate.z:
		var fraction = (previous.z - gate.z) / (previous.z - current.z)
		var at_gate = previous.lerp(current, fraction)
		return Vector2(at_gate.x - gate.x, at_gate.y - gate.y).length()
	return -1.0
