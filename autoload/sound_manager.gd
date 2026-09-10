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
	_audio_player.volume_db = -6.0
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
				sample = sin(t * freq * TAU)
			"square":
				sample = 0.6 if phase < 0.5 else -0.6
			"noise":
				sample = randf_range(-0.7, 0.7)
			"triangle":
				sample = (4.0 * abs(phase - 0.5) - 1.0) * 0.8
		
		if decay:
			var env = 1.0 - (float(i) / float(to_write))
			sample *= env
			
		_playback.push_frame(Vector2(sample, sample))


func play_sword_swing() -> void:
	# Quick swoosh (noise + dropping pitch)
	play_tone(320.0, 0.08, "noise")


func play_hit() -> void:
	# Punchy impact
	play_tone(150.0, 0.12, "triangle")


func play_coin() -> void:
	# Bright two-tone chime
	play_tone(880.0, 0.06, "sine")
	get_tree().create_timer(0.06).timeout.connect(func():
		play_tone(1320.0, 0.12, "sine")
	)


func play_potion() -> void:
	# Rising gentle chord
	play_tone(523.25, 0.08, "sine")
	get_tree().create_timer(0.08).timeout.connect(func():
		play_tone(659.25, 0.08, "sine")
		get_tree().create_timer(0.08).timeout.connect(func():
			play_tone(783.99, 0.14, "sine")
		)
	)


func play_level_up() -> void:
	# Fanfare arpeggio
	var notes = [523.25, 659.25, 783.99, 1046.50]
	for i in range(notes.size()):
		get_tree().create_timer(i * 0.09).timeout.connect(func():
			play_tone(notes[i], 0.12, "square")
		)


func play_purchase() -> void:
	play_tone(700.0, 0.06, "sine")
	get_tree().create_timer(0.06).timeout.connect(func():
		play_tone(900.0, 0.1, "sine")
	)


func play_enemy_death() -> void:
	play_tone(120.0, 0.18, "noise")


func play_boss_roar() -> void:
	play_tone(90.0, 0.35, "noise")


func play_skill_fire() -> void:
	play_tone(400.0, 0.15, "noise")


func play_skill_dash() -> void:
	play_tone(500.0, 0.12, "triangle")


func play_skill_power() -> void:
	play_tone(180.0, 0.25, "square")
