extends PlayerState

func _on_jump_state_processing(delta: float) -> void:

	if player_controller.is_on_floor():
		player_controller.state_chart.send_event("OnGrounded")
	
