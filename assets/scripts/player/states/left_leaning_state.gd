extends PlayerState



func _on_left_leaning_state_processing(delta: float) -> void:
	if player_controller.target_lean == 0.0:
		player_controller.state_chart.send_event("OnStraight")
