extends PlayerState

func _on_airborne_state_processing(delta: float) -> void:
	if player_controller.is_on_floor():
		if player_controller.check_fall_speed():
			player_controller.camera_effects.add_fall_kick(2.0)
		player_controller.state_chart.send_event("OnGrounded")
	
	player_controller.current_fall_velocity = player_controller.velocity.y
	
	if player_controller.velocity.y > 0 :
		player_controller.state_chart.send_event("OnJump")
	else:
		player_controller.state_chart.send_event("OnFall")
	
