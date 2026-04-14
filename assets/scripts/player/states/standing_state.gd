extends PlayerState

func _on_standing_state_entered() -> void:
	player_controller.stand()

func _on_standing_state_processing(delta: float) -> void:
	player_controller.camera.update_camera_height(delta, 1)
	
	if Input.is_action_pressed("crouch"):
		player_controller.state_chart.send_event("OnCrouching")
