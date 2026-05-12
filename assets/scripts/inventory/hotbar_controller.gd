class_name HotbarCotnroller extends Control

func _unhandled_input(event: InputEvent) -> void:
	if InventoryGlobal.current_drag_data != null: return
	
	# 1. Number Key Bindings for 10 Slots (Keys 1-9, plus Key 0)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Map standard Keys 1-9 to indices 0-8
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var target_index = event.keycode - KEY_1
			select_hotbar_slot(target_index)
		# Map Key 0 to the 10th slot (index 9)
		elif event.keycode == KEY_0:
			select_hotbar_slot(9)
			
	# 2. Mouse Wheel Scroll Cycling for 10 Slots
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Shift modulo loop calculation from 5 to 10
			var next_idx = (InventoryGlobal.active_hotbar_index - 1 + 10) % 10
			select_hotbar_slot(next_idx)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_idx = (InventoryGlobal.active_hotbar_index + 1) % 10
			select_hotbar_slot(next_idx)

func select_hotbar_slot(index: int) -> void:
	InventoryGlobal.active_hotbar_index = index
	
	var active_item = InventoryGlobal.hotbar_items.get(index, null)
	InventoryGlobal.hotbar_selection_changed.emit(index, active_item)
