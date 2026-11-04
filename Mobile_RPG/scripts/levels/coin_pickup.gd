class_name CoinPickup
extends Node3D

@export var coin_value: int = 1
@export var magnet_range: float = 4.0
@export var magnet_speed: float = 9.0

var _collected: bool = false
var _target_player: Node3D = null

@onready var mesh_instance: MeshInstance3D = $Visuals/CoinMesh
@onready var area: Area3D = $Area3D


func _ready() -> void:
	if area != null:
		area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected:
		return

	# Rotate visual coin
	if mesh_instance != null:
		mesh_instance.rotation.y += 3.5 * delta

	# Magnetize toward player if nearby
	if _target_player == null or not is_instance_valid(_target_player):
		_target_player = get_tree().get_first_node_in_group("player") as Node3D

	if _target_player != null and is_instance_valid(_target_player):
		var dist = global_position.distance_to(_target_player.global_position)
		if dist <= magnet_range:
			global_position = global_position.move_toward(_target_player.global_position + Vector3(0, 0.5, 0), magnet_speed * delta)
			if dist <= 0.8:
				_collect(_target_player)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collect(body)


func _collect(player: Node) -> void:
	if _collected:
		return
	_collected = true

	if player.has_method("add_coins"):
		player.add_coins(coin_value)
	else:
		SaveManager.coins += coin_value
		GameManager.coins_updated.emit(SaveManager.coins)

	if SoundManager != null:
		SoundManager.play_coin()

	# Float up and vanish
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 0.6, 0.2)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	tween.chain().tween_callback(queue_free)
