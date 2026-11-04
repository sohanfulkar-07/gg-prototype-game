class_name SkillProjectile
extends Node3D

@export var speed: float = 14.0
@export var damage: int = 25
@export var lifetime: float = 2.0

var _direction: Vector3 = Vector3.FORWARD
var _has_hit: bool = false

@onready var area: Area3D = $Area3D


func _ready() -> void:
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)
		
	get_tree().create_timer(lifetime).timeout.connect(func():
		if not _has_hit:
			queue_free()
	)


func setup(direction: Vector3, dmg: int = 25) -> void:
	_direction = direction.normalized()
	damage = dmg
	look_at(global_position + _direction, Vector3.UP)


func _process(delta: float) -> void:
	if _has_hit:
		return
	global_position += _direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if _has_hit or body.is_in_group("player"):
		return
	_handle_hit(body)


func _on_area_entered(other_area: Area3D) -> void:
	if _has_hit:
		return
	var parent = other_area.get_parent()
	if parent != null and parent.is_in_group("enemy"):
		_handle_hit(parent)


func _handle_hit(target: Node) -> void:
	# Traverse up to find damage receiver
	var damagable: Node = target
	while damagable != null and not damagable.has_method("take_damage") and damagable != get_tree().root:
		damagable = damagable.get_parent()

	if damagable != null and damagable.has_method("take_damage") and not damagable.is_in_group("player"):
		_has_hit = true
		var knockback = _direction * 4.0
		knockback.y = 0.0
		damagable.call("take_damage", damage, knockback)
		if SoundManager != null:
			SoundManager.play_hit()
		
		# Explode/dissipate
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(1.8, 1.8, 1.8), 0.08)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.08)
		tween.chain().tween_callback(queue_free)
	elif not target.is_in_group("player") and not target is Area3D:
		# Hit wall/obstacle
		_has_hit = true
		queue_free()
