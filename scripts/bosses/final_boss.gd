class_name FinalBoss
extends CharacterBody3D

signal boss_damaged(current: int, max_val: int)
signal boss_defeated_cinematic_started
signal boss_defeated_cinematic_finished

enum State { IDLE, CHASE, ATTACK, SPECIAL_ATTACK, HURT, DEATH, CINEMATIC }

@export var max_hp: int = 250
@export var current_hp: int = 250
@export var move_speed: float = 3.2
@export var rotation_speed: float = 8.0
@export var gravity: float = 14.0

var current_state: State = State.IDLE
var _target_player: Player = null
var _attack_cooldown_timer: float = 0.0
var _attack_phase: int = 0
var _hurt_timer: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/Body")
@onready var mask_node: MeshInstance3D = get_node_or_null("Visuals/Head/Mask")
@onready var sword_holder: Node3D = get_node_or_null("Visuals/WeaponHolder")
@onready var melee_hitbox: Area3D = get_node_or_null("Visuals/MeleeHitbox")
@onready var melee_shape: CollisionShape3D = get_node_or_null("Visuals/MeleeHitbox/CollisionShape3D")
@onready var ground_slam_indicator: MeshInstance3D = get_node_or_null("Visuals/GroundSlamIndicator")

var _original_material: Material = null


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	current_hp = max_hp

	if body_mesh != null:
		_original_material = body_mesh.get_surface_override_material(0)
		if _original_material == null and body_mesh.mesh != null:
			_original_material = body_mesh.mesh.material

	if melee_hitbox != null:
		melee_hitbox.monitoring = false
		melee_hitbox.body_entered.connect(_on_melee_hitbox_entered)

	if melee_shape != null:
		melee_shape.disabled = true

	if ground_slam_indicator != null:
		ground_slam_indicator.visible = false

	_find_player()


func _find_player() -> void:
	_target_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if current_state == State.DEATH or current_state == State.CINEMATIC:
		move_and_slide()
		return

	if _target_player == null or not is_instance_valid(_target_player):
		_find_player()

	_update_ai(delta)
	move_and_slide()


func _update_ai(delta: float) -> void:
	if _target_player == null:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return

	var dist = global_position.distance_to(_target_player.global_position)
	var player_dir = (_target_player.global_position - global_position)
	player_dir.y = 0.0

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			if dist <= 14.0:
				current_state = State.CHASE

		State.CHASE:
			if dist <= 2.2 and _attack_cooldown_timer <= 0.0:
				# Decide attack based on phase counter
				_attack_phase = (_attack_phase + 1) % 4
				match _attack_phase:
					0:
						_perform_normal_melee()
					1:
						_perform_strong_slash()
					2:
						_perform_area_slam()
					3:
						_perform_dash_charge()
			elif dist > 5.0 and _attack_cooldown_timer <= 0.0 and randf() < 0.35:
				_perform_dash_charge()
			else:
				var move_dir = player_dir.normalized()
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				if move_dir.length() > 0.1 and visuals != null:
					var target_rot = atan2(-move_dir.x, -move_dir.z)
					visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot, rotation_speed * delta)

		State.ATTACK, State.SPECIAL_ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)

		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if _hurt_timer <= 0.0:
				current_state = State.CHASE


# ==========================================
# Attack 1: Normal Melee Slash (10 DMG)
# ==========================================
func _perform_normal_melee() -> void:
	current_state = State.ATTACK
	_attack_cooldown_timer = 1.2
	_face_player()

	if SoundManager != null:
		SoundManager.play_sword_swing()

	var tween = create_tween()
	if sword_holder != null:
		tween.tween_property(sword_holder, "rotation:x", deg_to_rad(-80), 0.15)
		tween.chain().tween_property(sword_holder, "rotation:x", deg_to_rad(65), 0.15)

	get_tree().create_timer(0.15).timeout.connect(func():
		_set_melee_active(true, 10)
		get_tree().create_timer(0.18).timeout.connect(func():
			_set_melee_active(false, 0)
			if current_state != State.DEATH and current_state != State.CINEMATIC:
				current_state = State.CHASE
		)
	)


# ==========================================
# Attack 2: Strong Slash (18 DMG)
# ==========================================
func _perform_strong_slash() -> void:
	current_state = State.ATTACK
	_attack_cooldown_timer = 1.6
	_face_player()

	# Windup jump
	var tween = create_tween().set_parallel(true)
	if visuals != null:
		tween.tween_property(visuals, "position:y", 0.6, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if sword_holder != null:
		tween.tween_property(sword_holder, "rotation:x", deg_to_rad(-110), 0.25)

	get_tree().create_timer(0.28).timeout.connect(func():
		if SoundManager != null:
			SoundManager.play_boss_roar()
		var drop_tween = create_tween().set_parallel(true)
		if visuals != null:
			drop_tween.tween_property(visuals, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE)
		if sword_holder != null:
			drop_tween.tween_property(sword_holder, "rotation:x", deg_to_rad(90), 0.12)

		_set_melee_active(true, 18)
		get_tree().create_timer(0.2).timeout.connect(func():
			_set_melee_active(false, 0)
			if current_state != State.DEATH and current_state != State.CINEMATIC:
				current_state = State.CHASE
		)
	)


# ==========================================
# Attack 3: Ground Slam Shockwave AOE (20 DMG)
# ==========================================
func _perform_area_slam() -> void:
	current_state = State.SPECIAL_ATTACK
	_attack_cooldown_timer = 2.4

	# Show telegraph indicator ring
	if ground_slam_indicator != null:
		ground_slam_indicator.visible = true
		ground_slam_indicator.scale = Vector3(0.1, 0.1, 0.1)
		var ind_tween = create_tween()
		ind_tween.tween_property(ground_slam_indicator, "scale", Vector3(4.5, 1.0, 4.5), 0.6)

	# Jump into the air
	var jump_tween = create_tween()
	if visuals != null:
		jump_tween.tween_property(visuals, "position:y", 1.8, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump_tween.chain().tween_property(visuals, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	get_tree().create_timer(0.6).timeout.connect(func():
		if ground_slam_indicator != null:
			ground_slam_indicator.visible = false
		if SoundManager != null:
			SoundManager.play_hit()
			SoundManager.play_boss_roar()

		# Hit player if within radius
		if _target_player != null and is_instance_valid(_target_player):
			var d = global_position.distance_to(_target_player.global_position)
			if d <= 4.5:
				_target_player.take_damage(20)

		if current_state != State.DEATH and current_state != State.CINEMATIC:
			current_state = State.CHASE
	)


# ==========================================
# Attack 4: Dash / Charge Strike (15 DMG)
# ==========================================
func _perform_dash_charge() -> void:
	current_state = State.SPECIAL_ATTACK
	_attack_cooldown_timer = 2.0
	_face_player()

	if visuals == null or _target_player == null:
		current_state = State.CHASE
		return

	var forward_dir = -visuals.global_transform.basis.z
	velocity = forward_dir * 16.0
	_set_melee_active(true, 15)

	if SoundManager != null:
		SoundManager.play_skill_dash()

	get_tree().create_timer(0.35).timeout.connect(func():
		velocity = Vector3.ZERO
		_set_melee_active(false, 0)
		if current_state != State.DEATH and current_state != State.CINEMATIC:
			current_state = State.CHASE
	)


func _face_player() -> void:
	if _target_player != null and visuals != null:
		var dir = (_target_player.global_position - global_position).normalized()
		dir.y = 0.0
		if dir.length() > 0.1:
			visuals.rotation.y = atan2(-dir.x, -dir.z)


var _active_melee_damage: int = 0
func _set_melee_active(active: bool, dmg: int = 0) -> void:
	_active_melee_damage = dmg
	if melee_hitbox != null:
		melee_hitbox.monitoring = active
	if melee_shape != null:
		melee_shape.disabled = not active


func _on_melee_hitbox_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_active_melee_damage)


func take_damage(amount: int, _knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEATH or current_state == State.CINEMATIC:
		return

	current_hp = max(0, current_hp - amount)
	boss_damaged.emit(current_hp, max_hp)
	if SoundManager != null:
		SoundManager.play_hit()

	_flash_hurt()

	if current_hp <= 0:
		_start_defeat_and_reveal()
	else:
		if current_state != State.SPECIAL_ATTACK:
			current_state = State.HURT
			_hurt_timer = 0.2


func _flash_hurt() -> void:
	if body_mesh == null:
		return
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
	body_mesh.set_surface_override_material(0, flash_mat)
	get_tree().create_timer(0.12).timeout.connect(func():
		if body_mesh != null:
			body_mesh.set_surface_override_material(0, _original_material)
	)


# ==========================================
# Defeat & Older Brother Reveal Sequence
# ==========================================
func _start_defeat_and_reveal() -> void:
	current_state = State.CINEMATIC
	velocity = Vector3.ZERO
	_set_melee_active(false, 0)
	if collision_shape != null:
		collision_shape.disabled = true

	# Kneel down animation
	var kneel_tween = create_tween().set_parallel(true)
	if visuals != null:
		kneel_tween.tween_property(visuals, "position:y", -0.45, 0.6).set_trans(Tween.TRANS_QUAD)
		kneel_tween.tween_property(visuals, "rotation:x", deg_to_rad(20), 0.6)
	if sword_holder != null:
		kneel_tween.tween_property(sword_holder, "position:y", -0.4, 0.4)
		kneel_tween.tween_property(sword_holder, "rotation:z", deg_to_rad(90), 0.4)

	# Mask detaches and pops off
	get_tree().create_timer(0.6).timeout.connect(func():
		if mask_node != null:
			var mask_tween = create_tween().set_parallel(true)
			mask_tween.tween_property(mask_node, "position", Vector3(0.2, 0.1, -1.2), 0.45).set_trans(Tween.TRANS_QUAD)
			mask_tween.tween_property(mask_node, "rotation:x", deg_to_rad(120), 0.45)
		
		# Boss defeat cinematic started
		boss_defeated_cinematic_started.emit()
	)
