class_name DialogueBox
extends Control

signal dialogue_finished

@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var btn_next: Button = $Panel/VBox/BtnNext

var _dialogue_lines: Array = []
var _current_line_idx: int = 0
var _is_active: bool = false


func _ready() -> void:
	visible = false
	if btn_next != null:
		btn_next.pressed.connect(_advance_dialogue)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func show_dialogue(lines: Array) -> void:
	_dialogue_lines = lines
	_current_line_idx = 0
	_is_active = true
	visible = true

	# Freeze player movement during dialogue
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "can_move" in player:
		player.can_move = false

	_display_current_line()


func _display_current_line() -> void:
	if _current_line_idx >= _dialogue_lines.size():
		_finish_dialogue()
		return

	var line = _dialogue_lines[_current_line_idx]
	if speaker_label != null:
		speaker_label.text = str(line.get("speaker", ""))
	if text_label != null:
		text_label.text = str(line.get("text", ""))

	if _current_line_idx == _dialogue_lines.size() - 1:
		btn_next.text = "Close"
	else:
		btn_next.text = "Next >"


func _advance_dialogue() -> void:
	_current_line_idx += 1
	_display_current_line()


func _finish_dialogue() -> void:
	_is_active = false
	visible = false

	# Restore player movement
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "can_move" in player:
		player.can_move = true

	dialogue_finished.emit()
