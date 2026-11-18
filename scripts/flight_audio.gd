extends Node
## Bundled, credited game-audio packs. No generic oscillator synthesis or downloads.
const ROOT = "res://assets/audio/"
const ENGINE_SOURCES = [preload(ROOT + "engineCircular_000.ogg"), preload(ROOT + "spaceEngineLarge_000.ogg"), preload(ROOT + "thrusterFire_000.ogg")]
const MUSIC_SOURCES = [preload(ROOT + "01_lift_off_a.ogg"), preload(ROOT + "03_racing_through_asteroids_loop.ogg"), preload(ROOT + "06_battle_in_space_loop.ogg")]
var engine: AudioStreamPlayer
var feedback: AudioStreamPlayer
var music: AudioStreamPlayer
var engines: Array[AudioStreamOggVorbis] = []
var tracks: Array[AudioStreamOggVorbis] = []
var cues: Dictionary = {}
var volume = 0.45
var flying = false
var current_vehicle = -1
var pending_cue = ""
var pending_engine = false
var current_stage = 0
var music_position = 0.0

func _ready():
	engine = AudioStreamPlayer.new()
	feedback = AudioStreamPlayer.new()
	music = AudioStreamPlayer.new()
	for player in [engine, feedback, music]:
		add_child(player)
	for source in ENGINE_SOURCES:
		var loop = source.duplicate()
		loop.loop = true
		engines.append(loop)
	for source in MUSIC_SOURCES:
		var loop = source.duplicate()
		loop.loop = true
		tracks.append(loop)
	cues = {"pass": preload(ROOT + "forceField_000.ogg"), "miss": preload(ROOT + "impactMetal_003.ogg"), "complete": preload(ROOT + "forceField_004.ogg"), "impact": preload(ROOT + "explosionCrunch_002.ogg")}
	music.stream = tracks[0]
	set_volume(volume)

func _exit_tree():
	set_flying(false)
	for player in [engine, feedback, music]:
		player.stream = null

func start_session(stage: int):
	current_stage = clampi(stage, 0, tracks.size() - 1)
	set_flying(false)
	music.stream = tracks[current_stage]
	music_position = 0.0

func set_volume(value: float):
	volume = clampf(value, 0, 1) if is_finite(value) else 0.45
	if engine == null:
		return
	# Mix headroom: sampled engine, event and orchestral music share master volume.
	engine.volume_db = linear_to_db(maxf(volume * 0.30, 0.0001))
	feedback.volume_db = linear_to_db(maxf(volume * 0.35, 0.0001))
	music.volume_db = linear_to_db(maxf(volume * 0.25, 0.0001))
	if volume == 0:
		pending_cue = ""
		pending_engine = false
		if music.playing:
			music_position = music.get_playback_position()
		for player in [engine, feedback, music]:
			player.stop()

func set_flying(active: bool):
	flying = active
	if not active and engine != null:
		pending_cue = ""
		pending_engine = false
		if music.playing:
			music_position = music.get_playback_position()
		for player in [engine, feedback, music]:
			player.stop()

func update_engine(throttle: float, speed_fraction: float, vehicle: int, dt: float):
	if not flying or volume == 0:
		return
	vehicle = clampi(vehicle, 0, engines.size() - 1)
	if vehicle != current_vehicle:
		engine.stream = engines[vehicle]
		current_vehicle = vehicle
	var target = 0.75 + clampf(throttle, 0, 1) * 0.55 + clampf(speed_fraction, 0, 1) * 0.15
	engine.pitch_scale = lerpf(engine.pitch_scale, target, 1.0 - exp(-maxf(dt, 0) * 5.0))
	engine.volume_db = linear_to_db(maxf(volume * lerpf(0.10, 0.30, clampf(throttle, 0, 1)), 0.0001))
	pending_engine = true

func play_cue(event: String):
	if volume == 0 or not cues.has(event):
		return
	if not flying and event != "complete" and event != "impact":
		return
	pending_cue = event

func _process(_dt: float):
	# SceneTree can still process children in the frame their ancestor is queued free.
	# Cancel native playback before the audio server acquires a retiring scene's cue.
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			set_flying(false)
			return
		ancestor = ancestor.get_parent()
	if pending_engine and flying and volume > 0:
		pending_engine = false
		if not engine.playing:
			engine.play()
		if not music.playing:
			music.play(music_position)
			music_position = 0.0
	if pending_cue.is_empty():
		return
	feedback.stop()
	feedback.stream = cues[pending_cue]
	pending_cue = ""
	feedback.play()
