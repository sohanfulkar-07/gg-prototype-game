class_name MainMenu
extends Control

@onready var btn_new_game: Button = $VBox/BtnNewGame
@onready var btn_continue: Button = $VBox/BtnContinue
@onready var btn_controls: Button = $VBox/BtnControls
@onready var btn_exit: Button = $VBox/BtnExit
@onready var controls_modal: Control = $ControlsModal
@onready var btn_close_controls: Button = $ControlsModal/Panel/BtnCloseControls


func _ready() -> void:
	if controls_modal != null:
		controls_modal.visible = false

	if btn_new_game != null:
		btn_new_game.pressed.connect(_on_new_game)
	if btn_continue != null:
		btn_continue.pressed.connect(_on_continue)
		btn_continue.disabled = not SaveManager.has_save_file()
	if btn_controls != null:
		btn_controls.pressed.connect(_toggle_controls)
	if btn_exit != null:
		btn_exit.pressed.connect(_on_exit)
	if btn_close_controls != null:
		btn_close_controls.pressed.connect(_toggle_controls)


func _on_new_game() -> void:
	GameManager.start_new_game()


func _on_continue() -> void:
	GameManager.continue_game()


func _toggle_controls() -> void:
	if controls_modal != null:
		controls_modal.visible = not controls_modal.visible


func _on_exit() -> void:
	get_tree().quit()
