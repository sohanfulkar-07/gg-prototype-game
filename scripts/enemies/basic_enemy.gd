class_name BasicEnemy
extends CharacterBody3D

## Signals for combat and AI event tracking
signal enemy_damaged(current_hp: int, max_hp: int)
signal enemy_died
signal player_damaged(damage: int)

enum State { IDLE, CHASE, ATTACK, HURT, DEATH }

# ==========================================
# Exported Enemy Stats & Tuning
# ==========================================
@export_group("Enemy Stats")
@export var max_hp: int = 30
@export var current_hp: int = 30
@export var attack_damage: int = 5
@export var move_speed: float = 2.0
@export var detection_range: float = 7.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0
@export var xp_reward: int = 10
@export var min_coins: int = 1
@export var max_coins: int = 2

@export_group("Movement & Physics")
@export var rotation_speed: float = 10.0
@export var gravity: float = 14.0

# State variables
var current_state: State = State.IDLE
var _cooldown_timer: float = 0.0
var _hurt_timer: float = 0.0
var _target_player: Node3D = null

# Node References
@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var attack_area: Area3D = get_node_or_null("Visuals/EnemyAttackArea")
@onready var attack_shape: CollisionShape3D = get_node_or_null("Visuals/EnemyAttackArea/CollisionShape3D")
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/Body")

# Initial materials for hurt flash
var _original_material: Material = null


func _ready() -> void:
	add_to_group("enemy")
	current_hp = max_hp
	
	if body_mesh != null:
		_original_material = body_mesh.get_surface_override_material(0)
		if _original_material == null and body_mesh.mesh != null:
			_original_material = body_mesh.mesh.material

	if attack_area != null:
		attack_area.monitoring = false
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		
	if attack_shape != null:
		attack_shape.disabled = true

	_find_player()


func _physics_process(delta: float) -> void:
	# Decrement timers
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if current_state == State.DEATH:
		move_and_slide()
		return

	# Locate player safely if lost
	if _target_player == null or not is_instance_valid(_target_player):
		_find_player()

	_update_ai_state(delta)
	move_and_slide()


## Safely locates the player in the tree using Godot groups
func _find_player() -> void:
	_target_player = get_tree().get_first_node_in_group("player") as Node3D


## AI State Machine handling IDLE, CHASE, ATTACK, and HURT states
func _update_ai_state(delta: float) -> void:
	if _target_player == null:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return

	var dist_to_player = global_position.distance_to(_target_player.global_position)
	var player_dir = (_target_player.global_position - global_position)
	player_dir.y = 0.0
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			if dist_to_player <= detection_range:
				current_state = State.CHASE

		State.CHASE:
			if dist_to_player <= attack_range:
				velocity.x = 0.0
				velocity.z = 0.0
				if _cooldown_timer <= 0.0:
					_perform_attack()
			elif dist_to_player > detection_range + 3.0:
				current_state = State.IDLE
			else:
				# Move toward player
				var move_dir = player_dir.normalized()
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				
				# Face direction of movement
				if move_dir.length() > 0.1 and visuals != null:
					var target_rot = atan2(-move_dir.x, -move_dir.z)
					visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot, rotation_speed * delta)

		State.HURT:
			# Decelerate knockback
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if _hurt_timer <= 0.0:
				current_state = State.CHASE

		State.ATTACK:
			# Decelerate during attack animation
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)


## Executes enemy melee strike with visual telegraph and active damage window
func _perform_attack() -> void:
	current_state = State.ATTACK
	_cooldown_timer = attack_cooldown
	
	# Face player before striking
	if _target_player != null and visuals != null:
		var dir = (_target_player.global_position - global_position).normalized()
		visuals.rotation.y = atan2(-dir.x, -dir.z)

	# Telegraph attack (windup)
	var tween = create_tween()
	tween.tween_property(visuals, "position:y", 0.3, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(visuals, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	
	# Activate hitbox mid-swing
	get_tree().create_timer(0.15).timeout.connect(func():
		_set_attack_hitbox_active(true)
		get_tree().create_timer(0.15).timeout.connect(func():
			_set_attack_hitbox_active(false)
			if current_state != State.DEATH and current_state != State.HURT:
				current_state = State.CHASE
		)
	)


## Enables or disables enemy attack hitbox
func _set_attack_hitbox_active(active: bool) -> void:
	if attack_area != null:
		attack_area.monitoring = active
	if attack_shape != null:
		attack_shape.disabled = not active


## Called when player's sword or attack hitbox strikes the enemy
func take_damage(amount: int, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEATH:
		return

	current_hp = max(0, current_hp - amount)
	enemy_damaged.emit(current_hp, max_hp)
	if SoundManager != null:
		SoundManager.play_hit()

	# Apply knockback force
	if knockback_dir != Vector3.ZERO:
		velocity.x = knockback_dir.x * 5.0
		velocity.z = knockback_dir.z * 5.0

	# Flash hurt visual
	_flash_hurt()

	if current_hp <= 0:
		die()
	else:
		current_state = State.HURT
		_hurt_timer = 0.25


## Brief visual flash feedback when hit
func _flash_hurt() -> void:
	if body_mesh == null:
		return
		
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
	body_mesh.set_surface_override_material(0, flash_mat)
	
	get_tree().create_timer(0.12).timeout.connect(func():
		if body_mesh != null:
			body_mesh.set_surface_override_material(0, _original_material)
	)


## Handles enemy death logic
func die() -> void:
	if current_state == State.DEATH:
		return
	current_state = State.DEATH
	enemy_died.emit()
	if SoundManager != null:
		SoundManager.play_enemy_death()

	# Grant XP to player
	if _target_player != null and is_instance_valid(_target_player) and _target_player.has_method("add_xp"):
		_target_player.add_xp(xp_reward)

	# Spawn coins
	_spawn_coins()
	
	if collision_shape != null:
		collision_shape.disabled = true
	_set_attack_hitbox_active(false)

	# Death animation: shrink, rotate, fade
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visuals, "rotation:x", deg_to_rad(90), 0.45)
	
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _spawn_coins() -> void:
	var coin_count = randi_range(min_coins, max_coins)
	var coin_scene = preload("res://scenes/levels/coin_pickup.tscn")
	var parent_node = get_parent()
	if parent_node == null:
		return

	for i in range(coin_count):
		var coin = coin_scene.instantiate()
		parent_node.call_deferred("add_child", coin)
		var offset = Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5))
		coin.set_deferred("global_position", global_position + offset)


## Callback when enemy attack hitbox strikes player
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_damage)
		player_damaged.emit(attack_damage)
