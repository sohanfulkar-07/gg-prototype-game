extends Node

# Procedural Sound Manager using AudioStreamGeneratorPlayback
var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0

# Dedicated background ambience & music player
var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _is_music_active: bool = false
var _music_time: float = 0.0

# Volume scales
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# SFX Audio Player
	_audio_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = _sample_rate
	generator.buffer_length = 0.5
	_audio_player.stream = generator
	_audio_player.volume_db = linear_to_db(master_volume * sfx_volume)
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Ambience / Music Audio Player
	_music_player = AudioStreamPlayer.new()
	var music_gen = AudioStreamGenerator.new()
	music_gen.mix_rate = _sample_rate
	music_gen.buffer_length = 0.6
	_music_player.stream = music_gen
	_music_player.volume_db = linear_to_db(master_volume * music_volume * 0.75)
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_master_volume(val: float) -> void:
	master_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(val: float) -> void:
	sfx_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(val: float) -> void:
	music_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	if _audio_player != null:
		_audio_player.volume_db = linear_to_db(max(0.0001, master_volume * sfx_volume))
	if _music_player != null:
		_music_player.volume_db = linear_to_db(max(0.0001, master_volume * music_volume * 0.75))


func _process(delta: float) -> void:
	if _is_music_active and _music_playback != null:
		_generate_ambience_music_frames()


## Procedurally generates layered fantasy wind ambience and gentle harp chord swells
func _generate_ambience_music_frames() -> void:
	var available = _music_playback.get_frames_available()
	if available <= 0:
		return
	
	var to_write = min(available, 1024)
	
	# Fantasy chord root progression: D minor (D3 -> F3 -> A3 -> C4)
	# Frequencies: 146.83, 174.61, 220.00, 261.63, 293.66, 349.23
	var chord_notes = [146.83, 220.0, 261.63, 349.23, 440.0]
	
	for _i in range(to_write):
		_music_time += 1.0 / _sample_rate
		
		# Atmospheric filtered wind noise
		var wind_noise = randf_range(-0.18, 0.18)
		var wind_swell = (sin(_music_time * 0.45) * 0.5 + 0.5) * (cos(_music_time * 0.22) * 0.3 + 0.7)
		var wind_sample = wind_noise * wind_swell * 0.28
		
		# Gentle ethereal pad chords (slow beating harmonics)
		var note_idx = int(_music_time * 0.35) % chord_notes.size()
		var target_freq = chord_notes[note_idx]
		var harmonic_1 = sin(_music_time * target_freq * TAU) * 0.08
		var harmonic_2 = sin(_music_time * target_freq * 1.5 * TAU) * 0.04
		var drone = sin(_music_time * 73.42 * TAU) * 0.06 # Deep warm bass drone
		
		var sample_total = wind_sample + (harmonic_1 + harmonic_2 + drone) * 0.55
		_music_playback.push_frame(Vector2(sample_total, sample_total))


func start_cinematic_music() -> void:
	_is_music_active = true
	_music_time = 0.0


func stop_cinematic_music() -> void:
	_is_music_active = false


# ==========================================
# UI Sound Effects
# ==========================================

func play_ui_hover() -> void:
	play_tone(440.0, 0.03, "sine", true)


func play_ui_click() -> void:
	play_tone(784.0, 0.05, "sine", true)
	get_tree().create_timer(0.04).timeout.connect(func():
		play_tone(1046.5, 0.08, "sine", true)
	)


func play_ui_confirm() -> void:
	# Resonant noble chord
	play_tone(523.25, 0.1, "sine")
	get_tree().create_timer(0.06).timeout.connect(func():
		play_tone(659.25, 0.12, "sine")
	)
	get_tree().create_timer(0.12).timeout.connect(func():
		play_tone(783.99, 0.18, "sine")
	)


func play_ui_cancel() -> void:
	play_tone(370.0, 0.08, "sine", true)


func play_title_reveal() -> void:
	# Majestic resonant chord swell + shimmer
	play_sweep(130.0, 65.0, 0.6, "triangle")
	play_tone(220.0, 0.5, "sine")
	get_tree().create_timer(0.1).timeout.connect(func():
		play_tone(329.63, 0.45, "sine")
	)
	get_tree().create_timer(0.2).timeout.connect(func():
		play_tone(440.0, 0.6, "sine")
	)
	get_tree().create_timer(0.3).timeout.connect(func():
		play_sweep(880.0, 1760.0, 0.4, "sine")
	)


func play_wind_whoosh() -> void:
	play_sweep(400.0, 120.0, 0.35, "noise")


# ==========================================
# Core SFX (Existing Project Functionality)
# ==========================================

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
	play_sweep(650.0, 180.0, 0.09, "noise")


func play_hit() -> void:
	play_sweep(280.0, 60.0, 0.12, "triangle")


func play_coin() -> void:
	play_tone(987.77, 0.06, "sine")
	get_tree().create_timer(0.05).timeout.connect(func():
		play_tone(1318.51, 0.14, "sine")
	)


func play_potion() -> void:
	var chords = [523.25, 659.25, 783.99, 1046.50]
	for i in range(chords.size()):
		get_tree().create_timer(i * 0.06).timeout.connect(func():
			play_tone(chords[i], 0.12, "sine")
		)


func play_level_up() -> void:
	var notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
	for i in range(notes.size()):
		get_tree().create_timer(i * 0.07).timeout.connect(func():
			play_tone(notes[i], 0.14, "square")
		)


func play_purchase() -> void:
	play_tone(784.0, 0.06, "sine")
	get_tree().create_timer(0.06).timeout.connect(func():
		play_tone(1174.66, 0.12, "sine")
	)


func play_enemy_death() -> void:
	play_sweep(190.0, 45.0, 0.2, "triangle")


func play_boss_roar() -> void:
	play_sweep(120.0, 40.0, 0.45, "triangle")


func play_skill_fire() -> void:
	play_sweep(250.0, 800.0, 0.18, "noise")


func play_skill_dash() -> void:
	play_sweep(850.0, 240.0, 0.14, "triangle")


func play_skill_power() -> void:
	play_sweep(240.0, 50.0, 0.32, "triangle")
