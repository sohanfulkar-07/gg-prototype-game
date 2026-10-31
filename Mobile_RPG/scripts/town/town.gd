class_name Town
extends Node3D

signal gate_entered
signal save_point_interacted

@onready var player: Player = get_node_or_null("Player")
@onready var game_ui: GameUI = get_node_or_null("GameUI")
@onready var shop_dialog: ShopDialog = get_node_or_null("ShopDialog")
@onready var dialogue_box: DialogueBox = get_node_or_null("DialogueBox")

# Interactive areas
@onready var teleport_area: Area3D = get_node_or_null("TeleportGate/Area3D")
@onready var gate_label: Label3D = get_node_or_null("TeleportGate/Label3D")
@onready var save_area: Area3D = get_node_or_null("SavePoint/Area3D")
@onready var save_label: Label3D = get_node_or_null("SavePoint/Label3D")

var _near_gate: bool = false
var _near_save: bool = false
var _current_shop: String = ""
var _current_npc: String = ""


func _ready() -> void:
	if GameManager != null:
		GameManager.current_mission_id = 0

	# Auto-save when returning to town
	if SaveManager != null:
		SaveManager.save_game()

	_setup_triggers()
	_update_gate_label()
	_update_hud_objective()

	if player != null:
		player.interact_requested.connect(_trigger_current_interaction)


func _setup_triggers() -> void:
	# Teleport Gate
	if teleport_area != null:
		teleport_area.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_near_gate = true
				_update_prompts()
		)
		teleport_area.body_exited.connect(func(b):
			if b.is_in_group("player"):
				_near_gate = false
				_update_prompts()
		)

	# Save Point
	if save_area != null:
		save_area.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_near_save = true
				_update_prompts()
		)
		save_area.body_exited.connect(func(b):
			if b.is_in_group("player"):
				_near_save = false
				_update_prompts()
		)

	# Setup Shops
	_bind_shop_area("Shops/BasicSwordShop", "basic_sword")
	_bind_shop_area("Shops/AdvancedSwordShop", "advanced_sword")
	_bind_shop_area("Shops/SkillScrollShop", "skill_scroll")
	_bind_shop_area("Shops/PotionShop", "potion")

	# Setup NPCs
	_bind_npc_area("NPCs/Elder/Area3D", "elder")
	_bind_npc_area("NPCs/Guard/Area3D", "guard")
	_bind_npc_area("NPCs/Villager/Area3D", "villager")


func _bind_shop_area(path: String, shop_type: String) -> void:
	var area = get_node_or_null(path) as Area3D
	if area != null:
		area.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_current_shop = shop_type
				_update_prompts()
		)
		area.body_exited.connect(func(b):
			if b.is_in_group("player"):
				if _current_shop == shop_type:
					_current_shop = ""
				_update_prompts()
		)


func _bind_npc_area(path: String, npc_name: String) -> void:
	var area = get_node_or_null(path) as Area3D
	if area != null:
		area.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_current_npc = npc_name
				_update_prompts()
		)
		area.body_exited.connect(func(b):
			if b.is_in_group("player"):
				if _current_npc == npc_name:
					_current_npc = ""
				_update_prompts()
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_trigger_current_interaction()


func _trigger_current_interaction() -> void:
	# If a modal or dialogue is already open, ignore
	if shop_dialog != null and shop_dialog.visible:
		return
	if dialogue_box != null and dialogue_box.visible:
		return

	if _current_shop != "":
		if shop_dialog != null:
			shop_dialog.open_shop(_current_shop)
	elif _current_npc != "":
		_talk_to_npc(_current_npc)
	elif _near_save:
		_interact_save()
	elif _near_gate:
		_enter_teleport_gate()


func _update_prompts() -> void:
	var prompt_text := ""
	var is_visible := false

	if _current_shop != "":
		var shop_name = _current_shop.replace("_", " ").capitalize()
		prompt_text = "[E] Browse %s" % shop_name
		is_visible = true
	elif _current_npc != "":
		prompt_text = "[E] Talk to %s" % _current_npc.capitalize()
		is_visible = true
	elif _near_save:
		prompt_text = "[E] Save Progress"
		is_visible = true
	elif _near_gate:
		prompt_text = "[E] Enter Gate: %s" % _get_next_destination_name()
		is_visible = true

	if game_ui != null:
		game_ui.set_interact_prompt(prompt_text, is_visible)


func _get_next_destination_name() -> String:
	if SaveManager == null:
		return "Mission 1: Forest"

	if not (1 in SaveManager.completed_missions):
		return "Mission 1: Forest"
	elif not (2 in SaveManager.completed_missions):
		return "Mission 2: Ruins"
	elif not (3 in SaveManager.completed_missions):
		return "Mission 3: Deep Dungeon"
	else:
		return "Final Boss Arena"


func _enter_teleport_gate() -> void:
	gate_entered.emit()
	if not (1 in SaveManager.completed_missions):
		GameManager.change_scene_safely("res://scenes/levels/mission_1_forest.tscn")
	elif not (2 in SaveManager.completed_missions):
		GameManager.change_scene_safely("res://scenes/levels/mission_2_ruins.tscn")
	elif not (3 in SaveManager.completed_missions):
		GameManager.change_scene_safely("res://scenes/levels/mission_3_dungeon.tscn")
	else:
		GameManager.change_scene_safely("res://scenes/bosses/final_boss_arena.tscn")


func _interact_save() -> void:
	save_point_interacted.emit()
	if SaveManager != null:
		SaveManager.save_game()
	if SoundManager != null:
		SoundManager.play_level_up()
	if game_ui != null:
		game_ui.set_objective("GAME SAVED AT SAVE POINT!", Color(0.3, 1.0, 0.5))
		get_tree().create_timer(3.0).timeout.connect(_update_hud_objective)


func _talk_to_npc(npc_id: String) -> void:
	if dialogue_box == null:
		return

	var lines := []
	match npc_id:
		"elder":
			lines = [
				{"speaker": "Town Elder", "text": "Greetings, young traveler. Our kingdom is gripped by dark magic spilling from the ancient ruins."},
				{"speaker": "Town Elder", "text": "Years ago, your older brother stepped through the gate to seek the source. He never returned..."},
				{"speaker": "Town Elder", "text": "Buy a sword, conquer the missions, and bring peace back to our people!"}
			]
		"guard":
			lines = [
				{"speaker": "Town Guard", "text": "Beyond that gate lies peril! Defeated monsters drop valuable coins and experience."},
				{"speaker": "Town Guard", "text": "Don't forget to stock up on Healing Potions at the potion shop before setting out."}
			]
		"villager":
			lines = [
				{"speaker": "Villager", "text": "We are praying for your victory! You can unlock powerful Skill Scrolls at the magic shop!"},
				{"speaker": "Villager", "text": "Once you clear all three missions, legendary gear will be forged for the final challenge!"}
			]

	dialogue_box.show_dialogue(lines)


func _update_gate_label() -> void:
	if gate_label == null:
		return
	var dest = _get_next_destination_name()
	gate_label.text = "TELEPORT GATE\n[%s]" % dest


func _update_hud_objective() -> void:
	if game_ui == null:
		return

	if SaveManager == null:
		game_ui.set_objective("Explore Town & Visit Shops")
		return

	if not (1 in SaveManager.completed_missions):
		if not ("basic_sword" in SaveManager.owned_weapons):
			game_ui.set_objective("Town Objective: Buy Basic Sword (7 coins) then enter Forest")
		else:
			game_ui.set_objective("Town Objective: Enter Teleport Gate to Mission 1 (Forest)")
	elif not (2 in SaveManager.completed_missions):
		game_ui.set_objective("Town Objective: Enter Teleport Gate to Mission 2 (Ruins)")
	elif not (3 in SaveManager.completed_missions):
		game_ui.set_objective("Town Objective: Enter Teleport Gate to Mission 3 (Deep Dungeon)")
	elif not SaveManager.boss_defeated:
		if not ("advanced_sword" in SaveManager.owned_weapons):
			game_ui.set_objective("Town Objective: Buy Advanced Sword (15 coins) & Enter Final Boss Arena")
		else:
			game_ui.set_objective("Town Objective: Enter Gate for the Final Boss Battle!")
	else:
		game_ui.set_objective("The Kingdom is Saved! Celebration in progress!")
