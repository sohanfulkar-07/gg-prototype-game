class_name Mission1Forest
extends Node3D

signal mission_completed
signal objective_updated(remaining: int, total: int)

@export var total_enemies: int = 5
var remaining_enemies: int = 5
var is_completed: bool = false

# Node References
@onready var enemies_container: Node3D = get_node_or_null("Enemies")
@onready var exit_area: Area3D = get_node_or_null("ExitArea")
@onready var status_label: Label = get_node_or_null("CanvasLayer/StatusLabel")


func _ready() -> void:
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
		_update_ui_status()


func _update_ui_status() -> void:
	if status_label == null:
		return

	if not is_completed:
		status_label.text = "MISSION 1: FOREST\nObjective: Defeat all enemies (%d / %d remaining)" % [remaining_enemies, total_enemies]
		status_label.modulate = Color(1.0, 0.9, 0.4)
	else:
		status_label.text = "MISSION COMPLETE!\nAll enemies defeated! Proceed to the northern exit area."
		status_label.modulate = Color(0.3, 1.0, 0.4)


func _on_exit_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if is_completed:
			if status_label != null:
				status_label.text = "MISSION COMPLETE — RETURN TO TOWN"
				status_label.modulate = Color(0.2, 1.0, 0.8)
			print("MISSION COMPLETE — RETURN TO TOWN")
		else:
			if status_label != null:
				status_label.text = "EXIT LOCKED!\nDefeat remaining enemies (%d left)" % remaining_enemies
				status_label.modulate = Color(1.0, 0.3, 0.3)
