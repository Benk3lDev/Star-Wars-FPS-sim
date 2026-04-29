extends TextureRect

var item_data : ItemData
var grid_pos : Vector2i

signal drag_started(data, preview_node)

func _get_drag_data(_at_position):
	var drag_data = {
		"item_data": item_data,
		"original_pos": grid_pos
	}
	
	InventoryGlobal.remove_item_at_pos(grid_pos.x, grid_pos.y)
	
	var preview_handle = Control.new()
	var preview = TextureRect.new()
	
	preview.texture = self.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = self.size
	preview.modulate.a = 0.5
	
	preview.position = Vector2.ZERO
	preview.pivot_offset = Vector2.ZERO
	
	if item_data.is_rotated:
		preview.rotation_degrees = 90
		preview.position.x = InventoryGlobal.slot_size
	
	preview_handle.add_child(preview)
	
	set_drag_preview(preview_handle)
	
	drag_started.emit(item_data, preview_handle)
	
	return drag_data


func update_visuals():
	if item_data:
		texture = item_data.icon
		var base_w = item_data.width * InventoryGlobal.slot_size
		var base_h = item_data.height * InventoryGlobal.slot_size
		
		custom_minimum_size = Vector2(base_w, base_h)
		size = custom_minimum_size
		
		pivot_offset = Vector2.ZERO
		
		if item_data.is_rotated:
			rotation_degrees = 90
		else:
			rotation_degrees = 0
			
