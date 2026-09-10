class_name ShopDialog
extends Control

signal shop_closed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var item_name_label: Label = $Panel/VBox/ItemNameLabel
@onready var item_desc_label: Label = $Panel/VBox/ItemDescLabel
@onready var price_label: Label = $Panel/VBox/PriceLabel
@onready var player_coins_label: Label = $Panel/VBox/PlayerCoinsLabel
@onready var btn_buy: Button = $Panel/VBox/BtnBuy
@onready var btn_close: Button = $Panel/VBox/BtnClose
@onready var status_label: Label = $Panel/VBox/StatusLabel

var current_shop_type: String = ""
var selected_skill_index: int = 0
const SKILLS_LIST := ["fire_attack", "dash", "power_strike"]
const SKILL_NAMES := {
	"fire_attack": "Fire Attack Scroll (Hurl flaming projectiles, 25 DMG)",
	"dash": "Dash Scroll (Quick forward burst with invulnerability)",
	"power_strike": "Power Strike Scroll (Devastating 360 shockwave, 35 DMG)"
}


func _ready() -> void:
	visible = false
	if btn_buy != null:
		btn_buy.pressed.connect(_on_buy_pressed)
	if btn_close != null:
		btn_close.pressed.connect(close_shop)


func open_shop(shop_type: String) -> void:
	current_shop_type = shop_type
	visible = true
	status_label.text = ""
	_refresh_display()


func close_shop() -> void:
	visible = false
	shop_closed.emit()


func _refresh_display() -> void:
	if SaveManager == null:
		return

	player_coins_label.text = "Your Coins: %d" % SaveManager.coins

	match current_shop_type:
		"basic_sword":
			title_label.text = "BASIC SWORD SHOP"
			item_name_label.text = "Steel Adventurer Sword"
			item_desc_label.text = "A dependable tempered blade for new adventurers.\nIncreases attack damage to 15."
			price_label.text = "Price: 7 Coins"
			if "basic_sword" in SaveManager.owned_weapons:
				btn_buy.disabled = true
				btn_buy.text = "ALREADY OWNED"
			else:
				btn_buy.disabled = (SaveManager.coins < 7)
				btn_buy.text = "BUY BASIC SWORD"

		"advanced_sword":
			title_label.text = "ADVANCED SWORD SHOP"
			item_name_label.text = "Golden Royal Blade"
			item_desc_label.text = "Forged with enchanted aurum to slay deep dungeon evils.\nIncreases attack damage to 25!"
			price_label.text = "Price: 15 Coins"
			if not GameManager.is_advanced_sword_unlocked():
				btn_buy.disabled = true
				btn_buy.text = "LOCKED (Clear Mission 3)"
			elif "advanced_sword" in SaveManager.owned_weapons:
				btn_buy.disabled = true
				btn_buy.text = "ALREADY OWNED"
			else:
				btn_buy.disabled = (SaveManager.coins < 15)
				btn_buy.text = "BUY ADVANCED SWORD"

		"skill_scroll":
			title_label.text = "SKILL SCROLL SHOP"
			# Find next unowned skill
			var next_skill = ""
			for s in SKILLS_LIST:
				if not (s in SaveManager.unlocked_skills):
					next_skill = s
					break

			if next_skill == "":
				item_name_label.text = "Mastery Achieved!"
				item_desc_label.text = "You have mastered all available skills: Fire Attack, Dash, and Power Strike!"
				price_label.text = "Price: --"
				btn_buy.disabled = true
				btn_buy.text = "ALL SKILLS UNLOCKED"
			else:
				item_name_label.text = next_skill.replace("_", " ").capitalize() + " Scroll"
				item_desc_label.text = SKILL_NAMES[next_skill]
				price_label.text = "Price: 20 Coins"
				btn_buy.disabled = (SaveManager.coins < 20)
				btn_buy.text = "BUY SKILL SCROLL"

		"potion":
			title_label.text = "HEALING POTION SHOP"
			item_name_label.text = "Refreshing Red Elixir"
			item_desc_label.text = "Restores 30 Health Points instantly during tough missions.\nPress [Q] or Potion Button to drink."
			price_label.text = "Price: 3 Coins (Owned: %d)" % SaveManager.potion_count
			btn_buy.disabled = (SaveManager.coins < 3)
			btn_buy.text = "BUY POTION"


func _on_buy_pressed() -> void:
	var result = ""
	match current_shop_type:
		"basic_sword":
			result = GameManager.buy_basic_sword()
		"advanced_sword":
			result = GameManager.buy_advanced_sword()
		"skill_scroll":
			var next_skill = ""
			for s in SKILLS_LIST:
				if not (s in SaveManager.unlocked_skills):
					next_skill = s
					break
			if next_skill != "":
				result = GameManager.buy_skill(next_skill)
		"potion":
			result = GameManager.buy_healing_potion()

	match result:
		"SUCCESS":
			status_label.text = "Purchase successful!"
			status_label.modulate = Color(0.3, 1.0, 0.4)
		"NOT_ENOUGH_COINS":
			status_label.text = "Not enough coins!"
			status_label.modulate = Color(1.0, 0.3, 0.3)
		"ALREADY_OWNED":
			status_label.text = "Item is already owned!"
			status_label.modulate = Color(1.0, 0.8, 0.2)
		"LOCKED":
			status_label.text = "Item locked! Complete Mission 3 first."
			status_label.modulate = Color(1.0, 0.3, 0.3)

	_refresh_display()
