extends Node

# Procedural Sound Manager using AudioStreamGeneratorPlayback
var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = _sample_rate
	generator.buffer_length = 0.5
	_audio_player.stream = generator
	_audio_player.volume_db = -5.0
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func play_tone(freq: float, duration: float, type: String = "sine", decay: bool = true) -> void:
	if _playback == null or not _audio_player.playing:
		return

	var num_frames = int(_sample_rate * duration)
	var available = _playback.get_frames_available()
	var to_write = min(num_frames, available)

	for i in range(to_write):
		var t = float(i) / _sample_rate
		var sample: float = 0.0
		var phase = fmod(t * freq, 1.0)

		match type:
			"sine":
				# Warm fundamental + subtle second harmonic
				sample = sin(t * freq * TAU) * 0.8 + sin(t * freq * 2.0 * TAU) * 0.2
			"square":
				sample = 0.55 if phase < 0.5 else -0.55
			"noise":
				sample = randf_range(-0.65, 0.65)
			"triangle":
				sample = (4.0 * abs(phase - 0.5) - 1.0) * 0.85

		if decay:
			var env = (1.0 - (float(i) / float(to_write)))
			sample *= (env * env)

		_playback.push_frame(Vector2(sample, sample))


func play_sweep(start_freq: float, end_freq: float, duration: float, type: String = "sine") -> void:
	if _playback == null or not _audio_player.playing:
		return

	var num_frames = int(_sample_rate * duration)
	var available = _playback.get_frames_available()
	var to_write = min(num_frames, available)
	var current_phase: float = 0.0

	for i in range(to_write):
		var progress = float(i) / float(to_write)
		var current_freq = lerp(start_freq, end_freq, progress)
		current_phase += current_freq / _sample_rate

		var sample: float = 0.0
		match type:
			"sine":
				sample = sin(current_phase * TAU)
			"noise":
				sample = randf_range(-0.6, 0.6) * (1.0 - progress * 0.5)
			"triangle":
				var p = fmod(current_phase, 1.0)
				sample = (4.0 * abs(p - 0.5) - 1.0) * 0.8

		var env = (1.0 - progress)
		sample *= (env * env)
		_playback.push_frame(Vector2(sample, sample))


func play_sword_swing() -> void:
	# Dynamic whoosh sweep with airy texture
	play_sweep(650.0, 180.0, 0.09, "noise")


func play_hit() -> void:
	# Meaty punchy impact (pitch drop + noise crunch)
	play_sweep(280.0, 60.0, 0.12, "triangle")


func play_coin() -> void:
	# Crystal pure double chime
	play_tone(987.77, 0.06, "sine")
	get_tree().create_timer(0.05).timeout.connect(func():
		play_tone(1318.51, 0.14, "sine")
	)


func play_potion() -> void:
	# Soothing healing arpeggio
	var chords = [523.25, 659.25, 783.99, 1046.50]
	for i in range(chords.size()):
		get_tree().create_timer(i * 0.06).timeout.connect(func():
			play_tone(chords[i], 0.12, "sine")
		)


func play_level_up() -> void:
	# Brilliant victory fanfare
	var notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
	for i in range(notes.size()):
		get_tree().create_timer(i * 0.07).timeout.connect(func():
			play_tone(notes[i], 0.14, "square")
		)


func play_purchase() -> void:
	# Cheerful register chime
	play_tone(784.0, 0.06, "sine")
	get_tree().create_timer(0.06).timeout.connect(func():
		play_tone(1174.66, 0.12, "sine")
	)


func play_enemy_death() -> void:
	# Low crunch thud
	play_sweep(190.0, 45.0, 0.2, "triangle")


func play_boss_roar() -> void:
	# Sub-bass seismic rumble
	play_sweep(120.0, 40.0, 0.45, "triangle")


func play_skill_fire() -> void:
	# Crackling blaze whoosh
	play_sweep(250.0, 800.0, 0.18, "noise")


func play_skill_dash() -> void:
	# Aerodynamic wind slice
	play_sweep(850.0, 240.0, 0.14, "triangle")


func play_skill_power() -> void:
	# Earth-shattering slam
	play_sweep(240.0, 50.0, 0.32, "triangle")
