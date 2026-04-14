extends PlayerState

func _on_jogging_state_entered() -> void:
	player_controller.jog()


func _on_jogging_state_processing(delta: float) -> void:
	
	if Input.is_action_pressed("sprint"):
		player_controller.state_chart.send_event("OnSprinting")
	
	if Input.is_action_just_pressed("walk"):
		player_controller.state_chart.send_event("OnWalking")
