class_name MainMenu
extends Control

# Node References
@onready var env_3d: Node3D = $SubViewportContainer/SubViewport/MainMenuEnvironment
@onready var hud_layer: Control = $MenuHUD
@onready var cinematic_layer: Control = $CinematicOverlay
@onready var black_fade: ColorRect = $CinematicOverlay/BlackFade
@onready var btn_skip: Button = $CinematicOverlay/BtnSkip
@onready var cinematic_title: Control = $CinematicOverlay/CinematicTitle
@onready var cinematic_caption: Label = $CinematicOverlay/CaptionLabel

# Main Menu UI
@onready var menu_panel: Control = $MenuHUD/MenuPanel
@onready var title_label: Label = $MenuHUD/MenuPanel/VBox/TitleBlock/TitleLabel
@onready var subtitle_label: Label = $MenuHUD/MenuPanel/VBox/TitleBlock/SubtitleLabel
@onready var btn_new_game: Button = $MenuHUD/MenuPanel/VBox/Buttons/BtnNewGame
@onready var btn_continue: Button = $MenuHUD/MenuPanel/VBox/Buttons/BtnContinue
@onready var btn_settings: Button = $MenuHUD/MenuPanel/VBox/Buttons/BtnSettings
@onready var btn_credits: Button = $MenuHUD/MenuPanel/VBox/Buttons/BtnCredits
@onready var btn_exit: Button = $MenuHUD/MenuPanel/VBox/Buttons/BtnExit

# Modals
@onready var confirm_modal: Control = $Modals/ConfirmModal
@onready var btn_confirm_new_game: Button = $Modals/ConfirmModal/Panel/VBox/BtnConfirm
@onready var btn_cancel_new_game: Button = $Modals/ConfirmModal/Panel/VBox/BtnCancel
@onready var confirm_desc: Label = $Modals/ConfirmModal/Panel/VBox/DescLabel

@onready var settings_modal: Control = $Modals/SettingsModal
@onready var slider_master: HSlider = $Modals/SettingsModal/Panel/VBox/MasterRow/Slider
@onready var slider_sfx: HSlider = $Modals/SettingsModal/Panel/VBox/SfxRow/Slider
@onready var slider_music: HSlider = $Modals/SettingsModal/Panel/VBox/MusicRow/Slider
@onready var btn_fps_toggle: Button = $Modals/SettingsModal/Panel/VBox/FpsRow/BtnFps
@onready var btn_shadows_toggle: Button = $Modals/SettingsModal/Panel/VBox/ShadowsRow/BtnShadows
@onready var slider_cam_sens: HSlider = $Modals/SettingsModal/Panel/VBox/CamSensRow/Slider
@onready var btn_close_settings: Button = $Modals/SettingsModal/Panel/VBox/BtnCloseSettings

@onready var credits_modal: Control = $Modals/CreditsModal
@onready var btn_replay_intro: Button = $Modals/CreditsModal/Panel/VBox/BtnReplayIntro
@onready var btn_close_credits: Button = $Modals/CreditsModal/Panel/VBox/BtnCloseCredits

var _is_cinematic_running: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	# Hide all modals initially
	_hide_all_modals()
	
	# Connect Button events
	_setup_buttons()
	
	# Setup Settings values from SaveManager
	_populate_settings()
	
	# Connect environment signals
	if env_3d != null:
		env_3d.shot_changed.connect(_on_cinematic_shot_changed)
		env_3d.cinematic_completed.connect(_on_cinematic_completed)
	
	# Update Continue button state
	_update_continue_button()
	
	# Check whether to play Cinematic Opening or go straight to Live Main Menu
	var should_play_intro = not SaveManager.has_watched_intro
	if should_play_intro:
		play_cinematic_opening()
	else:
		show_main_menu_immediate()


func _setup_buttons() -> void:
	if btn_new_game != null:
		btn_new_game.pressed.connect(_on_new_game_pressed)
		_add_button_juice(btn_new_game)
	if btn_continue != null:
		btn_continue.pressed.connect(_on_continue_pressed)
		_add_button_juice(btn_continue)
	if btn_settings != null:
		btn_settings.pressed.connect(_on_settings_pressed)
		_add_button_juice(btn_settings)
	if btn_credits != null:
		btn_credits.pressed.connect(_on_credits_pressed)
		_add_button_juice(btn_credits)
	if btn_exit != null:
		btn_exit.pressed.connect(_on_exit_pressed)
		_add_button_juice(btn_exit)
	if btn_skip != null:
		btn_skip.pressed.connect(skip_cinematic)
		_add_button_juice(btn_skip)

	# Modals buttons
	if btn_confirm_new_game != null:
		btn_confirm_new_game.pressed.connect(_execute_new_game)
		_add_button_juice(btn_confirm_new_game)
	if btn_cancel_new_game != null:
		btn_cancel_new_game.pressed.connect(_hide_all_modals)
		_add_button_juice(btn_cancel_new_game)
	if btn_close_settings != null:
		btn_close_settings.pressed.connect(_hide_all_modals)
		_add_button_juice(btn_close_settings)
	if btn_close_credits != null:
		btn_close_credits.pressed.connect(_hide_all_modals)
		_add_button_juice(btn_close_credits)
	if btn_replay_intro != null:
		btn_replay_intro.pressed.connect(func():
			_hide_all_modals()
			play_cinematic_opening()
		)
		_add_button_juice(btn_replay_intro)

	# Sliders
	if slider_master != null:
		slider_master.value_changed.connect(func(v):
			SaveManager.settings_master_volume = v / 100.0
			SoundManager.set_master_volume(SaveManager.settings_master_volume)
		)
	if slider_sfx != null:
		slider_sfx.value_changed.connect(func(v):
			SaveManager.settings_sfx_volume = v / 100.0
			SoundManager.set_sfx_volume(SaveManager.settings_sfx_volume)
		)
	if slider_music != null:
		slider_music.value_changed.connect(func(v):
			SaveManager.settings_music_volume = v / 100.0
			SoundManager.set_music_volume(SaveManager.settings_music_volume)
		)
	if btn_fps_toggle != null:
		btn_fps_toggle.pressed.connect(_toggle_target_fps)
	if btn_shadows_toggle != null:
		btn_shadows_toggle.pressed.connect(_toggle_shadows)
	if slider_cam_sens != null:
		slider_cam_sens.value_changed.connect(func(v):
			SaveManager.settings_camera_sensitivity = v / 50.0
		)


func _add_button_juice(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		SoundManager.play_ui_hover()
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.025, 1.025), 0.12)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)
	btn.button_down.connect(func():
		SoundManager.play_ui_click()
		btn.scale = Vector2(0.97, 0.97)
	)
	btn.button_up.connect(func():
		btn.scale = Vector2(1.0, 1.0)
	)


func _update_continue_button() -> void:
	if btn_continue == null:
		return
	var has_save = SaveManager.has_save_file()
	btn_continue.disabled = not has_save
	if has_save:
		btn_continue.text = "Continue  (Lv. %d • %dG)" % [SaveManager.level, SaveManager.coins]
		btn_continue.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn_continue.text = "Continue  (No Save Found)"
		btn_continue.modulate = Color(0.65, 0.65, 0.7, 0.45)


# ==========================================
# Cinematic Opening Sequence
# ==========================================

func play_cinematic_opening() -> void:
	_is_cinematic_running = true
	hud_layer.visible = false
	cinematic_layer.visible = true
	btn_skip.visible = true
	btn_skip.modulate.a = 0.0
	cinematic_title.visible = false
	cinematic_caption.text = ""
	
	# Start in full blackness
	black_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	
	# Start atmospheric procedural wind & ambient music
	SoundManager.start_cinematic_music()
	
	# Fade in Skip button gently after 1 second
	var skip_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	skip_tween.tween_interval(1.0)
	skip_tween.tween_property(btn_skip, "modulate:a", 1.0, 0.8)

	# Trigger camera sequence
	if env_3d != null:
		env_3d.start_cinematic()


func _on_cinematic_shot_changed(shot_idx: int, _shot_name: String) -> void:
	if not _is_cinematic_running:
		return

	match shot_idx:
		1:
			# Scene 1: Darkness & Wind
			black_fade.color = Color(0.0, 0.0, 0.0, 1.0)
			cinematic_caption.text = "In the age before the sundering..."
			_fade_caption()
		2:
			# Scene 2: The World (fade in from black)
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(black_fade, "color:a", 0.0, 1.4)
			cinematic_caption.text = "A realm waiting for a champion."
			_fade_caption()
			SoundManager.play_wind_whoosh()
		3:
			# Scene 3: The Kingdom (descending on town)
			cinematic_caption.text = "SwordStrike: The Realm of Valenor."
			_fade_caption()
		4:
			# Scene 4: The Hero (push in on hero)
			cinematic_caption.text = "Your destiny begins."
			_fade_caption()
		5:
			# Scene 5: Title Reveal
			_reveal_cinematic_title()


func _fade_caption() -> void:
	if cinematic_caption == null:
		return
	cinematic_caption.modulate.a = 0.0
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cinematic_caption, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.8)
	tw.tween_property(cinematic_caption, "modulate:a", 0.0, 0.6)


func _reveal_cinematic_title() -> void:
	cinematic_title.visible = true
	cinematic_title.modulate.a = 0.0
	cinematic_title.scale = Vector2(0.92, 0.92)
	cinematic_caption.text = ""
	
	SoundManager.play_title_reveal()
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cinematic_title, "modulate:a", 1.0, 1.2)
	tw.tween_property(cinematic_title, "scale", Vector2(1.0, 1.0), 1.4)


func _on_cinematic_completed() -> void:
	if not _is_cinematic_running:
		return
	_is_cinematic_running = false
	
	# Mark intro as watched and save
	SaveManager.has_watched_intro = true
	SaveManager.save_game()
	
	# Fade out cinematic overlay and reveal main menu UI smoothly
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cinematic_layer, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		cinematic_layer.visible = false
		cinematic_layer.modulate.a = 1.0
		_show_main_menu_animated()
	)


func skip_cinematic() -> void:
	if not _is_cinematic_running:
		return
	_is_cinematic_running = false
	SoundManager.play_ui_click()

	SaveManager.has_watched_intro = true
	SaveManager.save_game()

	if env_3d != null:
		env_3d.skip_to_menu()

	# Quick smooth cross-fade to live main menu
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(black_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func():
		cinematic_layer.visible = false
		cinematic_title.visible = false
		black_fade.color.a = 0.0
		_show_main_menu_animated()
	)


func show_main_menu_immediate() -> void:
	_is_cinematic_running = false
	cinematic_layer.visible = false
	if env_3d != null:
		env_3d.skip_to_menu()
	SoundManager.start_cinematic_music()
	_show_main_menu_animated()


func _show_main_menu_animated() -> void:
	hud_layer.visible = true
	menu_panel.modulate.a = 0.0
	menu_panel.position.x = -40.0
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu_panel, "modulate:a", 1.0, 0.7)
	tw.tween_property(menu_panel, "position:x", 0.0, 0.7)


# ==========================================
# Main Menu Actions
# ==========================================

func _on_new_game_pressed() -> void:
	if SaveManager.has_save_file():
		# Ask for confirmation
		if confirm_desc != null:
			confirm_desc.text = "Existing adventure found:\nLevel %d Hero with %d Gold.\n\nStarting a new game will overwrite your progress. Are you sure?" % [SaveManager.level, SaveManager.coins]
		confirm_modal.visible = true
		_animate_modal_open(confirm_modal)
	else:
		_execute_new_game()


func _execute_new_game() -> void:
	_hide_all_modals()
	SoundManager.play_ui_confirm()
	SoundManager.stop_cinematic_music()
	
	# Smooth fade out before loading
	_fade_screen_out_and_execute(func():
		GameManager.start_new_game()
	)


func _on_continue_pressed() -> void:
	if not SaveManager.has_save_file():
		SoundManager.play_ui_cancel()
		return
	
	SoundManager.play_ui_confirm()
	SoundManager.stop_cinematic_music()
	
	_fade_screen_out_and_execute(func():
		GameManager.continue_game()
	)


func _fade_screen_out_and_execute(action: Callable) -> void:
	cinematic_layer.visible = true
	btn_skip.visible = false
	cinematic_title.visible = false
	black_fade.color = Color(0, 0, 0, 0)
	
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(black_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(action)


func _on_settings_pressed() -> void:
	_hide_all_modals()
	settings_modal.visible = true
	_animate_modal_open(settings_modal)


func _on_credits_pressed() -> void:
	_hide_all_modals()
	credits_modal.visible = true
	_animate_modal_open(credits_modal)


func _on_exit_pressed() -> void:
	SoundManager.play_ui_cancel()
	SaveManager.save_game()
	get_tree().quit()


# ==========================================
# Modals & Settings Management
# ==========================================

func _hide_all_modals() -> void:
	if confirm_modal != null:
		confirm_modal.visible = false
	if settings_modal != null:
		settings_modal.visible = false
	if credits_modal != null:
		credits_modal.visible = false


func _animate_modal_open(modal: Control) -> void:
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.95, 0.95)
	modal.pivot_offset = modal.size * 0.5
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal, "modulate:a", 1.0, 0.25)
	tw.tween_property(modal, "scale", Vector2(1.0, 1.0), 0.25)


func _populate_settings() -> void:
	if slider_master != null:
		slider_master.value = SaveManager.settings_master_volume * 100.0
	if slider_sfx != null:
		slider_sfx.value = SaveManager.settings_sfx_volume * 100.0
	if slider_music != null:
		slider_music.value = SaveManager.settings_music_volume * 100.0
	if slider_cam_sens != null:
		slider_cam_sens.value = SaveManager.settings_camera_sensitivity * 50.0
	_update_fps_button_label()
	_update_shadows_button_label()


func _toggle_target_fps() -> void:
	SoundManager.play_ui_click()
	if SaveManager.settings_target_fps == 60:
		SaveManager.settings_target_fps = 30
		Engine.max_fps = 30
	else:
		SaveManager.settings_target_fps = 60
		Engine.max_fps = 60
	_update_fps_button_label()


func _update_fps_button_label() -> void:
	if btn_fps_toggle != null:
		btn_fps_toggle.text = "%d FPS" % SaveManager.settings_target_fps


func _toggle_shadows() -> void:
	SoundManager.play_ui_click()
	SaveManager.settings_shadows_enabled = not SaveManager.settings_shadows_enabled
	if env_3d != null and env_3d.sun_light != null:
		env_3d.sun_light.shadow_enabled = SaveManager.settings_shadows_enabled
	_update_shadows_button_label()


func _update_shadows_button_label() -> void:
	if btn_shadows_toggle != null:
		btn_shadows_toggle.text = "Shadows: ON" if SaveManager.settings_shadows_enabled else "Shadows: OFF"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if confirm_modal != null and confirm_modal.visible:
			confirm_modal.visible = false
			get_viewport().set_input_as_handled()
		elif settings_modal != null and settings_modal.visible:
			settings_modal.visible = false
			get_viewport().set_input_as_handled()
		elif credits_modal != null and credits_modal.visible:
			credits_modal.visible = false
			get_viewport().set_input_as_handled()
		elif _is_cinematic_running:
			skip_cinematic()
			get_viewport().set_input_as_handled()
		else:
			_on_exit_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android Hardware Back Button
		if confirm_modal != null and confirm_modal.visible:
			confirm_modal.visible = false
		elif settings_modal != null and settings_modal.visible:
			settings_modal.visible = false
		elif credits_modal != null and credits_modal.visible:
			credits_modal.visible = false
		elif _is_cinematic_running:
			skip_cinematic()
		else:
			_on_exit_pressed()
