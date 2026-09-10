class_name EliteEnemy
extends BasicEnemy

func _init() -> void:
	max_hp = 80
	current_hp = 80
	attack_damage = 12
	move_speed = 2.0
	detection_range = 9.0
	attack_range = 1.8
	attack_cooldown = 0.8
	xp_reward = 40
	min_coins = 3
	max_coins = 5
