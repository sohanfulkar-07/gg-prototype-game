extends Node

# Official Game Identity
const GAME_NAME: String = "SwordStrike"
const GAME_VERSION: String = "5.3.50"

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added_to_tree)
	call_deferred("apply_global_graphics_and_textures")


func _on_node_added_to_tree(node: Node) -> void:
	if node.get_parent() == get_tree().root and node != self:
		call_deferred("apply_global_graphics_and_textures", node)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_handle_app_lifecycle_pause()


func _handle_back_request() -> void:
	print("GameManager: Android Back button requested.")
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	# If on Main Menu
	if current_scene.scene_file_path.ends_with("main_menu.tscn"):
		var controls_modal = current_scene.get_node_or_null("ControlsModal") as Control
		if controls_modal != null and controls_modal.visible:
			controls_modal.visible = false
			return
		get_tree().quit()
		return

	# If in Gameplay:
	# 1. Check if ShopDialog is open
	var shop = current_scene.get_node_or_null("ShopDialog")
	if shop == null:
		shop = get_tree().get_first_node_in_group("shop_dialog")
	if shop != null and shop.visible and shop.has_method("close_shop"):
		shop.close_shop()
		return

	# 2. Check if DialogueBox is active
	var dialogue = current_scene.get_node_or_null("DialogueBox")
	if dialogue == null:
		dialogue = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue != null and dialogue.visible and dialogue.has_method("_advance_dialogue"):
		dialogue._advance_dialogue()
		return

	# 3. Check GameUI pause menu
	var game_ui = current_scene.get_node_or_null("GameUI")
	if game_ui == null:
		game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("_toggle_pause"):
		game_ui._toggle_pause()
	else:
		get_tree().paused = not get_tree().paused


func _handle_app_lifecycle_pause() -> void:
	print("GameManager: App paused/unfocused, ensuring state is saved.")
	var current_scene = get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.ends_with("main_menu.tscn"):
		if SaveManager != null:
			SaveManager.save_game()
		get_tree().paused = true
		var game_ui = current_scene.get_node_or_null("GameUI")
		if game_ui == null:
			game_ui = get_tree().get_first_node_in_group("game_ui")
		if game_ui != null and "pause_menu" in game_ui and game_ui.pause_menu != null:
			game_ui.pause_menu.visible = true


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
		else:
			call_deferred("apply_global_graphics_and_textures")
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


## Universal Global Graphics & Textures System
## Enforces state-of-the-art PBR, ACES Filmic tonemapping, HDR bloom, and cascaded shadows
## across all levels, missions, and boss arenas automatically.
func apply_global_graphics_and_textures(scene_root: Node = null) -> void:
	var target = scene_root
	if target == null:
		target = get_tree().current_scene
	if target == null:
		return
		
	# 1. WorldEnvironment Configuration
	var world_env: WorldEnvironment = target.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		for child in target.get_children():
			if child is WorldEnvironment:
				world_env = child
				break
				
	if world_env == null and target is Node3D:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		target.add_child(world_env)
		
	if world_env != null:
		var env = world_env.environment
		if env == null:
			env = Environment.new()
			world_env.environment = env
			
		# Enforce ACES Filmic Tonemap for high dynamic range cinematic color grading
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.14
		env.tonemap_white = 1.05
		
		# Enforce AAA Cinematic HDR Bloom & Radiant Glow (matching high-end reference)
		env.glow_enabled = true
		env.glow_intensity = 0.95
		env.glow_bloom = 0.42
		env.glow_hdr_threshold = 0.68
		env.glow_hdr_scale = 1.8
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		
		# Enforce High-Contrast Color Grading & Rich Saturation
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.22
		env.adjustment_saturation = 1.28
		env.adjustment_brightness = 1.02
		
		# Deep Dramatic Ambient Shadows with Cool/Warm Contrast Split
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.20, 0.26, 0.40, 1) # deep slate blue shadows
		env.ambient_light_energy = 0.48 # reduced ambient fill for deep, inky shadows
		env.ambient_light_sky_contribution = 0.40
		
		# Enforce Volumetric Depth Fog with aerial perspective
		env.fog_enabled = true
		env.fog_aerial_perspective = 0.55
		env.fog_light_color = Color(0.40, 0.38, 0.50, 1)
		env.fog_density = 0.0022
		
		# Ensure Sky is present
		if env.sky == null or env.background_mode != Environment.BG_SKY:
			env.background_mode = Environment.BG_SKY
			var sky = Sky.new()
			var sky_mat = ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.25, 0.45, 0.82, 1)
			sky_mat.sky_horizon_color = Color(0.65, 0.72, 0.85, 1)
			sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.14, 1)
			sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.70, 1)
			sky.sky_material = sky_mat
			env.sky = sky
			
	# 2. Cascaded Shadows and Radiant Light Balancing
	_configure_lights_recursive(target)
	
	# 3. Enhanced PBR Textures, Metallic Specular & High-Energy Emissives
	_enhance_materials_recursive(target)


func _configure_lights_recursive(node: Node) -> void:
	if node is DirectionalLight3D:
		var dir_light = node as DirectionalLight3D
		dir_light.shadow_enabled = true
		dir_light.shadow_bias = 0.035
		dir_light.directional_shadow_split_1 = 0.08
		dir_light.directional_shadow_split_2 = 0.22
		dir_light.directional_shadow_split_3 = 0.55
		dir_light.directional_shadow_blend_splits = true
		dir_light.directional_shadow_max_distance = 180.0
		# Warm, radiant sunlight
		dir_light.light_color = Color(1.0, 0.92, 0.78, 1)
		dir_light.light_energy = maxf(dir_light.light_energy, 1.4)
	elif node is OmniLight3D:
		var omni = node as OmniLight3D
		omni.light_energy = maxf(omni.light_energy, 1.8)
		omni.omni_range = maxf(omni.omni_range, 8.5)
	elif node is SpotLight3D:
		var spot = node as SpotLight3D
		spot.light_energy = maxf(spot.light_energy, 2.0)
		
	for child in node.get_children():
		_configure_lights_recursive(child)


func _enhance_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		var mat_count = mesh_inst.get_surface_override_material_count()
		for i in range(mat_count):
			var mat = mesh_inst.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				_tune_pbr_material(mat as StandardMaterial3D)
				
		var base_mesh = mesh_inst.mesh
		if base_mesh != null:
			var surf_count = base_mesh.get_surface_count()
			for i in range(surf_count):
				var mat = base_mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					_tune_pbr_material(mat as StandardMaterial3D)
					
	for child in node.get_children():
		_enhance_materials_recursive(child)


func _tune_pbr_material(mat: StandardMaterial3D) -> void:
	# Refine metallic & roughness balance for mobile PBR (reflective highlights)
	if mat.metallic > 0.4:
		mat.metallic = maxf(mat.metallic, 0.88)
		mat.metallic_specular = 0.90
		mat.roughness = clampf(mat.roughness, 0.15, 0.35)
	else:
		mat.metallic_specular = 0.50
		mat.roughness = clampf(mat.roughness, 0.55, 0.85)
		
	# Radiant Emissive Glow (blazing core effect matching reference screenshot)
	if mat.emission_enabled:
		mat.emission_energy_multiplier = maxf(mat.emission_energy_multiplier, 5.5)