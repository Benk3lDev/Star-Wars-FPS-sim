extends PlayerState

func _on_walking_state_entered() -> void:
	player_controller.walk()

func _on_walking_state_processing(delta: float) -> void:
	
	if Input.is_action_just_pressed("walk"):
		player_controller.state_chart.send_event("OnJogging")
	if Input.is_action_pressed("sprint"):
		player_controller.state_chart.send_event("OnSprinting")


func _on_walking_state_exited() -> void:
	player_controller.walk()
