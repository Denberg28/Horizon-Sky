extends Node
# Original PCM synthesis: change engine harmonics here, mix levels in set_volume.
const SAMPLE_RATE = 22050
var engine: AudioStreamPlayer
var feedback: AudioStreamPlayer
var engines: Array[AudioStreamWAV] = []
var cues: Dictionary = {}
var volume = 0.45
var flying = false
var current_vehicle = -1
var pending_cue = ""

func _ready():
	engine = AudioStreamPlayer.new()
	feedback = AudioStreamPlayer.new()
	add_child(engine)
	add_child(feedback)
	for frequency in [80.0, 140.0, 60.0]:
		engines.append(make_wave(frequency, 0.1, true))
	cues = {"pass": make_wave(660, 0.18), "miss": make_wave(220, 0.22), "complete": make_wave(880, 0.5), "impact": make_wave(110, 0.3)}
	set_volume(volume)

func _exit_tree():
	set_flying(false)
	engine.stream = null
	feedback.stream = null

static func make_wave(frequency: float, seconds: float, loop: bool = false) -> AudioStreamWAV:
	var count = int(SAMPLE_RATE * seconds)
	var pcm = PackedByteArray()
	pcm.resize(count * 2)
	for i in range(count):
		var t = float(i) / SAMPLE_RATE
		var phase = TAU * frequency * t
		var sample = sin(phase) * 0.20 + sin(phase * 2) * 0.07 + sin(phase * 3) * 0.03
		if not loop:
			# Short attack/release avoid clicks at cue boundaries.
			var envelope = minf(t / 0.008, (seconds - t) / 0.05)
			sample *= clampf(envelope, 0, 1)
		pcm.encode_s16(i * 2, int(sample * 32767))
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = SAMPLE_RATE
	wave.data = pcm
	if loop:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = count
	return wave

func set_volume(value: float):
	volume = clampf(value, 0, 1) if is_finite(value) else 0.45
	if engine == null:
		return
	engine.volume_db = linear_to_db(maxf(volume, 0.0001))
	feedback.volume_db = engine.volume_db
	if volume == 0:
		pending_cue = ""
		engine.stop()
		feedback.stop()

func set_flying(active: bool):
	flying = active
	if not active and engine != null:
		pending_cue = ""
		engine.stop()
		feedback.stop()

func update_engine(throttle: float, speed_fraction: float, vehicle: int, dt: float):
	if not flying or volume == 0:
		return
	vehicle = clampi(vehicle, 0, engines.size() - 1)
	if vehicle != current_vehicle:
		engine.stream = engines[vehicle]
		current_vehicle = vehicle
	var target = 0.75 + clampf(throttle, 0, 1) * 0.7 + clampf(speed_fraction, 0, 1) * 0.25
	engine.pitch_scale = lerpf(engine.pitch_scale, target, 1.0 - exp(-maxf(dt, 0) * 5.0))
	if not engine.playing:
		engine.play()

func play_cue(event: String):
	if volume == 0 or not cues.has(event):
		return
	if not flying and event != "complete" and event != "impact":
		return
	# Render dispatch coalesces events and lets pause cancel a not-yet-started cue.
	pending_cue = event

func _process(_dt: float):
	if pending_cue.is_empty():
		return
	feedback.stop()
	feedback.stream = cues[pending_cue]
	pending_cue = ""
	feedback.play()
