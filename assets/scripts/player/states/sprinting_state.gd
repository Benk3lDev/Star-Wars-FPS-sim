extends PlayerState

func _on_sprinting_state_entered() -> void:
	print("PlayerSprint")
	player_controller.sprint()

func _on_sprinting_state_processing(delta: float) -> void:	
	if not Input.is_action_pressed("sprint"):
		player_controller.state_chart.send_event("OnJogging")
	
	if player_controller.is_crouch:
		player_controller.state_chart.send_event("OnCrouching")
