extends Node

var npc: NPC # Injected by NPCStateMachine at ready

# Internal tracking arrays and positions
var waypoint_positions: Array[Vector3] = []
var current_waypoint_index: int = 0
var path_initialized: bool = false
var spawn_origin: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Store where the NPC originally spawned after the engine finishes loading
	await get_tree().physics_frame
	if is_instance_valid(npc):
		spawn_origin = npc.global_position

func _on_walk_state_entered() -> void:
	print("🐾 [WALK STATE] Entered AtEase Walk.")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.AT_EASE
		npc.anim_prefix = "walknocombat"
		path_initialized = false
		
		# 1. Wait a frame for physics server loops to settle
		await get_tree().physics_frame
		
		# Interruption Safety Guard: If an enemy startled us into Alerted 
		# during that frame pause, completely halt patrol calculations!
		if not is_instance_valid(npc) or npc.current_macro_state != npc.MacroState.AT_EASE:
			print("⚠️ [WALK STATE] Aborted: State changed while waiting for physics frame.")
			return
		
		# 2. Force explicit world navigation map binding
		var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
		npc.nav_agent.set_navigation_map(default_3d_map_rid)
		
		# 3. Tighten navigation arrival thresholds to prevent early arrival loops
		npc.nav_agent.path_max_distance = 10.0
		npc.nav_agent.path_desired_distance = 0.5
		npc.nav_agent.target_desired_distance = 0.5
		
		# 4. Target Position Selection
		var target_pos: Vector3 = Vector3.ZERO
		
		if npc.custom_waypoints.size() > 0:
			# --- CUSTOM FIXED WAYPOINT LOOP ---
			if waypoint_positions.size() == 0:
				_build_waypoint_cache()
			
			if waypoint_positions.size() > 0:
				target_pos = waypoint_positions[current_waypoint_index]
				print("📍 [PATROL] Heading to custom waypoint #", current_waypoint_index, ": ", target_pos)
			else:
				target_pos = npc.global_position # Backup safe zone
		else:
			# --- AUTONOMOUS RANDOM PATROL ---
			if spawn_origin == Vector3.ZERO:
				spawn_origin = npc.global_position
				
			var random_angle: float = randf() * TAU
			var offset: Vector3 = Vector3(cos(random_angle), 0, sin(random_angle)) * npc.random_patrol_radius
			target_pos = spawn_origin + offset
			print("🎲 [PATROL] Heading to random spot near spawn: ", target_pos)
		
		# 5. Snap target point tightly to navigation mesh geometry
		var snapped_target = NavigationServer3D.map_get_closest_point(default_3d_map_rid, target_pos)
		npc.nav_agent.target_position = snapped_target

## Translates NodePaths from the NPC root inspector context into global Vector3 coordinates
func _build_waypoint_cache() -> void:
	waypoint_positions.clear()
	for path in npc.custom_waypoints:
		var node = npc.get_node_or_null(path)
		if node is Node3D:
			waypoint_positions.append(node.global_position)
		else:
			push_warning("❌ [PATROL ERROR] Waypoint Node at path ", path, " could not be resolved by NPC: ", npc.npc_resource.name)

func _on_walk_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta

	# Synchronize path initialization
	if not path_initialized:
		if npc.nav_agent.get_current_navigation_path().size() > 0:
			path_initialized = true

	# Arrival conditional gate
	var arrived: bool = false
	
	# 1. Fallback backup check: query Godot's internal server state
	if path_initialized and npc.nav_agent.is_navigation_finished():
		arrived = true
		
	# 2. THE FIX: Explicitly check flat horizontal distance to the active waypoint node
	if not arrived and npc.custom_waypoints.size() > 0 and waypoint_positions.size() > 0:
		var current_target_point: Vector3 = waypoint_positions[current_waypoint_index]
		
		# Strip the Y axis completely out of both vectors
		var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
		var target_flat: Vector2 = Vector2(current_target_point.x, current_target_point.z)
		
		# If we are within 0.7 meters horizontally, force an arrival!
		if npc_flat.distance_to(target_flat) <= 0.7:
			arrived = true

	# Execute arrival logic
	if arrived:
		print("🎯 [WALK STATE] Target achieved! Reached point #", current_waypoint_index)
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		path_initialized = false
		
		# Loop index advancement sequence
		if npc.custom_waypoints.size() > 0 and waypoint_positions.size() > 0:
			current_waypoint_index = (current_waypoint_index + 1) % waypoint_positions.size()
			print("⏭️ [PATROL] Index advanced. Next target index is: #", current_waypoint_index)
			
		if is_instance_valid(npc.state_chart):
			npc.state_chart.send_event("OnIdle")
		return

	# Movement & Path tracking steering math
	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	var current_pos: Vector3 = npc.global_position
	next_path_pos.y = current_pos.y 
	var direction: Vector3 = (next_path_pos - current_pos).normalized()
	
	if direction.is_equal_approx(Vector3.ZERO):
		direction = -npc.global_transform.basis.z
		
	# Smooth turn interpolation
	if direction.length_squared() > 0.001:
		var target_look = npc.global_position + direction
		if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
			var target_transform = npc.global_transform.looking_at(target_look, Vector3.UP)
			npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 10.0 * delta)

	var uniform_walk_speed: float = 3.0
	npc.velocity.x = direction.x * uniform_walk_speed
	npc.velocity.z = direction.z * uniform_walk_speed
	npc.move_and_slide()
