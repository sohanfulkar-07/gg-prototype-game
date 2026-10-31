class_name FinalBossArena
extends Node3D

@onready var boss: CharacterBody3D = get_node_or_null("FinalBoss")
@onready var player: Player = get_node_or_null("Player")
@onready var game_ui: GameUI = get_node_or_null("GameUI")
@onready var dialogue_box: DialogueBox = get_node_or_null("DialogueBox")


func _ready() -> void:
	if GameManager != null:
		GameManager.current_mission_id = 4

	if game_ui != null and boss != null:
		game_ui.show_boss_bar("Masked Warrior", boss.current_hp, boss.max_hp)
		game_ui.set_objective("FINAL BATTLE — Defeat the Masked Warrior!", Color(1.0, 0.3, 0.3))

	if boss != null:
		boss.boss_damaged.connect(_on_boss_damaged)
		boss.boss_defeated_cinematic_started.connect(_on_boss_defeat_cinematic)

	if dialogue_box != null:
		dialogue_box.dialogue_finished.connect(_on_reveal_dialogue_finished)


func _on_boss_damaged(current: int, _max_val: int) -> void:
	if game_ui != null:
		game_ui.update_boss_hp(current)


func _on_boss_defeat_cinematic() -> void:
	if game_ui != null:
		game_ui.hide_boss_bar()
		game_ui.set_objective("The Mask Falls...", Color(1.0, 0.85, 0.3))

	if player != null:
		player.can_move = false
		player.velocity = Vector3.ZERO

	if SoundManager != null:
		SoundManager.play_level_up()

	# Start brother reveal dialogue
	if dialogue_box != null:
		var reveal_lines := [
			{"speaker": "Adventurer", "text": "That mask... it fell to the ground..."},
			{"speaker": "Adventurer", "text": "No... it can't be..."},
			{"speaker": "Adventurer", "text": "BROTHER?!"},
			{"speaker": "Brother", "text": "Ugh... my head... The dark sorcery in this arena... it held me captive for years."},
			{"speaker": "Brother", "text": "You fought bravely, little brother... Your blade shattered the curse that bound me."},
			{"speaker": "Brother", "text": "Thank you for freeing me. Let's return to the village together... We are finally going home!"}
		]
		get_tree().create_timer(0.8).timeout.connect(func():
			dialogue_box.show_dialogue(reveal_lines)
		)


func _on_reveal_dialogue_finished() -> void:
	if game_ui != null:
		game_ui.set_objective("RETURNING TO TOWN FOR THE ROYAL CELEBRATION...", Color(0.2, 1.0, 0.8))

	GameManager.complete_mission(4)
	GameManager.change_scene_safely("res://scenes/levels/town_ending.tscn")
