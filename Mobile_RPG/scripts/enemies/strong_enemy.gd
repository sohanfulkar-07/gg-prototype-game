class_name StrongEnemy
extends BasicEnemy

func _init() -> void:
	max_hp = 45
	current_hp = 45
	attack_damage = 8
	move_speed = 2.2
	detection_range = 8.0
	attack_range = 1.6
	attack_cooldown = 0.9
	xp_reward = 20
	min_coins = 2
	max_coins = 3
