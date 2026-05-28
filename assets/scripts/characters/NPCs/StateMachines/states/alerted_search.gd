extends Node

var npc: NPC # Injected by NPCStateMachine at ready
var search_points_visited: int = 0
var current_search_sub_target: Vector3 = Vector3.ZERO
var path_initialized: bool = false
var is_waiting_at_point: bool = false # Latch to halt updates during looking animations

func _on_alerted_search_state_entered() -> void:
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.ALERTED
		path_initialized = false
		is_waiting_at_point = false
		
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
		
		# --- NOW STARTING MOVEMENT: ASSIGN WALK ANIMATION PREFIX ---
		npc.anim_prefix = "walkcombat"
		if npc.has_method("update_billboard_animation"):
			npc.update_billboard_animation()
		
		var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
		npc.nav_agent.set_navigation_map(default_3d_map_rid)
		
		# Compute random target around last known spot
		var random_angle: float = randf() * TAU
		var search_offset: Vector3 = Vector3(cos(random_angle), 0, sin(random_angle)) * 3.5
		current_search_sub_target = npc.alert_target_position + search_offset
		
		var snapped_target = NavigationServer3D.map_get_closest_point(default_3d_map_rid, current_search_sub_target)
		npc.nav_agent.target_position = snapped_target
		print("🔍 [ALERTED SEARCH] Moving to check point #", search_points_visited, ": ", snapped_target)

func _on_alerted_search_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	if not npc.is_on_floor(): npc.velocity += npc.get_gravity() * delta

	# 1. If we are waiting, keep velocity zeroed out
	if is_waiting_at_point:
		npc.velocity.x = 0
		npc.velocity.z = 0
		npc.move_and_slide()
		return

	if not path_initialized and npc.nav_agent.get_current_navigation_path().size() > 0:
		path_initialized = true

	# 2. THE ARRIVAL GATE FIX: Evaluate distance strictly on a flat 2D plane
	var arrived: bool = false
	if path_initialized and npc.nav_agent.is_navigation_finished(): 
		arrived = true
	
	# Strip the Y axis height entirely out of both location vectors
	var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
	var target_flat: Vector2 = Vector2(current_search_sub_target.x, current_search_sub_target.z)
	
	# Check horizontal distance against a slightly wider radius (0.8m) to absorb physics drift
	if npc_flat.distance_to(target_flat) <= 0.8: 
		arrived = true

	# 3. EXECUTE RE-STABILIZED ARRIVAL LOGIC
	if arrived:
		is_waiting_at_point = true
		npc.velocity = Vector3.ZERO
		path_initialized = false
		search_points_visited += 1
		
		# Immediately update prefix and force the billboard sprite update
		npc.anim_prefix = "idleaim" 
		if npc.has_method("update_billboard_animation"):
			npc.update_billboard_animation()
			
		print("👀 [ALERTED SEARCH] Point #", search_points_visited - 1, " reached. Scanning area...")
		
		# Stand completely still looking around for 2 seconds, then transition
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(npc) and npc.current_macro_state == npc.MacroState.ALERTED:
				_on_alerted_search_state_entered()
		)
		
		npc.move_and_slide()
		return

	# 4. Standard path tracking movement steering arithmetic
	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	next_path_pos.y = npc.global_position.y 
	var direction: Vector3 = (next_path_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_transform = npc.global_transform.looking_at(npc.global_position + direction, Vector3.UP)
		npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 10.0 * delta)

	var search_walk_speed: float = 2.0
	npc.velocity.x = direction.x * search_walk_speed
	npc.velocity.z = direction.z * search_walk_speed
	npc.move_and_slide()
