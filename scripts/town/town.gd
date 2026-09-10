class_name Town
extends Node3D

signal gate_entered
signal save_point_interacted

@onready var player: Node3D = get_node_or_null("Player")
@onready var teleport_area: Area3D = get_node_or_null("TeleportGate/Area3D")
@onready var save_area: Area3D = get_node_or_null("SavePoint/Area3D")
@onready var status_label: Label = get_node_or_null("CanvasLayer/StatusLabel")
@onready var interaction_label: Label = get_node_or_null("CanvasLayer/InteractionLabel")

var _near_gate: bool = false
var _near_save: bool = false
var _near_shop: bool = false
var _current_shop_name: String = ""


func _ready() -> void:
	if teleport_area != null:
		teleport_area.body_entered.connect(_on_gate_body_entered)
		teleport_area.body_exited.connect(_on_gate_body_exited)
		
	if save_area != null:
		save_area.body_entered.connect(_on_save_body_entered)
		save_area.body_exited.connect(_on_save_body_exited)

	_setup_shop_areas()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	# Handle key press events cleanly
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_trigger_current_interaction()


func _trigger_current_interaction() -> void:
	if _near_gate:
		enter_mission_1()
	elif _near_save:
		interact_save_point()
	elif _near_shop:
		interact_shop()


func enter_mission_1() -> void:
	gate_entered.emit()
	if status_label != null:
		status_label.text = "ENTERING MISSION 1: FOREST..."
		status_label.modulate = Color(0.2, 0.9, 1.0)
	
	# Transition to Mission 1 Forest
	get_tree().change_scene_to_file("res://scenes/levels/mission_1_forest.tscn")


func interact_save_point() -> void:
	save_point_interacted.emit()
	if status_label != null:
		status_label.text = "Save Point — Save system coming later."
		status_label.modulate = Color(0.9, 0.8, 0.2)


func interact_shop() -> void:
	if status_label != null:
		status_label.text = "%s — Shop system coming later." % _current_shop_name
		status_label.modulate = Color(0.9, 0.7, 0.3)


func _on_gate_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near_gate = true
		_update_ui()


func _on_gate_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near_gate = false
		_update_ui()


func _on_save_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near_save = true
		_update_ui()


func _on_save_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near_save = false
		_update_ui()


func _setup_shop_areas() -> void:
	var shop_nodes = get_tree().get_nodes_in_group("shop_area")
	for shop in shop_nodes:
		if shop is Area3D:
			shop.body_entered.connect(func(body):
				if body.is_in_group("player"):
					_near_shop = true
					_current_shop_name = shop.name.capitalize()
					_update_ui()
			)
			shop.body_exited.connect(func(body):
				if body.is_in_group("player"):
					_near_shop = false
					_update_ui()
			)


func _update_ui() -> void:
	if interaction_label == null:
		return

	if _near_gate:
		interaction_label.text = "[E] ENTER MISSION 1: FOREST"
		interaction_label.visible = true
	elif _near_save:
		interaction_label.text = "[E] SAVE GAME (Save Point)"
		interaction_label.visible = true
	elif _near_shop:
		interaction_label.text = "[E] BROWSE %s" % _current_shop_name.to_upper()
		interaction_label.visible = true
	else:
		interaction_label.visible = false
