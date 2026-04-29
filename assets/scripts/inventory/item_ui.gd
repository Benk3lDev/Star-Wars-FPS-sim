extends TextureRect

var item_data : ItemData
var grid_pos : Vector2i

signal drag_started(data, preview_node)

func _get_drag_data(_at_position):
	
	InventoryGlobal.remove_item_at_pos(grid_pos.x, grid_pos.y)
	
	var preview_handle = Control.new()
	var preview = TextureRect.new()
	
	preview.texture = self.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = self.size
	preview.modulate.a = 0.5
	
	preview.position = -preview.size / 2
	preview.pivot_offset = preview.size / 2
	
	if item_data.is_rotated:
		preview.rotation_degrees = 90
	
	preview_handle.add_child(preview)
	
	set_drag_preview(preview_handle)
	
	drag_started.emit(item_data, preview_handle)
	
	return item_data


func update_visuals():
	if item_data:
		texture = item_data.icon
		var display_width = item_data.width
		var display_height = item_data.height
		var slot_size = 64
		if item_data.is_rotated:
			display_width = item_data.height
			display_height = item_data.width
			rotation_degrees = 90
		else:
			rotation_degrees = 0
			
		custom_minimum_size = Vector2(display_width * slot_size, display_height * slot_size)
		pivot_offset = custom_minimum_size / 2
