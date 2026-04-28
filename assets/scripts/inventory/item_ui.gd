extends TextureRect

var item_data : ItemData
var grid_pos : Vector2i

signal drag_started(data)

func _get_drag_data(_at_position):
	drag_started.emit(item_data)
	
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = size
	preview.modulate.a = 0.5
	
	InventoryGlobal.remove_item_at_pos(grid_pos.x, grid_pos.y)
	
	return item_data


func update_visuals():
	if item_data:
		texture = item_data.icon
		var display_width = item_data.width
		var display_height = item_data.height
		if item_data.is_rotated:
			display_width = item_data.height
			display_height = item_data.width
