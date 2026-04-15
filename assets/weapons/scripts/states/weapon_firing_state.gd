extends WeaponState

func _on_firing_state_entered() -> void:
	if not weapon_controller:
		return


	# Fire Immediately on state entry
	weapon_controller.fire_weapon()


func _on_firing_state_processing(delta: float) -> void:
	if not weapon_controller:
		return

	# Check if ammo is empty
	if weapon_controller.current_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("OnEmpty")
		return

	# Check fire mode
	if weapon_controller.current_weapon.is_automatic:
		if Input.is_action_pressed("attack"):
			if weapon_controller.can_fire():
				weapon_controller.fire_weapon()

		else:
			weapon_controller.weapon_state_chart.send_event("OnIdle")

	else:
		weapon_controller.weapon_state_chart.send_event("OnIdle")
