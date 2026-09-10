class_name GameUI
extends CanvasLayer

signal attack_pressed
signal skill_pressed(index: int)
signal potion_pressed
signal interact_pressed
signal pause_toggled(is_paused: bool)

@onready var hp_bar: ProgressBar = $HUD/TopLeft/HPBar
@onready var hp_label: Label = $HUD/TopLeft/HPBar/HPLabel
@onready var xp_bar: ProgressBar = $HUD/TopLeft/XPBar
@onready var level_label: Label = $HUD/TopLeft/LevelLabel
@onready var coin_label: Label = $HUD/TopRight/CoinContainer/CoinLabel
@onready var potion_button: Button = $HUD/TopRight/PotionButton
@onready var objective_label: Label = $HUD/TopCenter/ObjectiveLabel
@onready var boss_container: VBoxContainer = $HUD/TopCenter/BossContainer
@onready var boss_bar: ProgressBar = $HUD/TopCenter/BossContainer/BossBar
@onready var boss_label: Label = $HUD/TopCenter/BossContainer/BossLabel

# Action buttons
@onready var btn_attack: Button = $HUD/BottomRight/BtnAttack
@onready var btn_skill_1: Button = $HUD/BottomRight/SkillContainer/BtnSkill1
@onready var btn_skill_2: Button = $HUD/BottomRight/SkillContainer/BtnSkill2
@onready var btn_skill_3: Button = $HUD/BottomRight/SkillContainer/BtnSkill3
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
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 65.0
var _player: Player = null


func _ready() -> void:
	# Hide boss bar by default
	if boss_container != null:
		boss_container.visible = false
	if pause_menu != null:
		pause_menu.visible = false

	# Connect buttons
	if btn_attack != null:
		btn_attack.pressed.connect(_on_attack_pressed)
	if btn_skill_1 != null:
		btn_skill_1.pressed.connect(func(): _on_skill_pressed(1))
	if btn_skill_2 != null:
		btn_skill_2.pressed.connect(func(): _on_skill_pressed(2))
	if btn_skill_3 != null:
		btn_skill_3.pressed.connect(func(): _on_skill_pressed(3))
	if potion_button != null:
		potion_button.pressed.connect(_on_potion_pressed)
	if btn_interact != null:
		btn_interact.pressed.connect(_on_interact_pressed)

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

	_find_and_bind_player()
	_update_all_hud()


func _find_and_bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.health_changed.connect(update_health)
		_player.xp_gained.connect(update_xp)
		_player.leveled_up.connect(func(lvl): update_level(lvl))
		_player.coins_changed.connect(update_coins)
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
		potion_button.text = "Potion (%d)" % count


func set_objective(text: String, color: Color = Color(1, 0.9, 0.4)) -> void:
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
		btn_skill_1.visible = has_fire
		if has_fire:
			if _player.skill_1_cooldown > 0.0:
				btn_skill_1.disabled = true
				btn_skill_1.text = "Fire (%.1f)" % _player.skill_1_cooldown
			else:
				btn_skill_1.disabled = false
				btn_skill_1.text = "Fire (1)"

	# Skill 2 (Dash)
	var has_dash = "dash" in SaveManager.unlocked_skills
	if btn_skill_2 != null:
		btn_skill_2.visible = has_dash
		if has_dash:
			if _player.skill_2_cooldown > 0.0:
				btn_skill_2.disabled = true
				btn_skill_2.text = "Dash (%.1f)" % _player.skill_2_cooldown
			else:
				btn_skill_2.disabled = false
				btn_skill_2.text = "Dash (2)"

	# Skill 3 (Power)
	var has_power = "power_strike" in SaveManager.unlocked_skills
	if btn_skill_3 != null:
		btn_skill_3.visible = has_power
		if has_power:
			if _player.skill_3_cooldown > 0.0:
				btn_skill_3.disabled = true
				btn_skill_3.text = "Power (%.1f)" % _player.skill_3_cooldown
			else:
				btn_skill_3.disabled = false
				btn_skill_3.text = "Power (3)"


func _on_attack_pressed() -> void:
	if _player != null:
		_player.perform_attack()
	attack_pressed.emit()


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
# Virtual Joystick (Touch & Mouse Drag)
# ==========================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_toggle_pause()

	# Handle screen touch and mouse clicks in joystick area
	if event is InputEventScreenTouch:
		if event.pressed:
			var local_pos = joystick_base.get_global_rect()
			if local_pos.has_point(event.position):
				_is_dragging_joystick = true
				_joystick_touch_id = event.index
				_update_joystick_pos(event.position)
		elif event.index == _joystick_touch_id:
			_reset_joystick()

	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_id and _is_dragging_joystick:
			_update_joystick_pos(event.position)

	# PC Mouse testing for virtual joystick
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var rect = joystick_base.get_global_rect()
				if rect.has_point(event.position):
					_is_dragging_joystick = true
					_joystick_touch_id = -99
					_update_joystick_pos(event.position)
			elif _joystick_touch_id == -99:
				_reset_joystick()

	elif event is InputEventMouseMotion:
		if _is_dragging_joystick and _joystick_touch_id == -99:
			_update_joystick_pos(event.position)


func _update_joystick_pos(touch_pos: Vector2) -> void:
	var base_center = joystick_base.global_position + joystick_base.size * 0.5
	var offset = touch_pos - base_center
	var dist = offset.length()
	var dir = offset.normalized()

	if dist > _joystick_radius:
		offset = dir * _joystick_radius

	if joystick_handle != null:
		joystick_handle.position = (joystick_base.size * 0.5) + offset - (joystick_handle.size * 0.5)

	# Normalize vector to send to player (-1 to 1)
	var move_vec = offset / _joystick_radius
	if _player != null:
		_player.set_mobile_move(move_vec)


func _reset_joystick() -> void:
	_is_dragging_joystick = false
	_joystick_touch_id = -1
	if joystick_handle != null:
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
	pause_toggled.emit(is_paused)


func _on_save_clicked() -> void:
	if SaveManager != null:
		SaveManager.save_game()
		if pause_status != null:
			pause_status.text = "Game Saved Successfully!"
			pause_status.modulate = Color(0.3, 1.0, 0.4)


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	if GameManager != null:
		GameManager.change_scene_safely("res://scenes/ui/main_menu.tscn")
