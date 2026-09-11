class_name HitSparkVFX
extends Node3D

@onready var particles: CPUParticles3D = get_node_or_null("CPUParticles3D")

func _ready() -> void:
	if particles != null:
		particles.emitting = true
	get_tree().create_timer(0.45).timeout.connect(queue_free)
