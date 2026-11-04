class_name GameUI
extends CanvasLayer

signal attack_pressed
signal skill_pressed(index: int)
signal potion_pressed
signal interact_pressed
signal pause_toggled(is_paused: bool)

# Top HUD elements
@onready var hud_top_left: Control = $HUD/TopLeft
@onready var hp_bar: ProgressBar = $HUD/TopLeft/MarginContainer/VBox/HPBar
@onready var hp_label: Label = $HUD/TopLeft/MarginContainer/VBox/HPBar/HPLabel
@onready var xp_bar: ProgressBar = $HUD/TopLeft/MarginContainer/VBox/XPBar
@onready var level_label: Label = $HUD/TopLeft/MarginContainer/VBox/HeaderRow/LevelBadge/Margin/LevelLabel
@onready var coin_label: Label = $HUD/TopLeft/MarginContainer/VBox/HeaderRow/CoinContainer/CoinLabel
@onready var potion_button: Button = $HUD/TopRight/PotionButton
@onready var pause_button: Button = $HUD/TopRight/PauseButton
@onready var objective_label: Label = $HUD/TopCenter/ObjectivePanel/Margin/ObjectiveLabel
@onready var boss_container: VBoxContainer = $HUD/TopCenter/BossContainer
@onready var boss_bar: ProgressBar = $HUD/TopCenter/BossContainer/BossBar
@onready var boss_label: Label = $HUD/TopCenter/BossContainer/BossLabel

# Combat Cluster & Action buttons
@onready var btn_attack: Button = $HUD/BottomRight/BtnAttack
@onready var combo_badge: PanelContainer = $HUD/BottomRight/ComboBadge
@onready var combo_label: Label = $HUD/BottomRight/ComboBadge/Margin/ComboLabel
@onready var btn_skill_1: Button = $HUD/BottomRight/BtnSkill1
@onready var btn_skill_2: Button = $HUD/BottomRight/BtnSkill2
@onready var btn_skill_3: Button = $HUD/BottomRight/BtnSkill3
@onready var btn_jump: Button = $HUD/BottomRight/BtnJump
@onready var btn_interact: Button = $HUD/BottomRight/BtnInteract

# Pause menu
@onready var pause_menu: Control = $PauseMenu
@onready var btn_resume: Button = $PauseMenu/Panel/VBox/BtnResume
@onready var btn_save: Button = $PauseMenu/Panel/VBox/BtnSave
@onready var btn_quit_menu: Button = $PauseMenu/Panel/VBox/BtnQuitMenu
@onready var pause_status: Label = $PauseMenu/Panel/VBox/StatusLabel

# Virtual Joystick elements
@onready var joystick_base: Control = $HUD/BottomLeft/JoystickBase
@onready var joystick_handle: Control = $HUD/BottomLeft/JoystickBase/Handle

var _is_dragging_joystick: bool = false
var _joystick_touch_id: int = -1
var _joystick_radius: float = 65.0
const JOYSTICK_DEADZONE: float = 0.12

var _player: Player = null

@export_group("Mobile Camera")
@export var mobile_camera_sensitivity: float = 0.005

var _is_swiping_camera: bool = false
var _camera_touch_id: int = -1
var _combo_fade_tween: Tween = null
var _active_button_touches: Dictionary = {}


func _ready() -> void:
	add_to_group("game_ui")
	# Hide contextual and modal elements by default
	if boss_container != null:
		boss_container.visible = false
	if pause_menu != null:
		pause_menu.visible = false
	if btn_interact != null:
		btn_interact.visible = false
	if combo_badge != null:
		combo_badge.modulate.a = 0.0

	# Connect action buttons
	if btn_attack != null:
		btn_attack.pressed.connect(_on_attack_pressed)
		_setup_button_juice(btn_attack)
	if btn_jump != null:
		btn_jump.pressed.connect(_on_jump_pressed)
		_setup_button_juice(btn_jump)
	if btn_skill_1 != null:
		btn_skill_1.pressed.connect(func(): _on_skill_pressed(1))
		_setup_button_juice(btn_skill_1)
	if btn_skill_2 != null:
		btn_skill_2.pressed.connect(func(): _on_skill_pressed(2))
		_setup_button_juice(btn_skill_2)
	if btn_skill_3 != null:
		btn_skill_3.pressed.connect(func(): _on_skill_pressed(3))
		_setup_button_juice(btn_skill_3)
	if potion_button != null:
		potion_button.pressed.connect(_on_potion_pressed)
		_setup_button_juice(potion_button)
	if pause_button != null:
		pause_button.pressed.connect(_toggle_pause)
		_setup_button_juice(pause_button)
	if btn_interact != null:
		btn_interact.pressed.connect(_on_interact_pressed)
		_setup_button_juice(btn_interact)

	# Pause menu buttons
	if btn_resume != null:
		btn_resume.pressed.connect(_toggle_pause)
	if btn_save != null:
		btn_save.pressed.connect(_on_save_clicked)
	if btn_quit_menu != null:
		btn_quit_menu.pressed.connect(_on_quit_to_menu)

	# Connect GameManager signals
	if GameManager != null:
		GameManager.coins_updated.connect(update_coins)
		GameManager.inventory_updated.connect(_update_inventory_display)

	# Safe area and responsive adaptation for modern phone aspect ratios
	_apply_safe_area()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_apply_safe_area)

	_find_and_bind_player()
	_update_all_hud()


## Adds dynamic tactile spring feedback when buttons are tapped/pressed
func _setup_button_juice(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _find_and_bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.health_changed.connect(update_health)
		_player.xp_gained.connect(update_xp)
		_player.leveled_up.connect(func(lvl: int): update_level(lvl))
		_player.coins_changed.connect(update_coins)
		if _player.has_signal("combo_step_changed"):
			_player.combo_step_changed.connect(update_combo)
		update_health(_player.current_hp, _player.max_hp)
		update_level(_player.level)
		update_xp(0, _player.current_xp, _player.xp_to_next_level)


func _process(_delta: float) -> void:
	_update_skill_buttons()


func _update_all_hud() -> void:
	if SaveManager != null:
		update_coins(SaveManager.coins)
		update_potions(SaveManager.potion_count)
		update_level(SaveManager.level)
		update_health(SaveManager.current_hp, SaveManager.max_hp)
		update_xp(0, SaveManager.current_xp, SaveManager.xp_to_next)
	_update_skill_buttons()


func _update_inventory_display() -> void:
	if SaveManager != null:
		update_potions(SaveManager.potion_count)
	_update_skill_buttons()


func update_health(current: int, max_val: int) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_val
		hp_bar.value = current
	if hp_label != null:
		hp_label.text = "HP %d / %d" % [current, max_val]


func update_xp(_gained: int, current: int, needed: int) -> void:
	if xp_bar != null:
		xp_bar.max_value = needed
		xp_bar.value = current


func update_level(lvl: int) -> void:
	if level_label != null:
		level_label.text = "LVL %d" % lvl


func update_coins(amount: int) -> void:
	if coin_label != null:
		coin_label.text = "%d Coins" % amount


func update_potions(count: int) -> void:
	if potion_button != null:
		potion_button.text = "♥ Potion ×%d" % count
		if count > 0:
			potion_button.disabled = false
			potion_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			potion_button.disabled = true
			potion_button.modulate = Color(0.65, 0.65, 0.65, 0.6)


func update_combo(step: int) -> void:
	if combo_badge == null or combo_label == null:
		return

	if step <= 0:
		if _combo_fade_tween != null and _combo_fade_tween.is_valid():
			_combo_fade_tween.kill()
		_combo_fade_tween = create_tween()
		_combo_fade_tween.tween_property(combo_badge, "modulate:a", 0.0, 0.35)
		return

	combo_badge.modulate.a = 1.0
	match step:
		1:
			combo_label.text = "Combo: [1] → 2 → 3 → 4"
			combo_label.modulate = Color(1.0, 0.95, 0.6)
		2:
			combo_label.text = "Combo: 1 → [2] → 3 → 4"
			combo_label.modulate = Color(1.0, 0.82, 0.3)
		3:
			combo_label.text = "Combo: 1 → 2 → [3] → 4"
			combo_label.modulate = Color(1.0, 0.65, 0.2)
		4:
			combo_label.text = "Combo: 1 → 2 → 3 → [4] FINISH!"
			combo_label.modulate = Color(1.0, 0.35, 0.25)

	if _combo_fade_tween != null and _combo_fade_tween.is_valid():
		_combo_fade_tween.kill()
	_combo_fade_tween = create_tween()
	_combo_fade_tween.tween_interval(1.1)
	_combo_fade_tween.tween_property(combo_badge, "modulate:a", 0.0, 0.35)


func set_objective(text: String, color: Color = Color(1, 0.9, 0.45)) -> void:
	if objective_label != null:
		objective_label.text = text
		objective_label.modulate = color


func show_boss_bar(boss_name: String, current_hp: int, max_hp: int) -> void:
	if boss_container != null:
		boss_container.visible = true
	if boss_label != null:
		boss_label.text = boss_name
	if boss_bar != null:
		boss_bar.max_value = max_hp
		boss_bar.value = current_hp


func update_boss_hp(current_hp: int) -> void:
	if boss_bar != null:
		boss_bar.value = current_hp


func hide_boss_bar() -> void:
	if boss_container != null:
		boss_container.visible = false


func set_interact_prompt(text: String, is_visible: bool) -> void:
	if btn_interact != null:
		btn_interact.visible = is_visible
		if is_visible and text != "":
			btn_interact.text = text


func _update_skill_buttons() -> void:
	if SaveManager == null or _player == null:
		return

	# Skill 1 (Fire)
	var has_fire = "fire_attack" in SaveManager.unlocked_skills
	if btn_skill_1 != null:
		if not has_fire:
			btn_skill_1.disabled = true
			btn_skill_1.text = "🔒\n1"
			btn_skill_1.modulate = Color(0.6, 0.6, 0.6, 0.6)
		else:
			if _player.skill_1_cooldown > 0.0:
				btn_skill_1.disabled = true
				btn_skill_1.text = "🔥\n%.1fs" % _player.skill_1_cooldown
				btn_skill_1.modulate = Color(0.75, 0.75, 0.75, 0.75)
			else:
				btn_skill_1.disabled = false
				btn_skill_1.text = "🔥\n1"
				btn_skill_1.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Skill 2 (Dash)
	var has_dash = "dash" in SaveManager.unlocked_skills
	if btn_skill_2 != null:
		if not has_dash:
			btn_skill_2.disabled = true
			btn_skill_2.text = "🔒\n2"
			btn_skill_2.modulate = Color(0.6, 0.6, 0.6, 0.6)
		else:
			if _player.skill_2_cooldown > 0.0:
				btn_skill_2.disabled = true
				btn_skill_2.text = "⚡\n%.1fs" % _player.skill_2_cooldown
				btn_skill_2.modulate = Color(0.75, 0.75, 0.75, 0.75)
			else:
				btn_skill_2.disabled = false
				btn_skill_2.text = "⚡\n2"
				btn_skill_2.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Skill 3 (Power)
	var has_power = "power_strike" in SaveManager.unlocked_skills
	if btn_skill_3 != null:
		if not has_power:
			btn_skill_3.disabled = true
			btn_skill_3.text = "🔒\n3"
			btn_skill_3.modulate = Color(0.6, 0.6, 0.6, 0.6)
		else:
			if _player.skill_3_cooldown > 0.0:
				btn_skill_3.disabled = true
				btn_skill_3.text = "💥\n%.1fs" % _player.skill_3_cooldown
				btn_skill_3.modulate = Color(0.75, 0.75, 0.75, 0.75)
			else:
				btn_skill_3.disabled = false
				btn_skill_3.text = "💥\n3"
				btn_skill_3.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_attack_pressed() -> void:
	if _player != null:
		_player.perform_attack()
	attack_pressed.emit()


func _on_jump_pressed() -> void:
	if _player != null:
		_player.perform_jump()


func _on_skill_pressed(index: int) -> void:
	if _player != null:
		_player.use_skill(index)
	skill_pressed.emit(index)


func _on_potion_pressed() -> void:
	if _player != null:
		_player.use_potion()
	potion_pressed.emit()


func _on_interact_pressed() -> void:
	if _player != null:
		_player.trigger_interaction()
	interact_pressed.emit()


# ==========================================
# Virtual Joystick & Camera Swipe Multi-Touch
# ==========================================

func _apply_safe_area() -> void:
	var safe_rect = DisplayServer.get_display_safe_area()
	var vp_size = get_viewport().get_visible_rect().size
	var window_size = DisplayServer.window_get_size()

	var margin_left: float = 20.0
	var margin_right: float = 20.0
	var margin_top: float = 16.0
	var margin_bottom: float = 20.0

	if window_size.x > 0 and window_size.y > 0:
		var scale_x = vp_size.x / float(window_size.x)
		var scale_y = vp_size.y / float(window_size.y)
		var inset_left = safe_rect.position.x * scale_x
		var inset_right = (window_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x
		var inset_top = safe_rect.position.y * scale_y
		var inset_bottom = (window_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y

		margin_left = max(margin_left, inset_left)
		margin_right = max(margin_right, inset_right)
		margin_top = max(margin_top, inset_top)
		margin_bottom = max(margin_bottom, inset_bottom)

	if hud_top_left != null:
		hud_top_left.offset_left = margin_left
		hud_top_left.offset_top = margin_top

	var hud_top_right = get_node_or_null("HUD/TopRight") as Control
	if hud_top_right != null:
		hud_top_right.offset_right = -margin_right
		hud_top_right.offset_top = margin_top

	var hud_bottom_left = get_node_or_null("HUD/BottomLeft") as Control
	if hud_bottom_left != null:
		hud_bottom_left.offset_left = margin_left + 10.0
		hud_bottom_left.offset_bottom = -margin_bottom

	var hud_bottom_right = get_node_or_null("HUD/BottomRight") as Control
	if hud_bottom_right != null:
		hud_bottom_right.offset_right = -margin_right
		hud_bottom_right.offset_bottom = -margin_bottom


func _animate_button_press(btn: Button, is_down: bool) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var tween = create_tween()
	if is_down:
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_touch_on_action_button(pos: Vector2) -> bool:
	var buttons = [btn_attack, btn_jump, btn_skill_1, btn_skill_2, btn_skill_3, btn_interact, potion_button, pause_button]
	for btn in buttons:
		if btn != null and btn.is_visible_in_tree() and btn.get_global_rect().has_point(pos):
			return true
	if pause_menu != null and pause_menu.visible:
		return true
	if hud_top_left != null and hud_top_left.get_global_rect().has_point(pos):
		return true
	return false


func _dispatch_button_touch_down(pos: Vector2, touch_id: int) -> bool:
	# If pause menu is visible, handle pause menu buttons directly
	if pause_menu != null and pause_menu.visible:
		if btn_resume != null and btn_resume.get_global_rect().has_point(pos):
			_toggle_pause()
			return true
		elif btn_save != null and btn_save.get_global_rect().has_point(pos):
			_on_save_clicked()
			return true
		elif btn_quit_menu != null and btn_quit_menu.get_global_rect().has_point(pos):
			_on_quit_to_menu()
			return true
		return true

	# Check combat and HUD buttons
	if btn_attack != null and btn_attack.is_visible_in_tree() and btn_attack.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_attack
		_animate_button_press(btn_attack, true)
		_on_attack_pressed()
		return true
	elif btn_jump != null and btn_jump.is_visible_in_tree() and btn_jump.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_jump
		_animate_button_press(btn_jump, true)
		_on_jump_pressed()
		return true
	elif btn_skill_1 != null and btn_skill_1.is_visible_in_tree() and btn_skill_1.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_skill_1
		_animate_button_press(btn_skill_1, true)
		_on_skill_pressed(1)
		return true
	elif btn_skill_2 != null and btn_skill_2.is_visible_in_tree() and btn_skill_2.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_skill_2
		_animate_button_press(btn_skill_2, true)
		_on_skill_pressed(2)
		return true
	elif btn_skill_3 != null and btn_skill_3.is_visible_in_tree() and btn_skill_3.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_skill_3
		_animate_button_press(btn_skill_3, true)
		_on_skill_pressed(3)
		return true
	elif btn_interact != null and btn_interact.is_visible_in_tree() and btn_interact.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = btn_interact
		_animate_button_press(btn_interact, true)
		_on_interact_pressed()
		return true
	elif potion_button != null and potion_button.is_visible_in_tree() and potion_button.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = potion_button
		_animate_button_press(potion_button, true)
		_on_potion_pressed()
		return true
	elif pause_button != null and pause_button.is_visible_in_tree() and pause_button.get_global_rect().has_point(pos):
		_active_button_touches[touch_id] = pause_button
		_animate_button_press(pause_button, true)
		_toggle_pause()
		return true

	return false


func _dispatch_button_touch_up(touch_id: int) -> void:
	if touch_id in _active_button_touches:
		var btn = _active_button_touches[touch_id]
		_animate_button_press(btn, false)
		_active_button_touches.erase(touch_id)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_toggle_pause()

	# Mobile multi-touch input
	if event is InputEventScreenTouch:
		if event.pressed:
			# 1. Check if touch lands on any interactive button
			if _dispatch_button_touch_down(event.position, event.index):
				return

			# 2. Check virtual joystick touch (left area)
			var joystick_rect = joystick_base.get_global_rect().grow(45.0) if joystick_base != null else Rect2()
			if joystick_rect.has_point(event.position):
				_is_dragging_joystick = true
				_joystick_touch_id = event.index
				_update_joystick_pos(event.position)
				return
			elif event.position.x < get_viewport().get_visible_rect().size.x * 0.4 and not _is_dragging_joystick:
				_is_dragging_joystick = true
				_joystick_touch_id = event.index
				_update_joystick_pos(event.position)
				return

			# 3. Check right-side camera rotation swipe area (guaranteed not on buttons)
			if event.position.x >= get_viewport().get_visible_rect().size.x * 0.35 and not _is_touch_on_action_button(event.position):
				_is_swiping_camera = true
				_camera_touch_id = event.index
		else:
			if event.index == _joystick_touch_id:
				_reset_joystick()
			if event.index == _camera_touch_id:
				_is_swiping_camera = false
				_camera_touch_id = -1
			_dispatch_button_touch_up(event.index)

	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_id and _is_dragging_joystick:
			_update_joystick_pos(event.position)
		elif event.index == _camera_touch_id and _is_swiping_camera:
			if _player != null and _player.has_method("rotate_camera"):
				_player.rotate_camera(event.relative.x * mobile_camera_sensitivity, event.relative.y * mobile_camera_sensitivity)

	# Desktop PC mouse testing for virtual joystick and camera drag
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _dispatch_button_touch_down(event.position, -99):
					return
				var joystick_rect = joystick_base.get_global_rect().grow(45.0) if joystick_base != null else Rect2()
				if joystick_rect.has_point(event.position):
					_is_dragging_joystick = true
					_joystick_touch_id = -99
					_update_joystick_pos(event.position)
				elif event.position.x > get_viewport().get_visible_rect().size.x * 0.38 and not _is_touch_on_action_button(event.position):
					_is_swiping_camera = true
					_camera_touch_id = -88
			else:
				if _joystick_touch_id == -99:
					_reset_joystick()
				if _camera_touch_id == -88:
					_is_swiping_camera = false
					_camera_touch_id = -1
				_dispatch_button_touch_up(-99)

	elif event is InputEventMouseMotion:
		if _is_dragging_joystick and _joystick_touch_id == -99:
			_update_joystick_pos(event.position)
		elif _is_swiping_camera and _camera_touch_id == -88:
			if _player != null and _player.has_method("rotate_camera"):
				_player.rotate_camera(event.relative.x * mobile_camera_sensitivity, event.relative.y * mobile_camera_sensitivity)


func _update_joystick_pos(touch_pos: Vector2) -> void:
	if joystick_base == null:
		return
	var base_center = joystick_base.global_position + joystick_base.size * 0.5
	var offset = touch_pos - base_center
	var dist = offset.length()
	var dir = offset.normalized() if dist > 0.001 else Vector2.ZERO

	if dist > _joystick_radius:
		offset = dir * _joystick_radius
		dist = _joystick_radius

	if joystick_handle != null:
		joystick_handle.position = (joystick_base.size * 0.5) + offset - (joystick_handle.size * 0.5)

	# Calculate normalized output with deadzone and progressive ramp
	var normalized_dist = dist / _joystick_radius
	if normalized_dist < JOYSTICK_DEADZONE:
		if _player != null:
			_player.set_mobile_move(Vector2.ZERO)
	else:
		var adjusted_mag = (normalized_dist - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE)
		var move_vec = dir * clamp(adjusted_mag, 0.0, 1.0)
		if _player != null:
			_player.set_mobile_move(move_vec)


func _reset_joystick() -> void:
	_is_dragging_joystick = false
	_joystick_touch_id = -1
	if joystick_handle != null and joystick_base != null:
		joystick_handle.position = (joystick_base.size * 0.5) - (joystick_handle.size * 0.5)
	if _player != null:
		_player.set_mobile_move(Vector2.ZERO)


# ==========================================
# Pause Menu
# ==========================================

func _toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	if pause_menu != null:
		pause_menu.visible = is_paused
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_toggled.emit(is_paused)


func _on_save_clicked() -> void:
	if SaveManager != null:
		SaveManager.save_game()
		if pause_status != null:
			pause_status.text = "Game Saved Successfully!"
			pause_status.modulate = Color(0.3, 1.0, 0.4)


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameManager != null:
		GameManager.change_scene_safely("res://scenes/ui/main_menu.tscn")
