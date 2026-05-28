extends Node

var npc: NPC # Injected by NPCStateMachine at ready

func _on_alerted_idle_state_entered() -> void:
	print("⚠️ [ALERTED IDLE] Folder opened. Locking focus on threat coordinates.")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.ALERTED
		npc.anim_prefix = "idle" # Stunned reaction loop
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		
		# Stand startled for 1.5 seconds, then execute micro-transition to walk over
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(npc) and npc.current_macro_state == npc.MacroState.ALERTED:
				if is_instance_valid(npc.state_chart):
					print("⏭️ [ALERTED IDLE] Finished reaction delay. Advancing to AlertedWalk.")
					npc.state_chart.send_event("OnAlertedWalk")
		)

func _on_alerted_idle_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	
	# Turn to face the last known alert position coordinate vector dynamically
	var target_pos = npc.alert_target_position
	target_pos.y = npc.global_position.y
	var direction = (target_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(target_pos, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 12.0 * delta)
