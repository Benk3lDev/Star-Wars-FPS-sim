extends PlayerState


func _on_straight_state_processing(delta: float) -> void:
	
	if player_controller.target_lean == -1.0:
		player_controller.state_chart.send_event("OnLeftLeaning")
	elif player_controller.target_lean == 1.0:
		player_controller.state_chart.send_event("OnRightLeaning")
	else:
		return
