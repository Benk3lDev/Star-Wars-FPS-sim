extends Node

var npc: NPC # Injected by NPCStateMachine at ready
var search_points_visited: int = 0
var current_search_sub_target: Vector3 = Vector3.ZERO
var path_initialized: bool = false

func _on_alerted_search_state_entered() -> void:
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.ALERTED
		npc.anim_prefix = "walknocombat"
		path_initialized = false
		
		if not npc.is_searching_alert_zone:
			npc.is_searching_alert_zone = true
			search_points_visited = 0
			
		# EXIT CONDITIONAL: If area is clean after 3 checks, fire the macro-level exit event!
		if search_points_visited >= 3:
			print("🏳️ [ALERTED SEARCH] Nothing found. Exiting folder back to AtEase.")
			npc.is_searching_alert_zone = false
			if is_instance_valid(npc.state_chart):
				npc.state_chart.send_event("OnAtEase") # Macro Reset Event
			return
			
		await get_tree().physics_frame
		if not is_instance_valid(npc) or npc.current_macro_state != npc.MacroState.ALERTED: return
		
		var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
		npc.nav_agent.set_navigation_map(default_3d_map_rid)
		
		# Compute random target around last known spot
		var random_angle: float = randf() * TAU
		var search_offset: Vector3 = Vector3(cos(random_angle), 0, sin(random_angle)) * 3.5
		current_search_sub_target = npc.alert_target_position + search_offset
		
		var snapped_target = NavigationServer3D.map_get_closest_point(default_3d_map_rid, current_search_sub_target)
		npc.nav_agent.target_position = snapped_target
		print("🔍 [ALERTED SEARCH] Check point index #", search_points_visited, ": ", snapped_target)

func _on_alerted_search_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	if not npc.is_on_floor(): npc.velocity += npc.get_gravity() * delta

	if not path_initialized and npc.nav_agent.get_current_navigation_path().size() > 0:
		path_initialized = true

	var arrived: bool = false
	if path_initialized and npc.nav_agent.is_navigation_finished(): arrived = true
	
	var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
	var target_flat: Vector2 = Vector2(current_search_sub_target.x, current_search_sub_target.z)
	if npc_flat.distance_to(target_flat) <= 0.8: arrived = true

	if arrived:
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		path_initialized = false
		search_points_visited += 1
		
		# Re-enter to calculate next point or evaluate the exit criteria loop
		_on_alerted_search_state_entered()
		return

	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	next_path_pos.y = npc.global_position.y 
	var direction: Vector3 = (next_path_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(npc.global_position + direction, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 10.0 * delta)

	var search_walk_speed: float = 3.5
	npc.velocity.x = direction.x * search_walk_speed
	npc.velocity.z = direction.z * search_walk_speed
	npc.move_and_slide()
