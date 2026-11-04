class_name MainMenuEnvironment
extends Node3D

signal shot_changed(shot_index: int, shot_name: String)
signal cinematic_completed

@onready var camera: Camera3D = $Camera3D
@onready var hero_visuals: Node3D = $Hero/Visuals
@onready var hero_sword: Node3D = get_node_or_null("Hero/Visuals/WeaponHolder/Sword")
@onready var hero_blade: MeshInstance3D = get_node_or_null("Hero/Visuals/WeaponHolder/Sword/Blade")
@onready var hero_feather: Node3D = get_node_or_null("Hero/Visuals/Head/HatBrim/Feather")
@onready var hero_left_arm: Node3D = get_node_or_null("Hero/Visuals/LeftArm")
@onready var hero_right_arm: Node3D = get_node_or_null("Hero/Visuals/RightArm")

# Environment lights and banners
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var lantern_light_1: OmniLight3D = get_node_or_null("Lanterns/Lantern1/Lamp/WarmLight")
@onready var lantern_light_2: OmniLight3D = get_node_or_null("Lanterns/Lantern2/Lamp/WarmLight")
@onready var flag_banner: Node3D = get_node_or_null("Banners/FlagPole/Banner")
@onready var smoke_particles: GPUParticles3D = get_node_or_null("ChimneySmoke")
@onready var town_guard: Node3D = get_node_or_null("NPCs/TownGuard")
@onready var town_elder: Node3D = get_node_or_null("NPCs/TownElder")

# State
enum State { CINEMATIC, MENU_IDLE }
var current_state: State = State.MENU_IDLE

var _cinematic_time: float = 0.0
var _anim_time: float = 0.0
var _idle_time: float = 0.0
var _current_shot: int = 1

# Camera waypoints for cinematic sequence
# Each shot defines start_pos, end_pos, start_rot, end_rot, duration
const SHOT_1_DURATION := 2.5 # Darkness / Mountains
const SHOT_2_DURATION := 3.6 # The World & Valley
const SHOT_3_DURATION := 3.8 # The Kingdom & Town
const SHOT_4_DURATION := 3.6 # The Hero Overlook
const SHOT_5_DURATION := 2.2 # Title Reveal & Settle

# Final Main Menu idle camera base transform
var menu_cam_pos := Vector3(-0.35, 1.45, 0.95)
var menu_cam_rot := Vector3(-0.06, 0.42, 0.0)


func _ready() -> void:
	# Synchronize hero weapon with SaveManager if available
	_setup_hero_visuals()


func _setup_hero_visuals() -> void:
	if hero_blade != null:
		var mat = StandardMaterial3D.new()
		var weapon_id = SaveManager.current_weapon if SaveManager != null else "basic_sword"
		if weapon_id == "advanced_sword":
			mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0)
			mat.metallic = 0.95
			mat.roughness = 0.15
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.2, 1.0)
			mat.emission_energy_multiplier = 0.5
		else:
			mat.albedo_color = Color(0.9, 0.93, 0.96, 1.0)
			mat.metallic = 0.88
			mat.roughness = 0.2
		hero_blade.set_surface_override_material(0, mat)


func start_cinematic() -> void:
	current_state = State.CINEMATIC
	_cinematic_time = 0.0
	_current_shot = 1
	_apply_cinematic_camera(0.0)
	shot_changed.emit(1, "Darkness")


func skip_to_menu() -> void:
	current_state = State.MENU_IDLE
	_cinematic_time = 999.0
	_current_shot = 5
	if camera != null:
		camera.position = menu_cam_pos
		camera.rotation = menu_cam_rot
		camera.fov = 48.0
	cinematic_completed.emit()


func _process(delta: float) -> void:
	_anim_time += delta
	_animate_environment(delta)
	_animate_hero(delta)

	match current_state:
		State.CINEMATIC:
			_process_cinematic(delta)
		State.MENU_IDLE:
			_process_menu_idle(delta)


func _process_cinematic(delta: float) -> void:
	_cinematic_time += delta

	var t1 = SHOT_1_DURATION
	var t2 = t1 + SHOT_2_DURATION
	var t3 = t2 + SHOT_3_DURATION
	var t4 = t3 + SHOT_4_DURATION
	var t5 = t4 + SHOT_5_DURATION

	if _cinematic_time < t1:
		if _current_shot != 1:
			_current_shot = 1
			shot_changed.emit(1, "Darkness")
		var p = _cinematic_time / t1
		_interpolate_camera(
			Vector3(-8.0, 16.0, -16.0), Vector3(-6.0, 14.5, -14.0),
			Vector3(-0.35, 0.45, 0.0), Vector3(-0.30, 0.40, 0.0),
			p, 52.0
		)
	elif _cinematic_time < t2:
		if _current_shot != 2:
			_current_shot = 2
			shot_changed.emit(2, "The World")
		var p = (_cinematic_time - t1) / SHOT_2_DURATION
		# Sweeping through misty mountains and forest canopy
		_interpolate_camera(
			Vector3(-10.0, 12.0, -8.0), Vector3(-2.5, 6.5, -4.5),
			Vector3(-0.25, 0.65, 0.0), Vector3(-0.18, 0.35, 0.0),
			p, 50.0
		)
	elif _cinematic_time < t3:
		if _current_shot != 3:
			_current_shot = 3
			shot_changed.emit(3, "The Kingdom")
		var p = (_cinematic_time - t2) / SHOT_3_DURATION
		# Gliding along the town entrance and timber buildings
		_interpolate_camera(
			Vector3(-1.8, 3.4, -4.0), Vector3(0.2, 2.1, 0.0),
			Vector3(-0.12, 0.28, 0.0), Vector3(-0.08, 0.38, 0.0),
			p, 49.0
		)
	elif _cinematic_time < t4:
		if _current_shot != 4:
			_current_shot = 4
			shot_changed.emit(4, "The Hero")
		var p = (_cinematic_time - t3) / SHOT_4_DURATION
		# Pushing in smoothly toward the hero on the stone bluff
		_interpolate_camera(
			Vector3(0.6, 1.4, 1.8), menu_cam_pos + Vector3(0.2, 0.1, 0.3),
			Vector3(-0.04, 0.48, 0.0), menu_cam_rot,
			p, 48.0
		)
	elif _cinematic_time < t5:
		if _current_shot != 5:
			_current_shot = 5
			shot_changed.emit(5, "Title Reveal")
		var p = (_cinematic_time - t4) / SHOT_5_DURATION
		# Final settle into the Main Menu framing
		_interpolate_camera(
			menu_cam_pos + Vector3(0.2, 0.1, 0.3), menu_cam_pos,
			menu_cam_rot, menu_cam_rot,
			p, 48.0
		)
	else:
		# Sequence finished -> transition to continuous Menu Idle
		current_state = State.MENU_IDLE
		cinematic_completed.emit()


func _interpolate_camera(p1: Vector3, p2: Vector3, r1: Vector3, r2: Vector3, progress: float, fov_val: float) -> void:
	if camera == null:
		return
	# Smooth cubic ease-in-out curve
	var eased = progress * progress * (3.0 - 2.0 * progress)
	camera.position = p1.lerp(p2, eased)
	camera.rotation.x = lerp_angle(r1.x, r2.x, eased)
	camera.rotation.y = lerp_angle(r1.y, r2.y, eased)
	camera.rotation.z = lerp_angle(r1.z, r2.z, eased)
	camera.fov = fov_val


func _apply_cinematic_camera(_progress: float) -> void:
	if camera == null:
		return
	camera.position = Vector3(-8.0, 16.0, -16.0)
	camera.rotation = Vector3(-0.35, 0.45, 0.0)
	camera.fov = 52.0


## Living 3D background camera: slow, breathing drift that keeps the scene dynamic behind the menu
func _process_menu_idle(delta: float) -> void:
	if camera == null:
		return
	_idle_time += delta
	var sway_x = sin(_idle_time * 0.35) * 0.06
	var sway_y = cos(_idle_time * 0.28) * 0.035
	var sway_rot = sin(_idle_time * 0.22) * 0.012

	camera.position = menu_cam_pos + Vector3(sway_x, sway_y, 0.0)
	camera.rotation.x = menu_cam_rot.x + (sway_y * 0.1)
	camera.rotation.y = menu_cam_rot.y + sway_rot
	camera.rotation.z = 0.0


## Natural procedural idle animation for the Hero character
func _animate_hero(_delta: float) -> void:
	if hero_visuals == null:
		return
	# Subtle grounded breathing cycle
	var breath = sin(_anim_time * 2.2) * 0.01
	hero_visuals.position.y = breath
	
	# Feather sway in mountain breeze
	if hero_feather != null:
		hero_feather.rotation.z = sin(_anim_time * 3.4) * 0.06 + 0.04
	
	# Relaxed resting limbs with subtle weapon grip motion
	if hero_left_arm != null:
		hero_left_arm.rotation.x = sin(_anim_time * 1.8) * 0.03
	if hero_right_arm != null:
		hero_right_arm.rotation.x = -0.15 + cos(_anim_time * 1.8) * 0.02


## Atmospheric environmental animation: banner flutter, warm lantern flicker, NPC idle
func _animate_environment(_delta: float) -> void:
	# Banners swaying in the morning breeze
	if flag_banner != null:
		flag_banner.rotation.z = sin(_anim_time * 3.6) * 0.14 + sin(_anim_time * 7.2) * 0.04

	# Subtle lantern light flickering
	var flicker = sin(_anim_time * 7.5) * 0.12 + cos(_anim_time * 11.0) * 0.06
	if lantern_light_1 != null:
		lantern_light_1.light_energy = 1.9 + flicker
	if lantern_light_2 != null:
		lantern_light_2.light_energy = 1.8 - flicker

	# Subtle NPC life
	if town_guard != null:
		town_guard.rotation.y = sin(_anim_time * 0.8) * 0.04
	if town_elder != null:
		town_elder.position.y = sin(_anim_time * 1.4) * 0.012
