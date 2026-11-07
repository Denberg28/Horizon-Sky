extends RefCounted
## Deterministic arcade flight model. Units: metres, seconds, radians.
const VEHICLES = [
	{"name": "Kestrel", "role": "TRAINER / forgiving", "min_speed": 24.0, "max_speed": 55.0, "response": 3.0, "roll_rate": 1.4, "pitch_rate": 0.65, "yaw_rate": 0.42, "inertia": 3.5},
	{"name": "Peregrine", "role": "JET / fast precision", "min_speed": 38.0, "max_speed": 88.0, "response": 5.0, "roll_rate": 2.0, "pitch_rate": 0.85, "yaw_rate": 0.3, "inertia": 2.5},
	{"name": "Nomad", "role": "SPACECRAFT / momentum", "min_speed": 18.0, "max_speed": 64.0, "response": 1.5, "roll_rate": 1.0, "pitch_rate": 0.8, "yaw_rate": 0.6, "inertia": 0.9}
]
var position = Vector3(0, 45, 30)
var pitch = 0.0
var roll = 0.0
var heading = 0.0
var velocity = Vector3.ZERO
var speed = 35.0
var time = 0.0
var vehicle = 0

func reset(kind: int):
	vehicle = clampi(kind, 0, 2)
	position = Vector3(0, 45, 30)
	pitch = 0.0
	roll = 0.0
	heading = 0.0
	speed = VEHICLES[vehicle].min_speed + 8.0
	velocity = Vector3(0, 0, -speed)
	time = 0.0

func step(command: Vector4, dt: float, wind: float = 0.0):
	if dt <= 0.0 or dt > 0.1 or not command.is_finite():
		return
	var v = VEHICLES[vehicle]
	var c = command.clamp(Vector4(-1, -1, -1, 0), Vector4.ONE)
	var response: float = 1.0 - exp(-v.response * dt)
	# Roll is an attitude command, pitch and rudder are rates. A bank causes a turn.
	roll = lerpf(roll, -c.x * 1.1, response)
	pitch = clampf(pitch + c.y * v.pitch_rate * dt, -0.65, 0.65)
	heading = clampf(heading + (c.z * v.yaw_rate - sin(roll) * 0.38) * dt, -1.0, 1.0)
	speed = lerpf(speed, lerpf(v.min_speed, v.max_speed, c.w), 1.0 - exp(-dt * 1.8))
	var forward = Vector3(sin(heading) * cos(pitch), sin(pitch), -cos(heading) * cos(pitch))
	var target_velocity: Vector3 = forward * speed + Vector3(sin(time * 0.7) * wind, 0, 0)
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-dt * v.inertia))
	position += velocity * dt
	time += dt

static func crossing_distance(previous: Vector3, current: Vector3, gate: Vector3) -> float:
	if previous.z > gate.z and current.z <= gate.z:
		var fraction = (previous.z - gate.z) / (previous.z - current.z)
		var at_gate = previous.lerp(current, fraction)
		return Vector2(at_gate.x - gate.x, at_gate.y - gate.y).length()
	return -1.0
