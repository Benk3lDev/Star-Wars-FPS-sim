extends TextureRect

@export var slot_index: int
@onready var icon_display = %Icon

func _ready() -> void:
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)
	InventoryGlobal.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	custom_minimum_size = Vector2(64, 64)
	_on_hotbar_selection_changed(InventoryGlobal.active_hotbar_index, null)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		# --- DROPPING A HELD ITEM FROM THE GRID INTO THE HOTBAR ---
		if InventoryGlobal.current_drag_data != null:
			var held_item = InventoryGlobal.current_drag_data
			var grid_node = InventoryGlobal.drag_source
			var original_coords = InventoryGlobal.original_pickup_coords
			
			if original_coords != Vector2i(-1, -1):
				
				# --- DUPLICATION PREVENTION SCAN ---
				var already_in_hotbar = false
				for slot_key in InventoryGlobal.hotbar_items.keys():
					var current_hotbar_item = InventoryGlobal.hotbar_items[slot_key]
					if current_hotbar_item and current_hotbar_item.item_name == held_item.item_name:
						already_in_hotbar = true
						break
				
				if already_in_hotbar:
					print("This item is already assigned to your hotbar! Cannot duplicate.")
					
					# Force-return the item to its true source position without creating a clone
					held_item.is_equipped_now = true
					InventoryGlobal.insert_item_at_grid_coords(original_coords, held_item)
					
					# Clean up visual drags normally
					if is_instance_valid(grid_node):
						if grid_node.has_method("clear_drag_preview"):
							grid_node.clear_drag_preview()
						if grid_node.has_method("refresh_ui"):
							grid_node.refresh_ui()
							
					InventoryGlobal.original_pickup_coords = Vector2i(-1, -1)
					accept_event()
					return
				# -----------------------------------
				
				# --- PROCEDE NORMALLY IF NOT DUPLICATED ---
				var hotbar_clone = held_item.duplicate()
				InventoryGlobal.add_item_to_hotbar(slot_index, hotbar_clone)
				
				held_item.is_equipped_now = true
				InventoryGlobal.insert_item_at_grid_coords(original_coords, held_item)
				
				if is_instance_valid(grid_node):
					if grid_node.has_method("clear_drag_preview"):
						grid_node.clear_drag_preview()
					if grid_node.has_method("refresh_ui"):
						grid_node.refresh_ui()
						
				InventoryGlobal.original_pickup_coords = Vector2i(-1, -1)
				accept_event()
				return


# --- NATIVE OUTGOING DRAG SYSTEM (For Dragging Out of Hotbar Back to Grid) ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	if InventoryGlobal.current_drag_data != null: return null
	
	var hotbar_item = InventoryGlobal.hotbar_items.get(slot_index)
	if not hotbar_item: return null
	
	var preview = TextureRect.new()
	preview.texture = hotbar_item.hotbar_icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(60, 60)
	set_drag_preview(preview)
	
	return {
		"item_data": hotbar_item,
		"source_type": "hotbar",
		"hotbar_index": slot_index
	}

func _on_hotbar_updated(index: int, item_data: ItemData) -> void:
	if index == slot_index:
		if item_data:
			icon_display.texture = item_data.hotbar_icon
			icon_display.show()
		else:
			icon_display.texture = null
			icon_display.hide()

func _on_hotbar_selection_changed(index: int, _item: ItemData) -> void:
	# Animate or tint the slot frame to show it is the actively selected weapon
	if index == slot_index:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.8), 0.1)
	else:
		modulate = Color.WHITE
