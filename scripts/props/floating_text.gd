class_name FloatingText
extends Node3D

@onready var label: Label3D = $Label3D

func setup(text: String, color: Color = Color(1, 1, 1), font_size_px: int = 24) -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if label != null:
		label.text = text
		label.modulate = color
		label.font_size = font_size_px

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.2, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
	tween.chain().tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
