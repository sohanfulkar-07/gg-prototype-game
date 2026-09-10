class_name PlayerCombat
extends Node

## Signals for future combat, UI, and enemy integration
signal attack_started(attack_name: String, combo_index: int)
signal attack_finished(attack_name: String, combo_index: int)
signal attack_hit(target: Node3D, damage: int)

# ==========================================
# Exported Settings
# ==========================================
@export_group("Combat Tuning")
@export var attack_cooldown: float = 0.15 ## Time after an attack finishes before another can start
@export var combo_reset_delay: float = 1.2 ## Seconds of inactivity before combo resets to hit 1
@export var base_damage: int = 15

# Attack pattern definitions
const ATTACKS := [
	{ "name": "Horizontal Slash", "type": "horizontal_slash", "duration": 0.20, "lunge": 0.0 },
	{ "name": "Vertical Slash",   "type": "vertical_slash",   "duration": 0.20, "lunge": 0.0 },
	{ "name": "Spin Slash",       "type": "spin_slash",       "duration": 0.28, "lunge": 1.5 },
	{ "name": "Heavy Strike",     "type": "heavy_strike",     "duration": 0.35, "lunge": 4.0 }
]

# State variables
var is_attacking: bool = false
var combo_index: int = 0
var _cooldown_timer: float = 0.0
var _combo_timer: float = 0.0

# Initial default transforms for resetting after swings
var _weapon_initial_transform: Transform3D

# Node References
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var weapon_holder: Node3D = get_node_or_null("../Visuals/WeaponHolder")
@onready var visuals: Node3D = get_node_or_null("../Visuals")
@onready var hitbox_area: Area3D = get_node_or_null("../Visuals/WeaponHolder/AttackHitbox")
@onready var hitbox_shape: CollisionShape3D = get_node_or_null("../Visuals/WeaponHolder/AttackHitbox/CollisionShape3D")


func _ready() -> void:
	if weapon_holder != null:
		_weapon_initial_transform = weapon_holder.transform

	if hitbox_area != null:
		hitbox_area.monitoring = false
		hitbox_area.area_entered.connect(_on_hitbox_entered)
		hitbox_area.body_entered.connect(_on_hitbox_entered)
		
	if hitbox_shape != null:
		hitbox_shape.disabled = true


func _process(delta: float) -> void:
	# Update timers
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0 and not is_attacking:
			combo_index = 0


## Triggers an attack (Called by Player controller or UI Attack Button)
func try_attack() -> bool:
	if is_attacking or _cooldown_timer > 0.0:
		return false
		
	_execute_attack()
	return true


## Executes the current attack pattern in the combo sequence
func _execute_attack() -> void:
	is_attacking = true
	var current_attack = ATTACKS[combo_index]
	var attack_name: String = current_attack["name"]
	var attack_type: String = current_attack["type"]
	var duration: float = current_attack["duration"]
	var lunge_speed: float = current_attack["lunge"]

	attack_started.emit(attack_name, combo_index)

	# Apply forward lunge impulse if specified
	if lunge_speed > 0.0 and player != null and visuals != null:
		var forward_dir = -visuals.global_transform.basis.z
		player.velocity += forward_dir * lunge_speed

	# Enable attack hitbox during swing
	_set_hitbox_active(true)

	# Play procedural swing animation
	_animate_swing(attack_type, duration)

	# Schedule attack completion
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		_set_hitbox_active(false)
		_reset_weapon_transform()
		
		attack_finished.emit(attack_name, combo_index)
		
		# Advance combo step
		combo_index = (combo_index + 1) % ATTACKS.size()
		_combo_timer = combo_reset_delay
		_cooldown_timer = attack_cooldown
		is_attacking = false
	)


## Enables or disables the attack hitbox
func _set_hitbox_active(active: bool) -> void:
	if hitbox_area != null:
		hitbox_area.monitoring = active
	if hitbox_shape != null:
		hitbox_shape.disabled = not active


## Procedurally animates the 4 distinct sword attack patterns
func _animate_swing(attack_type: String, duration: float) -> void:
	if weapon_holder == null:
		return

	var tween = create_tween().set_parallel(true)
	
	match attack_type:
		"horizontal_slash":
			weapon_holder.rotation = Vector3(deg_to_rad(15), deg_to_rad(75), deg_to_rad(-20))
			tween.tween_property(weapon_holder, "rotation", Vector3(deg_to_rad(-10), deg_to_rad(-85), deg_to_rad(-40)), duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				
		"vertical_slash":
			weapon_holder.rotation = Vector3(deg_to_rad(-80), deg_to_rad(10), deg_to_rad(0))
			tween.tween_property(weapon_holder, "rotation", Vector3(deg_to_rad(70), deg_to_rad(0), deg_to_rad(0)), duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				
		"spin_slash":
			weapon_holder.rotation = Vector3(deg_to_rad(0), deg_to_rad(90), deg_to_rad(-60))
			if visuals != null:
				var target_rot_y = visuals.rotation.y + TAU
				tween.tween_property(visuals, "rotation:y", target_rot_y, duration)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					
		"heavy_strike":
			weapon_holder.rotation = Vector3(deg_to_rad(-110), deg_to_rad(0), deg_to_rad(0))
			tween.tween_property(weapon_holder, "rotation", Vector3(deg_to_rad(85), deg_to_rad(0), deg_to_rad(0)), duration)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Resets weapon to its default held transform after attack
func _reset_weapon_transform() -> void:
	if weapon_holder != null:
		var reset_tween = create_tween()
		reset_tween.tween_property(weapon_holder, "transform", _weapon_initial_transform, 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Callback when attack hitbox intersects with a node
func _on_hitbox_entered(target: Node) -> void:
	if target == player or target == hitbox_area:
		return

	# Traverse up hierarchy to find damagable target
	var damagable: Node = target
	while damagable != null and not damagable.has_method("take_damage") and damagable != get_tree().root:
		damagable = damagable.get_parent()

	if damagable != null and damagable.has_method("take_damage") and damagable != player:
		var knockback_dir := Vector3.ZERO
		if player != null and damagable is Node3D:
			knockback_dir = (damagable.global_position - player.global_position).normalized()
			knockback_dir.y = 0.0
			
		damagable.call("take_damage", base_damage, knockback_dir)
		attack_hit.emit(damagable, base_damage)
