extends PlayerState

func _on_crouching_state_entered() -> void:
	player_controller.crouch()

func _on_crouching_state_processing(delta: float) -> void:
	player_controller.camera.update_camera_height(delta, -1)
	if not Input.is_action_pressed("crouch"):
		if not player_controller.crouch_check.is_colliding():
			player_controller.state_chart.send_event("OnStanding")
		else:
			return
