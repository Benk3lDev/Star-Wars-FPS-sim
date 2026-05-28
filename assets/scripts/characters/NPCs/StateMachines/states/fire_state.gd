extends Node

var npc: NPC # Injected by NPCStateMachine at ready

# Connect this to your StateChart's Fire -> state_entered() signal in the editor
func _on_combat_fire_state_entered() -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.current_combat_target): 
		return
	
	npc.current_macro_state = npc.MacroState.COMBAT
	npc.anim_prefix = "shooting"
	
	# Fetch firing interval constraints straight from your manager script setup parameters
	# Formula matches player: fire_rate_timer = 1.0 / weapon.fire_rate
	var delay: float = 0.3
	if npc.active_weapon_stats != null:
		delay = 1.0 / npc.active_weapon_stats.fire_rate
	
	# TRIGGER THE FIRE COMMAND ROUTINE
	if npc.weapon_controller and npc.weapon_controller.has_method("npc_fire_weapon"):
		npc.weapon_controller.npc_fire_weapon(npc.current_combat_target)
		
	# Force the 8-way billboarding system to immediately draw the weapon discharge frame
	if npc.has_method("update_billboard_animation"):
		npc.update_billboard_animation()

	# Hold processing loop matching the weapon's automatic firing cadence interval
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(npc) and npc.current_macro_state == npc.MacroState.COMBAT:
			_evaluate_post_fire_conditions()
	)

func _evaluate_post_fire_conditions() -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.state_chart): 
		return
	
	var target = npc.current_combat_target
	
	# Fallback out of Combat if target disappears completely out of memory
	if not is_instance_valid(target):
		npc.state_chart.send_event("OnAlerted")
		return
	
	# If the player ducked behind cover or broke line of sight, switch back to chase/run
	if is_instance_valid(npc.vision) and not npc.vision.is_entity_visible(target):
		print("🏃 [COMBAT FIRE] Target broke line of sight! Re-entering CombatRun pursuit.")
		npc.state_chart.send_event("OnCombatRun")
		return
		
	# If player is still visible, route back to Aim to re-check ammo capacity fields
	npc.state_chart.send_event("OnCombatAim")

# Connect this to your StateChart's Fire -> state_physics_processing(delta) signal
func _on_combat_fire_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	var target = npc.current_combat_target
	if not is_instance_valid(target): return
	
	# Keep the NPC's body matrix locked tightly on the player coordinates while cycling bursts
	var target_pos = target.global_position
	target_pos.y = npc.global_position.y
	
	if (target_pos - npc.global_position).length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(target_pos, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 16.0 * delta)
