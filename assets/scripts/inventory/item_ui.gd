extends TextureRect

@onready var quantity_label = $QuantityLabel

var item_data : ItemData
var grid_pos : Vector2i

signal drag_started(data, preview_node)
signal request_context_menu(item: ItemData, pivot_pos: Vector2i, mouse_pos: Vector2)


func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_mouse_entered():
	InventoryGlobal.emit_signal("item_hovered", item_data)


func _on_mouse_exited():
	InventoryGlobal.emit_signal("item_unhovered")


func _get_drag_data(_at_position):
	var drag_data = {
		"item_data": item_data,
		"original_pos": grid_pos
	}
	
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
	
	drag_started.emit(drag_data, preview_handle)
	
	return drag_data


func update_visuals():
	if not item_data: return
	
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
		
	if item_data.is_stackable and item_data.quantity > 1:
		quantity_label.text = str(item_data.quantity)
		quantity_label.show()
		
		quantity_label.pivot_offset = Vector2.ZERO
		
		if item_data.is_rotated:
			
			quantity_label.rotation_degrees = -90
			var padding = 5
			quantity_label.position.x = 2
			quantity_label.position.y = size.x + 2
		
		else:
			quantity_label.rotation_degrees = 0
			quantity_label.position = size - quantity_label.size - Vector2(2, 2)
	else:
		quantity_label.hide()


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var slot_data = InventoryGlobal.inventory[grid_pos.x + (grid_pos.y * InventoryGlobal.grid_width)]
			if slot_data.get("is_occupied", false):
				var px = slot_data.pivot_gx
				var py = slot_data.pivot_gy
				var pivot_slot = InventoryGlobal.inventory[px + (py * InventoryGlobal.grid_width)]
				
				var item = pivot_slot.item_resource
				if item:
					InventoryGlobal.request_context_menu.emit(item, Vector2i(px, py), get_global_mouse_position())
