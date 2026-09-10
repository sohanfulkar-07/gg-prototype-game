extends Node

const SAVE_PATH := "user://save_game.json"

signal data_loaded
signal data_saved
signal data_reset

# Default starting values
var coins: int = 10
var owned_weapons: Array = [] # e.g. ["basic_sword", "advanced_sword"]
var current_weapon: String = "none" # "none", "basic_sword", "advanced_sword"
var unlocked_skills: Array = [] # e.g. ["fire_attack", "dash", "power_strike"]
var potion_count: int = 0
var level: int = 1
var current_xp: int = 0
var xp_to_next: int = 100
var max_hp: int = 100
var current_hp: int = 100
var completed_missions: Array = [] # e.g. [1, 2, 3]
var boss_defeated: bool = false
var story_progress: int = 0


func _ready() -> void:
	pass


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var save_data := {
		"coins": coins,
		"owned_weapons": owned_weapons,
		"current_weapon": current_weapon,
		"unlocked_skills": unlocked_skills,
		"potion_count": potion_count,
		"level": level,
		"current_xp": current_xp,
		"xp_to_next": xp_to_next,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"completed_missions": completed_missions,
		"boss_defeated": boss_defeated,
		"story_progress": story_progress
	}

	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for write: %s" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()
	data_saved.emit()
	print("SaveManager: Game successfully saved to ", SAVE_PATH)
	return true


func load_game() -> bool:
	if not has_save_file():
		print("SaveManager: No save file found.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for read: %s" % FileAccess.get_open_error())
		return false

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_error("SaveManager: Failed to parse save JSON: %s" % json.get_error_message())
		return false

	var data = json.data
	if not (data is Dictionary):
		push_error("SaveManager: Save data is not a Dictionary.")
		return false

	coins = int(data.get("coins", 10))
	owned_weapons = data.get("owned_weapons", [])
	current_weapon = str(data.get("current_weapon", "none"))
	unlocked_skills = data.get("unlocked_skills", [])
	potion_count = int(data.get("potion_count", 0))
	level = int(data.get("level", 1))
	current_xp = int(data.get("current_xp", 0))
	xp_to_next = int(data.get("xp_to_next", 100))
	max_hp = int(data.get("max_hp", 100))
	current_hp = int(data.get("current_hp", max_hp))
	completed_missions = data.get("completed_missions", [])
	boss_defeated = bool(data.get("boss_defeated", false))
	story_progress = int(data.get("story_progress", 0))

	data_loaded.emit()
	print("SaveManager: Game loaded successfully. Level: ", level, " Coins: ", coins)
	return true


func reset_to_default() -> void:
	coins = 10
	owned_weapons = []
	current_weapon = "none"
	unlocked_skills = []
	potion_count = 0
	level = 1
	current_xp = 0
	xp_to_next = 100
	max_hp = 100
	current_hp = 100
	completed_missions = []
	boss_defeated = false
	story_progress = 0
	data_reset.emit()
	print("SaveManager: Reset to default state.")
