extends WeaponState

func _on_idle_state_processing(delta: float) -> void:
	if not weapon_controller: return
	if InventoryGlobal.current_drag_data != null: return
	if InventoryGlobal.ui_node and InventoryGlobal.ui_node.visible: return

	# 1. Fetch your dynamic runtime weapon manager group instance
	var wm = get_tree().get_first_node_in_group("weapon_manager")
	if not wm or wm.current_equipped_item == null: return
	
	# --- THE DYNAMIC AMMO TRACKER ---
	# This variable captures exactly how many shots your equipped gun has left right now
	var current_runtime_ammo: int = wm.current_equipped_item.ammo
	var max_capacity: int = weapon_controller.current_weapon.max_ammo
	# ---------------------------------

	# Automatically drop the weapon to an Empty sub-state if you hit 0 bullets
	if current_runtime_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("OnEmpty")
		return

	# Detect the initial pull of the trigger
	if Input.is_action_just_pressed("attack"):
		if weapon_controller.can_fire():
			weapon_controller.weapon_state_chart.send_event("OnFiring")
			return
	
	# FIX: Changed 'is_action_pressed' to 'just_pressed' so it triggers once per click,
	# and fixed the inversion operator so you can reload when current_ammo is LESS than max
	if Input.is_action_just_pressed("reload"):
		if current_runtime_ammo < max_capacity:
			weapon_controller.weapon_state_chart.send_event("OnReload")
