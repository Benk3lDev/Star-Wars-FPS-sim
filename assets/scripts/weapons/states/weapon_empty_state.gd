extends WeaponState

func _on_empty_state_entered() -> void:
	print("🚨 [WEAPON EMPTY] Out of ammunition in chamber!")

func _on_empty_state_processing(delta: float) -> void:
	if not weapon_controller or not weapon_controller.current_weapon:
		return
		
	if InventoryGlobal.current_drag_data != null: return
	if InventoryGlobal.ui_node and InventoryGlobal.ui_node.visible: return

	# Listen for the player manually clicking the reload key while empty
	if Input.is_action_just_pressed("reload"):
		if _has_backpack_ammo_reserves():
			print("🔄 [WEAPON EMPTY] Ammunition reserves found in backpack. Moving to Reload state.")
			weapon_controller.weapon_state_chart.send_event("OnReload")
		else:
			print("🔊 [WEAPON EMPTY] Click! Out of reserve ammo. Play empty click sound effect.")
			# TODO: Trigger an empty weapon click sound effect on your audio players here later!

## Helper method to verify if a matching ammo box exists inside your Tetris database slots
func _has_backpack_ammo_reserves() -> bool:
	var weapon = weapon_controller.current_weapon
	var expected_ammo_name: String = weapon.weapon_name + " Ammo"
	
	# Scan through your exact global Tetris data array matrix locations
	for item in InventoryGlobal.slot_data:
		if is_instance_valid(item):
			if item.item_type == "Consumable" and item.item_name == expected_ammo_name:
				# Verify it has at least one loose bullet left inside its internal magazine resource count
				if item.consumable_stats != null and item.consumable_stats.ammo > 0:
					return true
					
	return false
