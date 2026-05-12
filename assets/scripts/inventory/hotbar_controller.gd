class_name HotbarCotnroller extends Control

func _unhandled_input(event: InputEvent) -> void:
	# 1. Block hotbar selections if the player is currently typing or inside menus
	if InventoryGlobal.current_drag_data != null: return
	
	# 2. Number Key Bindings (Map Keys 1-5 to Hotbar Indexes 0-4)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var target_index = event.keycode - KEY_1
			select_hotbar_slot(target_index)
			
	# 3. Mouse Wheel Scroll Cycling
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var next_idx = (InventoryGlobal.active_hotbar_index - 1 + 5) % 5
			select_hotbar_slot(next_idx)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_idx = (InventoryGlobal.active_hotbar_index + 1) % 5
			select_hotbar_slot(next_idx)

## Changes the active selection index registry and updates systems
func select_hotbar_slot(index: int) -> void:
	InventoryGlobal.active_hotbar_index = index
	
	# Look up what item resource file is sitting in this hotbar register
	var active_item = InventoryGlobal.hotbar_items.get(index, null)
	
	# Broadcast globally so slot frames can animate/highlight and weapons can update
	InventoryGlobal.hotbar_selection_changed.emit(index, active_item)
