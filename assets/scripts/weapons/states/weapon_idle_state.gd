extends WeaponState

func _on_idle_state_processing(delta: float) -> void:
	if not weapon_controller: return
	if InventoryGlobal.current_drag_data != null: return
	if InventoryGlobal.ui_node and InventoryGlobal.ui_node.visible: return

	# Just detect the initial touch frame
	if Input.is_action_just_pressed("attack"):
		if weapon_controller.can_fire():
			weapon_controller.weapon_state_chart.send_event("OnFiring")

	if not weapon_controller.has_ammo():
		weapon_controller.weapon_state_chart.send_event("OnEmpty")
