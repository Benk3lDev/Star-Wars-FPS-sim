class_name ItemData extends Resource

@export_enum("Head", "Chest", "Belt", "Backpack") var armor_type: String
@export_enum("Armor", "Weapon", "Consumable") var item_type : String

@export var item_name : String = ""
@export var item_effect : String = ""
@export var icon : Texture2D
@export var size : Vector2i
@export var hotbar_icon : Texture2D
@export var item_model : PackedScene
@export var is_stackable : bool
@export var max_stack_size : int
@export var weapon_stats: Weapon
@export var ammo : int

var quantity : int = 1

var is_equipped_now : bool = false
var is_rotated : bool = false

func get_size() -> Vector2i:
	if is_rotated:
		return Vector2i(size.y, size.x)
	else:
		return Vector2i(size.x, size.y)
