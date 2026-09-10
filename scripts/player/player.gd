class_name Player
extends CharacterBody3D

## Signals for future systems (combat, stats, economy, progression)
signal health_changed(current_hp: int, max_hp: int)
signal died
signal xp_gained(amount: int, current_xp: int, xp_needed: int)
signal leveled_up(new_level: int)
signal coins_changed(new_amount: int)
signal attack_performed(attack_type: String)
signal skill_used(skill_index: int)

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
@export var coins: int = 0

@export_group("Movement")
@export var move_speed: float = 6.0
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var rotation_speed: float = 14.0
@export var enable_gravity: bool = true
@export var gravity: float = 14.0

# ==========================================
# Node References
# ==========================================
@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var weapon_holder: Node3D = $Visuals/WeaponHolder
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var combat: Node = $PlayerCombat

# Internal movement state
var _input_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	
	# Connect combat signals if component is attached
	if combat != null:
		if combat.has_signal("attack_started"):
			combat.connect("attack_started", Callable(self, "_on_attack_started"))
		if combat.has_signal("attack_finished"):
			combat.connect("attack_finished", Callable(self, "_on_attack_finished"))


func _physics_process(delta: float) -> void:
	_handle_input()
	_apply_movement(delta)
	_apply_rotation(delta)
	_apply_gravity(delta)
	
	move_and_slide()


## Reads keyboard and mouse input (WASD / Arrows for move, Left Click for Attack)
func _handle_input() -> void:
	var raw_input := Vector2.ZERO
	
	# Direct keyboard check (W/A/S/D and Arrows) + default UI action fallback
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		raw_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		raw_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		raw_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		raw_input.x += 1.0
	
	# Normalize diagonal movement so speed is uniform
	_input_direction = raw_input.normalized()
	
	# Left Mouse Click triggers attack (also ready for mobile UI button via try_attack())
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("ui_accept"):
		if combat != null and combat.has_method("try_attack"):
			combat.try_attack()


## Calculates 2.5D top-down movement relative to fixed top-down camera
func _apply_movement(delta: float) -> void:
	# Screen Left/Right is X axis (-X/+X)
	# Screen Up/Down is Z axis (-Z/+Z)
	var move_direction := Vector3(_input_direction.x, 0.0, _input_direction.y)
	
	# Slightly reduce speed during active swing for tactical feel
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
	
	# Do not override rotation while mid-spin in Spin Slash
	var is_attacking: bool = combat != null and combat.get("is_attacking") == true
	var combo_index: int = combat.get("combo_index") if combat != null else 0
	if is_attacking and combo_index == 3:
		return
		
	if horizontal_velocity.length() > 0.2 and visuals != null:
		var target_rotation_y := atan2(-velocity.x, -velocity.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation_y, rotation_speed * delta)


## Applies gravity when airborne
func _apply_gravity(delta: float) -> void:
	if not enable_gravity:
		velocity.y = 0.0
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


# ==============================================================================
# Signal Handlers & Public Hooks
# ==============================================================================

func _on_attack_started(attack_name: String, _combo_step: int) -> void:
	attack_performed.emit(attack_name)


func _on_attack_finished(_attack_name: String, _combo_step: int) -> void:
	pass


func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	
	# Visual flash when player takes damage
	if visuals != null:
		var tween = create_tween()
		tween.tween_property(visuals, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
		tween.tween_property(visuals, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
		
	if current_hp <= 0:
		die()


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


func die() -> void:
	died.emit()


func add_xp(amount: int) -> void:
	current_xp += amount
	xp_gained.emit(amount, current_xp, xp_to_next_level)
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level_up()


func level_up() -> void:
	level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5)
	max_hp += 15
	current_hp = max_hp
	attack_damage += 3
	leveled_up.emit(level)
	health_changed.emit(current_hp, max_hp)


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func perform_attack() -> void:
	if combat != null and combat.has_method("try_attack"):
		combat.try_attack()


func use_skill(skill_index: int) -> void:
	skill_used.emit(skill_index)
