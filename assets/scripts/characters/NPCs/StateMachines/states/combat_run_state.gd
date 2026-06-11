extends Node

var npc: NPC
var path_initialized: bool = false
var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.25

func _on_combat_run_state_entered() -> void:
	#print("⚔️ [COMBAT RUN] Tracking target positions...")
	if is_instance_valid(npc):
		npc.current_macro_state = npc.MacroState.COMBAT
		npc.anim_prefix = "combat_run"
		path_initialized = false
		path_update_timer = 0.0
		_update_chase_path()

func _update_chase_path() -> void:
	if not is_instance_valid(npc) or not is_instance_valid(npc.current_combat_target): return
	
	var default_3d_map_rid : RID = npc.get_world_3d().get_navigation_map()
	npc.nav_agent.set_navigation_map(default_3d_map_rid)
	
	var weapon_max_range: float = 12.0 # Default backup range
	if npc.active_weapon_stats != null:
		weapon_max_range = npc.active_weapon_stats.range
		
	npc.nav_agent.target_desired_distance = weapon_max_range
	npc.nav_agent.target_position = npc.current_combat_target.global_position

func _on_combat_run_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	if not npc.is_on_floor(): npc.velocity += npc.get_gravity() * delta

	var target = npc.current_combat_target
	if not is_instance_valid(target):
		npc.state_chart.send_event("OnAlerted")
		return

	path_update_timer += delta
	if path_update_timer >= PATH_UPDATE_INTERVAL:
		path_update_timer = 0.0
		_update_chase_path()

	if not path_initialized and npc.nav_agent.get_current_navigation_path().size() > 0:
		path_initialized = true

	# --- LAYER 2: WEAPON FIRING RANGE CHECK ---
	var npc_flat: Vector2 = Vector2(npc.global_position.x, npc.global_position.z)
	var target_flat: Vector2 = Vector2(target.global_position.x, target.global_position.z)
	var current_distance = npc_flat.distance_to(target_flat)

	var weapon_max_range: float = 12.0 # Fallback
	if npc.active_weapon_stats != null:
		weapon_max_range = npc.active_weapon_stats.range

	# If player steps inside our weapon's unique firing range, drop down into Aim node!
	if current_distance <= weapon_max_range:
		npc.velocity = Vector3.ZERO
		npc.move_and_slide()
		if is_instance_valid(npc.state_chart):
			#print("🎯 [COMBAT RUN] Target inside shooting range (", current_distance, "m <= ", weapon_max_range, "m). Halting to Aim.")
			npc.state_chart.send_event("OnCombatAim")
		return

	# Path Tracking Steering
	var next_path_pos: Vector3 = npc.nav_agent.get_next_path_position()
	next_path_pos.y = npc.global_position.y 
	var direction: Vector3 = (next_path_pos - npc.global_position).normalized()
	
	if direction.length_squared() > 0.001:
		var target_look = npc.global_position + direction
		if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
			var target_transform = npc.global_transform.looking_at(target_look, Vector3.UP)
			npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 14.0 * delta)

	var combat_sprint_speed = npc.health_component.skills_component.sprint_speed
	npc.velocity.x = direction.x * combat_sprint_speed
	npc.velocity.z = direction.z * combat_sprint_speed
	npc.move_and_slide()
