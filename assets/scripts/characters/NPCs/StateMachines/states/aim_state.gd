extends Node

var npc: NPC # Injected by NPCStateMachine at ready

func _on_combat_aim_state_entered() -> void:
	print("🎯 [COMBAT AIM] Target acquired. Framing target...")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.COMBAT
		npc.anim_prefix = "idleaim"
		
		# Freeze physical movement while tracking sightlines
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		
		# Simulates a brief 0.4 second lock-on delay before pulling the trigger
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(npc) and npc.current_macro_state == npc.MacroState.COMBAT:
				_evaluate_next_combat_action()
		)

func _evaluate_next_combat_action() -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.state_chart): return
	
	# Check the unified current_ammo tracker we initialized on the root NPC script
	if npc.current_ammo <= 0:
		print("🔄 [COMBAT AIM] Clip is empty! Dispatching OnCombatReload micro-event.")
		npc.state_chart.send_event("OnCombatReload")
	else:
		npc.state_chart.send_event("OnCombatFire")

func _on_combat_aim_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	var target = npc.current_combat_target
	if not is_instance_valid(target): return
	
	# Explicitly turn the NPC's body matrix to face the enemy position
	var target_pos = target.global_position
	target_pos.y = npc.global_position.y
	var direction = (target_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(target_pos, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 16.0 * delta)
