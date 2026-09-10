class_name Mission2Ruins
extends Node3D

signal mission_completed
signal objective_updated(remaining: int, total: int)

@export var total_enemies: int = 7
var remaining_enemies: int = 7
var is_completed: bool = false

@onready var enemies_container: Node3D = get_node_or_null("Enemies")
@onready var exit_area: Area3D = get_node_or_null("ExitArea")
@onready var game_ui: GameUI = get_node_or_null("GameUI")


func _ready() -> void:
	if GameManager != null:
		GameManager.current_mission_id = 2

	_setup_enemy_tracking()
	
	if exit_area != null:
		exit_area.body_entered.connect(_on_exit_area_entered)

	_update_ui_status()


func _setup_enemy_tracking() -> void:
	if enemies_container == null:
		return

	var enemies = enemies_container.get_children()
	total_enemies = enemies.size()
	remaining_enemies = total_enemies

	for enemy in enemies:
		if enemy.has_signal("enemy_died"):
			enemy.connect("enemy_died", Callable(self, "_on_enemy_died").bind(enemy))


func _on_enemy_died(_enemy_node: Node) -> void:
	remaining_enemies = max(0, remaining_enemies - 1)
	objective_updated.emit(remaining_enemies, total_enemies)
	_update_ui_status()
	_check_completion()


func _check_completion() -> void:
	if remaining_enemies <= 0 and not is_completed:
		is_completed = true
		mission_completed.emit()
		if SoundManager != null:
			SoundManager.play_level_up()
		_update_ui_status()


func _update_ui_status() -> void:
	if game_ui == null:
		return

	if not is_completed:
		var text = "MISSION 2: RUINS — Defeat all ancient monsters (%d / %d remaining)" % [remaining_enemies, total_enemies]
		game_ui.set_objective(text, Color(1.0, 0.85, 0.4))
	else:
		var text = "MISSION 2 COMPLETE! Enter northern portal to return to Town"
		game_ui.set_objective(text, Color(0.3, 1.0, 0.4))


func _on_exit_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if is_completed:
			if game_ui != null:
				game_ui.set_objective("RETURNING TO TOWN (+8 COIN REWARD)...", Color(0.2, 1.0, 0.8))
			print("MISSION 2 COMPLETE — RETURNING TO TOWN...")
			GameManager.complete_mission(2)
			GameManager.change_scene_safely("res://scenes/town/town.tscn")
		else:
			if game_ui != null:
				game_ui.set_objective("PORTAL LOCKED! Defeat remaining monsters (%d left)" % remaining_enemies, Color(1.0, 0.3, 0.3))
				get_tree().create_timer(2.0).timeout.connect(_update_ui_status)
