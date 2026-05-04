class_name ItemData extends Resource

@export_enum("Head", "Chest", "Belt", "Backpack") var armor_type: String
@export_enum("Armor", "Weapon", "Consumable") var item_type : String

@export var item_name : String = ""
@export var item_effect : String = ""
@export var icon : Texture2D
@export var width : int
@export var height : int
@export var hotbar_icon : Texture2D
@export var item_model : PackedScene
@export var is_stackable : bool
@export var max_stack_size : int
var quantity : int = 1

var is_rotated : bool = false

func get_size() -> Vector2i:
	if is_rotated:
		return Vector2i(height, width)
	else:
		return Vector2i(width, height)
