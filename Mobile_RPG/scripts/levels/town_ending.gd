class_name TownEnding
extends Node3D

@onready var dialogue_box: DialogueBox = get_node_or_null("DialogueBox")
@onready var credits_panel: Control = get_node_or_null("CanvasLayer/CreditsPanel")
@onready var btn_title: Button = get_node_or_null("CanvasLayer/CreditsPanel/VBox/BtnTitle")
@onready var player: Player = get_node_or_null("Player")


func _ready() -> void:
	if GameManager != null:
		GameManager.current_mission_id = 5

	if credits_panel != null:
		credits_panel.visible = false

	if btn_title != null:
		btn_title.pressed.connect(_on_return_to_title)

	if dialogue_box != null:
		dialogue_box.dialogue_finished.connect(_show_credits)

	# Auto-save completion
	if SaveManager != null:
		SaveManager.boss_defeated = true
		SaveManager.save_game()

	if SoundManager != null:
		SoundManager.play_level_up()

	# Start celebratory royal dialogue after brief pause
	get_tree().create_timer(1.2).timeout.connect(_start_ending_dialogue)


func _start_ending_dialogue() -> void:
	if dialogue_box == null:
		_show_credits()
		return

	var ending_lines := [
		{"speaker": "Town Elder", "text": "Hooray! The brothers have returned victorious from the deep dungeon!"},
		{"speaker": "Town Guard", "text": "The dark shroud over our lands has cleared! Three cheers for our champion!"},
		{"speaker": "Brother", "text": "I couldn't have done it without my little brother here. He's the real hero."},
		{"speaker": "The King", "text": "Make way! Make way for royal majesty!"},
		{"speaker": "The King", "text": "Brave hero! You have saved our realm from the ancient calamity!"},
		{"speaker": "The King", "text": "As your eternal reward... I hereby offer you my beloved daughter's hand in marriage!"},
		{"speaker": "Adventurer", "text": "(Wait... WHAT?! But I just started adventuring yesterday?!)"},
		{"speaker": "Princess", "text": "FATHER! Put that decree away! I am the royal master of archery, not a raffle prize!"},
		{"speaker": "Brother", "text": "Bwahaha! Congratulations, little brother! Looks like you'll need all three skills to survive royal court!"},
		{"speaker": "The King", "text": "Ahem! In that case... Let the grand feast begin! Drinks and roast boar for everyone!"}
	]

	dialogue_box.show_dialogue(ending_lines)


func _show_credits() -> void:
	if SoundManager != null:
		SoundManager.play_level_up()

	if credits_panel != null:
		credits_panel.visible = true
		credits_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(credits_panel, "modulate:a", 1.0, 1.0)


func _on_return_to_title() -> void:
	if GameManager != null:
		GameManager.change_scene_safely("res://scenes/ui/main_menu.tscn")
