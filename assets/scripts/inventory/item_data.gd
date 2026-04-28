class_name ItemData extends Resource

@export var item_name : String = ""
@export var item_type : String = ""
@export var item_effect : String = ""
@export var icon : Texture2D
@export var width : int
@export var height : int
@export var hotbar_icon : Texture2D
@export var item_model : PackedScene

var is_rotated : bool = false

func get_size() -> Vector2i:
	return Vector2i(height, width) if is_rotated else Vector2i(width, height)
