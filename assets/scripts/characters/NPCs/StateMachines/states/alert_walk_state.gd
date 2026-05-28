extends Node

var npc: NPC # Injected by NPCStateMachine at ready
var path_initialized: bool = false

func _on_alerted_walk_state_entered() -> void:
	print("🐾 [ALERTED WALK] Walking to investigate last known coordinates.")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.ALERTED
		npc.anim_prefix = "walkcombat"
		path_initialized = false
		
		await get_tree().physics_frame
		if not is_instance_valid(npc) or npc.current_macro_state != npc.MacroState.ALERTED: return
		
		var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
		npc.nav_agent.set_navigation_map(default_3d_map_rid)
		
		npc.nav_agent.path_max_distance = 10.0
		npc.nav_agent.path_desired_distance = 0.5
		npc.nav_agent.target_desired_distance = 0.5
		
		var snapped_target = NavigationServer3D.map_get_closest_point(default_3d_map_rid, npc.alert_target_position)
		npc.nav_agent.target_position = snapped_target

func _on_alerted_walk_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	if not npc.is_on_floor(): npc.velocity += npc.get_gravity() * delta

	if not path_initialized and npc.nav_agent.get_current_navigation_path().size() > 0:
		path_initialized = true

	# Arrival conditional gate calculation
	var arrived: bool = false
	if path_initialized and npc.nav_agent.is_navigation_finished(): arrived = true
	
	var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
	var target_flat: Vector2 = Vector2(npc.alert_target_position.x, npc.alert_target_position.z)
	if npc_flat.distance_to(target_flat) <= 0.8: arrived = true

	if arrived:
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		path_initialized = false
		
		# Micro transition event to enter local grid scanning patterns
		if is_instance_valid(npc.state_chart):
			print("🎯 [ALERTED WALK] Position reached. Triggering local area search pattern.")
			npc.state_chart.send_event("OnAlertedSearch")
		return

	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	next_path_pos.y = npc.global_position.y 
	var direction: Vector3 = (next_path_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(npc.global_position + direction, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 10.0 * delta)

	var alert_speed: float = 3.5
	npc.velocity.x = direction.x * alert_speed
	npc.velocity.z = direction.z * alert_speed
	npc.move_and_slide()
