extends Node

var npc: NPC # Injected by NPCStateMachine at ready
var path_initialized: bool = false
var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.25 # Recalculate path 4 times a second (saves performance)

func _on_combat_run_state_entered() -> void:
	print("⚔️ [COMBAT RUN] Tracking target positions aggressively...")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.COMBAT
		npc.anim_prefix = "combat_run" # Switches sprite rendering engine to combat pose
		path_initialized = false
		path_update_timer = 0.0
		_update_chase_path()

func _update_chase_path() -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.current_combat_target): 
		return
	
	var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
	npc.nav_agent.set_navigation_map(default_3d_map_rid)
	
	# Loosen path tolerances slightly for high-speed combat tracking
	npc.nav_agent.path_max_distance = 10.0
	npc.nav_agent.path_desired_distance = 1.0
	
	# Fetch dynamic weapon range to set path termination zone limits
	var weapon_max_range: float = 10.0 # Default backup range
	if npc.active_weapon_stats != null:
		weapon_max_range = npc.active_weapon_stats.range
		
	npc.nav_agent.target_desired_distance = weapon_max_range
	npc.nav_agent.target_position = npc.current_combat_target.global_position

func _on_combat_run_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	if not npc.is_on_floor(): npc.velocity += npc.get_gravity() * delta

	var target = npc.current_combat_target
	
	# Target Loss Safetynet: If player somehow deletes/vanishes, drop out of Combat back to Alerted
	if not is_instance_valid(target):
		if is_instance_valid(npc.state_chart):
			npc.state_chart.send_event("OnAlerted")
		return

	# Performance Throttle: Update navigation tracking coordinates periodically
	path_update_timer += delta
	if path_update_timer >= PATH_UPDATE_INTERVAL:
		path_update_timer = 0.0
		_update_chase_path()

	if not path_initialized and npc.nav_agent.get_current_navigation_path().size() > 0:
		path_initialized = true

	# --- WEAPON INVENTORY RANGE CHECK ---
	# Calculate flat horizontal distance to target
	var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
	var target_flat: Vector2 = Vector2(target.global_position.x, target.global_position.z)
	var current_distance = npc_flat.distance_to(target_flat)

	# Read the 'range' variable straight out of your Weapon custom resource slot!
	var weapon_max_range: float = 12.0 # Standard default fallback
	if npc.active_weapon_stats != null:
		weapon_max_range = npc.active_weapon_stats.range

	# If player steps inside our gun's unique firing range, stop and transition!
	if current_distance <= weapon_max_range:
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		if is_instance_valid(npc.state_chart):
			print("🎯 [COMBAT RUN] Target inside shooting range (", current_distance, "m <= ", weapon_max_range, "m). Transitioning to Aim.")
			npc.state_chart.send_event("OnCombatAim") # Micro-event transition
		return

	# Standard path tracking vector arithmetic
	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	next_path_pos.y = npc.global_position.y 
	var direction: Vector3 = (next_path_pos - npc.global_position).normalized()
	
	# Smooth face rotation alignment while chasing
	if direction.length_squared() > 0.001:
		var target_look = npc.global_position + direction
		if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
			var target_transform = npc.global_transform.looking_at(target_look, Vector3.UP)
			npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 14.0 * delta)

	# Combat Sprint Speed calculation
	var combat_sprint_speed: float = 5.0 
	npc.velocity.x = direction.x * npc.health_component.skills_component.sprint_speed
	npc.velocity.z = direction.z * npc.health_component.skills_component.sprint_speed
	npc.move_and_slide()
