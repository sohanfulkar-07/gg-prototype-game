class_name ShopSign
extends Node3D

@export var icon_symbol: String = "⚔️"
@export var sign_title: String = "Weapons"

@onready var icon_label: Label3D = get_node_or_null("Board/IconLabel")
@onready var title_label: Label3D = get_node_or_null("Board/TitleLabel")

func _ready() -> void:
	if icon_label != null:
		icon_label.text = icon_symbol
	if title_label != null:
		title_label.text = sign_title
