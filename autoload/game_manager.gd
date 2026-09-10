extends Node

signal mission_completed(mission_id: int)
signal coins_updated(total_coins: int)
signal inventory_updated
signal hp_updated(current: int, max_val: int)
signal xp_updated(current: int, needed: int, level: int)

var is_transitioning: bool = false
var current_mission_id: int = 0 # 0 = town, 1 = forest, 2 = ruins, 3 = dungeon, 4 = boss, 5 = ending

# Mission rewards (coins)
const MISSION_REWARDS := {
	1: 5,
	2: 8,
	3: 12,
	4: 25
}

# Weapon damage mapping
const WEAPON_DAMAGE := {
	"none": 8,
	"basic_sword": 15,
	"advanced_sword": 25
}


func _ready() -> void:
	pass


func start_new_game() -> void:
	SaveManager.reset_to_default()
	SaveManager.save_game()
	current_mission_id = 0
	change_scene_safely("res://scenes/town/town.tscn")


func continue_game() -> void:
	if SaveManager.has_save_file():
		SaveManager.load_game()
	else:
		SaveManager.reset_to_default()
		SaveManager.save_game()
		
	current_mission_id = 0
	if SaveManager.boss_defeated:
		change_scene_safely("res://scenes/levels/town_ending.tscn")
	else:
		change_scene_safely("res://scenes/town/town.tscn")


func change_scene_safely(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	print("GameManager: Changing scene to ", scene_path)
	
	# Small delay / defer to allow callers to clean up
	get_tree().create_timer(0.1).timeout.connect(func():
		var err = get_tree().change_scene_to_file(scene_path)
		if err != OK:
			push_error("GameManager: Failed to load scene %s: error %d" % [scene_path, err])
		is_transitioning = false
	)


func is_mission_unlocked(mission_id: int) -> bool:
	match mission_id:
		1:
			return true
		2:
			return 1 in SaveManager.completed_missions
		3:
			return 2 in SaveManager.completed_missions
		4: # Final Boss
			return 3 in SaveManager.completed_missions
		_:
			return false


func is_advanced_sword_unlocked() -> bool:
	return 3 in SaveManager.completed_missions


func complete_mission(mission_id: int) -> void:
	if not (mission_id in SaveManager.completed_missions):
		SaveManager.completed_missions.append(mission_id)
	
	var reward = MISSION_REWARDS.get(mission_id, 5)
	SaveManager.coins += reward
	coins_updated.emit(SaveManager.coins)
	
	if mission_id == 4:
		SaveManager.boss_defeated = true
		SaveManager.story_progress = 4
	
	SaveManager.save_game()
	mission_completed.emit(mission_id)
	print("GameManager: Mission %d completed! Rewarded %d coins. Total coins: %d" % [mission_id, reward, SaveManager.coins])


func buy_basic_sword() -> String:
	const PRICE = 7
	if "basic_sword" in SaveManager.owned_weapons:
		return "ALREADY_OWNED"
	if SaveManager.coins < PRICE:
		return "NOT_ENOUGH_COINS"
	
	SaveManager.coins -= PRICE
	SaveManager.owned_weapons.append("basic_sword")
	SaveManager.current_weapon = "basic_sword"
	SaveManager.save_game()
	coins_updated.emit(SaveManager.coins)
	inventory_updated.emit()
	if SoundManager != null:
		SoundManager.play_purchase()
	return "SUCCESS"


func buy_advanced_sword() -> String:
	const PRICE = 15
	if not is_advanced_sword_unlocked():
		return "LOCKED"
	if "advanced_sword" in SaveManager.owned_weapons:
		return "ALREADY_OWNED"
	if SaveManager.coins < PRICE:
		return "NOT_ENOUGH_COINS"
		
	SaveManager.coins -= PRICE
	SaveManager.owned_weapons.append("advanced_sword")
	SaveManager.current_weapon = "advanced_sword"
	SaveManager.save_game()
	coins_updated.emit(SaveManager.coins)
	inventory_updated.emit()
	if SoundManager != null:
		SoundManager.play_purchase()
	return "SUCCESS"


func buy_healing_potion() -> String:
	const PRICE = 3
	if SaveManager.coins < PRICE:
		return "NOT_ENOUGH_COINS"
		
	SaveManager.coins -= PRICE
	SaveManager.potion_count += 1
	SaveManager.save_game()
	coins_updated.emit(SaveManager.coins)
	inventory_updated.emit()
	if SoundManager != null:
		SoundManager.play_purchase()
	return "SUCCESS"


func buy_skill(skill_id: String) -> String:
	const PRICE = 20
	if skill_id in SaveManager.unlocked_skills:
		return "ALREADY_OWNED"
	if SaveManager.coins < PRICE:
		return "NOT_ENOUGH_COINS"
		
	SaveManager.coins -= PRICE
	SaveManager.unlocked_skills.append(skill_id)
	SaveManager.save_game()
	coins_updated.emit(SaveManager.coins)
	inventory_updated.emit()
	if SoundManager != null:
		SoundManager.play_purchase()
	return "SUCCESS"


func use_potion(player: Node) -> bool:
	if SaveManager.potion_count <= 0:
		return false
	if player == null or not is_instance_valid(player):
		return false
	if player.current_hp >= player.max_hp:
		return false # full HP already
		
	SaveManager.potion_count -= 1
	player.heal(30)
	SaveManager.current_hp = player.current_hp
	inventory_updated.emit()
	if SoundManager != null:
		SoundManager.play_potion()
	return true


func get_current_weapon_damage() -> int:
	return WEAPON_DAMAGE.get(SaveManager.current_weapon, 8)
