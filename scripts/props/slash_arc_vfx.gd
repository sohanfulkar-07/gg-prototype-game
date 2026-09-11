class_name SlashArcVFX
extends Node3D

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

func setup(color: Color = Color(0.9, 0.95, 1.0, 0.85), scale_mult: float = 1.0, duration: float = 0.16) -> void:
	if mesh_instance != null:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		mesh_instance.set_surface_override_material(0, mat)

	scale = Vector3(scale_mult * 0.7, scale_mult * 0.7, scale_mult * 0.7)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(scale_mult * 1.3, scale_mult * 1.3, scale_mult * 1.3), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mesh_instance != null:
		tween.chain().tween_property(mesh_instance, "modulate:a", 0.0, duration * 0.6)
	tween.chain().tween_callback(queue_free)
