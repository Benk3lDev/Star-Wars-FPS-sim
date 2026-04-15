extends WeaponState

func _on_idle_state_processing(delta: float) -> void:
	if not weapon_controller:
		return

	# Check for fire input
	if Input.is_action_just_pressed("attack") and weapon_controller.can_fire():
		weapon_controller.weapon_state_chart.send_event("OnFiring")

	if weapon_controller.current_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("OnEmpty")
