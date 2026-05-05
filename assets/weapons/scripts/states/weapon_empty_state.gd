extends WeaponState


func _on_empty_state_entered() -> void:
	print("Weapon empty!")

func _on_empty_state_processing(delta: float) -> void:
	if not weapon_controller or not Managers.weapon_manager:
		return
	
	if Managers.weapon_manager.has_ammo():
		weapon_controller.weapon_state_chart.send_event("OnIdle")
