class_name Player
extends CharacterBody3D

## Signals for UI, combat, and progression
signal health_changed(current_hp: int, max_hp: int)
signal died
signal xp_gained(amount: int, current_xp: int, xp_needed: int)
signal leveled_up(new_level: int)
signal coins_changed(new_amount: int)
signal attack_performed(attack_type: String)
signal skill_used(skill_index: int)
signal skill_cooldown_started(skill_index: int, duration: float)
signal interact_requested

# ==========================================
# Exported Stats & Attributes
# ==========================================
@export_group("Base Stats")
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack_damage: int = 15

@export_group("Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100
@export var coins: int = 10

@export_group("Movement")
@export var move_speed: float = 6.0
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var rotation_speed: float = 12.0
@export var enable_gravity: bool = true
@export var gravity: float = 14.0

@export_group("Camera Settings")
@export var camera_yaw_speed: float = 0.003
@export var camera_pitch_speed: float = 0.003
@export var min_pitch: float = deg_to_rad(-60.0)
@export var max_pitch: float = deg_to_rad(-10.0)
@export var default_pitch: float = deg_to_rad(-28.0)

# ==========================================
# Node References
# ==========================================
@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var weapon_holder: Node3D = $Visuals/WeaponHolder
@onready var sword_node: Node3D = get_node_or_null("Visuals/WeaponHolder/Sword")
@onready var blade_mesh: MeshInstance3D = get_node_or_null("Visuals/WeaponHolder/Sword/Blade")
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = get_node_or_null("CameraPivot/SpringArm3D")
@onready var camera: Camera3D = get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
@onready var combat: PlayerCombat = $PlayerCombat

# Internal movement & input state
var _input_direction: Vector2 = Vector2.ZERO
var mobile_move_direction: Vector2 = Vector2.ZERO
var is_invulnerable: bool = false
var can_move: bool = true

# Skill cooldowns
var skill_1_cooldown: float = 0.0 # Fire Attack (3.0s)
var skill_2_cooldown: float = 0.0 # Dash (2.0s)
var skill_3_cooldown: float = 0.0 # Power Strike (4.0s)

const SKILL_1_MAX_CD := 3.0
const SKILL_2_MAX_CD := 2.0
const SKILL_3_MAX_CD := 4.0


func _ready() -> void:
	add_to_group("player")
	
	# Exclude player body from camera spring-arm collision
	if spring_arm != null:
		spring_arm.add_excluded_object(get_rid())
		spring_arm.rotation.x = default_pitch
	
	# Synchronize stats from SaveManager
	sync_from_save()
	
	# Connect combat signals
	if combat != null:
		if combat.has_signal("attack_started"):
			combat.connect("attack_started", Callable(self, "_on_attack_started"))
		if combat.has_signal("attack_finished"):
			combat.connect("attack_finished", Callable(self, "_on_attack_finished"))

	# Listen to inventory / weapon updates
	if GameManager != null:
		GameManager.inventory_updated.connect(update_weapon_visuals)

	update_weapon_visuals()


func sync_from_save() -> void:
	if SaveManager != null:
		max_hp = SaveManager.max_hp
		current_hp = SaveManager.current_hp
		level = SaveManager.level
		current_xp = SaveManager.current_xp
		xp_to_next_level = SaveManager.xp_to_next
		coins = SaveManager.coins
	health_changed.emit(current_hp, max_hp)
	coins_changed.emit(coins)


func update_weapon_visuals() -> void:
	if sword_node == null:
		return

	var weapon_id = SaveManager.current_weapon if SaveManager != null else "basic_sword"
	if weapon_id == "none":
		sword_node.visible = false
	else:
		sword_node.visible = true
		if blade_mesh != null:
			var mat = StandardMaterial3D.new()
			if weapon_id == "advanced_sword":
				mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0) # Golden Blade
				mat.metallic = 0.95
				mat.roughness = 0.15
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.8, 0.2, 1.0)
				mat.emission_energy_multiplier = 0.4
			else:
				mat.albedo_color = Color(0.9, 0.93, 0.96, 1.0) # Steel Blade
				mat.metallic = 0.85
				mat.roughness = 0.2
			blade_mesh.set_surface_override_material(0, mat)


func get_attack_damage() -> int:
	var base_dmg = GameManager.get_current_weapon_damage() if GameManager != null else attack_damage
	return base_dmg + (level - 1) * 2


## Rotates third-person camera horizontally around pivot and vertically clamps pitch
func rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	if camera_pivot != null:
		camera_pivot.rotation.y -= yaw_delta
	if spring_arm != null:
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - pitch_delta, min_pitch, max_pitch)


func _unhandled_input(event: InputEvent) -> void:
	# PC Right Mouse Button drag to rotate camera smoothly
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_camera(event.relative.x * camera_yaw_speed, event.relative.y * camera_pitch_speed)


func _physics_process(delta: float) -> void:
	_update_skill_cooldowns(delta)
	
	if can_move:
		_handle_input()
		_apply_movement(delta)
		_apply_rotation(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		
	_apply_gravity(delta)
	move_and_slide()


func _update_skill_cooldowns(delta: float) -> void:
	if skill_1_cooldown > 0.0:
		skill_1_cooldown = max(0.0, skill_1_cooldown - delta)
	if skill_2_cooldown > 0.0:
		skill_2_cooldown = max(0.0, skill_2_cooldown - delta)
	if skill_3_cooldown > 0.0:
		skill_3_cooldown = max(0.0, skill_3_cooldown - delta)


func set_mobile_move(dir: Vector2) -> void:
	mobile_move_direction = dir


## Reads keyboard, mouse, and mobile movement input
func _handle_input() -> void:
	# If mobile virtual joystick provides input, prioritize it
	if mobile_move_direction.length_squared() > 0.01:
		_input_direction = mobile_move_direction
	else:
		var raw_input := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
			raw_input.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
			raw_input.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
			raw_input.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
			raw_input.x += 1.0
		_input_direction = raw_input.normalized()

	# Attack input (Left Mouse Click or ui_accept or custom action)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("ui_accept"):
		perform_attack()

	# Keyboard hotkeys for Skills & Potion & Interaction
	if Input.is_action_just_pressed("skill_1") or Input.is_key_pressed(KEY_1):
		use_skill(1)
	if Input.is_action_just_pressed("skill_2") or Input.is_key_pressed(KEY_2):
		use_skill(2)
	if Input.is_action_just_pressed("skill_3") or Input.is_key_pressed(KEY_3):
		use_skill(3)
	if Input.is_action_just_pressed("potion") or Input.is_key_pressed(KEY_Q):
		use_potion()
	if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
		trigger_interaction()


## Calculates 3D camera-relative movement using camera pivot horizontal orientation
func _apply_movement(delta: float) -> void:
	var cam_forward := Vector3.FORWARD
	var cam_right := Vector3.RIGHT
	
	if camera_pivot != null:
		var cam_basis = camera_pivot.global_transform.basis
		cam_forward = -cam_basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		cam_right = cam_basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()

	# _input_direction.y is -1.0 for W/forward, +1.0 for S/backward
	# _input_direction.x is -1.0 for A/left, +1.0 for D/right
	var move_direction := (cam_forward * (-_input_direction.y) + cam_right * _input_direction.x)
	if move_direction.length_squared() > 0.01:
		move_direction = move_direction.normalized()

	var is_attacking: bool = combat != null and combat.get("is_attacking") == true
	var speed_factor: float = 0.5 if is_attacking else 1.0
	var target_speed: float = move_speed * speed_factor

	if move_direction != Vector3.ZERO:
		var target_vel = move_direction * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)


## Smoothly rotates the visual model to face the movement direction
func _apply_rotation(delta: float) -> void:
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var is_attacking: bool = combat != null and combat.get("is_attacking") == true
	var combo_index: int = combat.get("combo_index") if combat != null else 0
	if is_attacking and combo_index == 3:
		return

	if horizontal_velocity.length() > 0.2 and visuals != null:
		var target_rotation_y := atan2(-velocity.x, -velocity.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation_y, rotation_speed * delta)


func _apply_gravity(delta: float) -> void:
	if not enable_gravity:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


# ==========================================
# Combat & Actions
# ==========================================

func perform_attack() -> void:
	if not can_move:
		return
	if combat != null and combat.has_method("try_attack"):
		combat.try_attack()


func use_skill(skill_index: int) -> void:
	if not can_move:
		return
	match skill_index:
		1:
			_cast_fire_attack()
		2:
			_cast_dash()
		3:
			_cast_power_strike()


func _cast_fire_attack() -> void:
	if skill_1_cooldown > 0.0:
		return
	if not ("fire_attack" in SaveManager.unlocked_skills):
		return

	skill_1_cooldown = SKILL_1_MAX_CD
	skill_cooldown_started.emit(1, SKILL_1_MAX_CD)
	skill_used.emit(1)
	if SoundManager != null:
		SoundManager.play_skill_fire()

	# Spawn projectile facing player's visual orientation
	var proj_scene = preload("res://scenes/player/skill_projectile.tscn")
	var proj = proj_scene.instantiate()
	get_parent().add_child(proj)
	
	var forward_dir = -visuals.global_transform.basis.z if visuals != null else -global_transform.basis.z
	proj.global_position = global_position + Vector3(0, 0.8, 0) + forward_dir * 0.8
	proj.setup(forward_dir, 25)


func _cast_dash() -> void:
	if skill_2_cooldown > 0.0:
		return
	if not ("dash" in SaveManager.unlocked_skills):
		return

	skill_2_cooldown = SKILL_2_MAX_CD
	skill_cooldown_started.emit(2, SKILL_2_MAX_CD)
	skill_used.emit(2)
	if SoundManager != null:
		SoundManager.play_skill_dash()

	var forward_dir = -visuals.global_transform.basis.z if visuals != null else -global_transform.basis.z
	velocity = forward_dir * 18.0
	is_invulnerable = true

	# Dash ghost / trail visual
	if visuals != null:
		var tween = create_tween()
		tween.tween_property(visuals, "scale", Vector3(0.8, 1.2, 1.4), 0.1)
		tween.tween_property(visuals, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

	get_tree().create_timer(0.25).timeout.connect(func():
		is_invulnerable = false
	)


func _cast_power_strike() -> void:
	if skill_3_cooldown > 0.0:
		return
	if not ("power_strike" in SaveManager.unlocked_skills):
		return

	skill_3_cooldown = SKILL_3_MAX_CD
	skill_cooldown_started.emit(3, SKILL_3_MAX_CD)
	skill_used.emit(3)
	if SoundManager != null:
		SoundManager.play_skill_power()

	# Spin jump animation
	if visuals != null:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(visuals, "rotation:y", visuals.rotation.y + TAU * 2.0, 0.35)
		tween.tween_property(visuals, "position:y", 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(visuals, "position:y", 0.0, 0.17).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)

	# Area damage to nearby enemies
	get_tree().create_timer(0.2).timeout.connect(func():
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			if enemy is Node3D and is_instance_valid(enemy):
				var d = global_position.distance_to(enemy.global_position)
				if d <= 3.8 and enemy.has_method("take_damage"):
					var knock = (enemy.global_position - global_position).normalized() * 8.0
					knock.y = 0.0
					enemy.take_damage(35, knock)
	)


func use_potion() -> void:
	if GameManager != null:
		GameManager.use_potion(self)


func trigger_interaction() -> void:
	interact_requested.emit()


func _on_attack_started(attack_name: String, _combo_step: int) -> void:
	attack_performed.emit(attack_name)


func _on_attack_finished(_attack_name: String, _combo_step: int) -> void:
	pass


func take_damage(amount: int) -> void:
	if is_invulnerable:
		return

	current_hp = max(0, current_hp - amount)
	if SaveManager != null:
		SaveManager.current_hp = current_hp
	health_changed.emit(current_hp, max_hp)
	if SoundManager != null:
		SoundManager.play_hit()

	if visuals != null:
		var tween = create_tween()
		tween.tween_property(visuals, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
		tween.tween_property(visuals, "scale", Vector3(1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		die()


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	if SaveManager != null:
		SaveManager.current_hp = current_hp
	health_changed.emit(current_hp, max_hp)


func die() -> void:
	died.emit()
	can_move = false
	# Respawn in town after brief delay
	get_tree().create_timer(1.2).timeout.connect(func():
		current_hp = max_hp
		if SaveManager != null:
			SaveManager.current_hp = max_hp
			SaveManager.save_game()
		if GameManager != null:
			GameManager.change_scene_safely("res://scenes/town/town.tscn")
	)


func add_xp(amount: int) -> void:
	current_xp += amount
	if SaveManager != null:
		SaveManager.current_xp = current_xp
	xp_gained.emit(amount, current_xp, xp_to_next_level)
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level_up()


func level_up() -> void:
	level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5)
	max_hp += 15
	current_hp = max_hp
	if SaveManager != null:
		SaveManager.level = level
		SaveManager.xp_to_next = xp_to_next_level
		SaveManager.max_hp = max_hp
		SaveManager.current_hp = current_hp
		SaveManager.save_game()
	
	if SoundManager != null:
		SoundManager.play_level_up()
	leveled_up.emit(level)
	health_changed.emit(current_hp, max_hp)


func add_coins(amount: int) -> void:
	coins += amount
	if SaveManager != null:
		SaveManager.coins = coins
		SaveManager.save_game()
	coins_changed.emit(coins)
	if GameManager != null:
		GameManager.coins_updated.emit(coins)
