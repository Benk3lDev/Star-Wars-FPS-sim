extends WeaponState

func _on_reload_state_entered() -> void:
	print("🔄 [WEAPON STATE] Entered player reload state.")
	
	if not weapon_controller or not weapon_controller.current_weapon:
		_abort_to_idle()
		return
		
	var weapon = weapon_controller.current_weapon
	
	# 1. Run basic inventory depletion checks
	var reload_successful: bool = false
	if weapon_controller.has_method("reload_weapon"):
		reload_successful = weapon_controller.reload_weapon()
	
	if not reload_successful:
		print("⚠️ [WEAPON STATE] Reload failed. Bypassing timer.")
		_abort_to_idle()
		return
		
	# 2. EXTRACT RESOURCE SKILL SCORING VIA THE GLOBAL GETTER FUNCTION
	var skill_score: int = 0
	
	var player_root = weapon_controller.player_controller if "player_controller" in weapon_controller else null
	if not player_root and weapon_controller.get_parent():
		player_root = weapon_controller.get_parent()
		
	if is_instance_valid(player_root) and "skills" in player_root and is_instance_valid(player_root.skills):
		var skills_comp = player_root.skills
		
		# Invoke your specific custom method!
		if skills_comp.has_method("get_weapon_skill_total"):
			skill_score = skills_comp.get_weapon_skill_total(weapon.weapon_skill_key)
	
	# 3. COMPUTE FLUID PRECISION SPEED VALUES
	# Clamp skill at 100 max. A score of 100 reduces reload time by 50% (0.5x multiplier)
	var skill_float: float = float(skill_score)
	var speed_modifier: float = 1.0 - (clamp(skill_float, 0.0, 100.0) * 0.005)
	var final_reload_duration: float = weapon.reload_time * speed_modifier
	
	print("⏳ [WEAPON STATE] Skill Data ID '", weapon.weapon_skill_key, "' total value: ", skill_score)
	print("   -> Speed Modifier: ", speed_modifier, "x | Dynamic Duration: ", final_reload_duration, "s")
	
	# 4. COMMENCE TIMER COUNTDOWN
	get_tree().create_timer(final_reload_duration).timeout.connect(func():
		if is_instance_valid(weapon_controller) and weapon_controller.current_weapon != null:
			if is_instance_valid(weapon_controller.weapon_state_chart):
				print("✅ [WEAPON STATE] Reload complete. Swapping states back to Idle.")
				weapon_controller.weapon_state_chart.send_event("OnIdle")
	)

func _abort_to_idle() -> void:
	if is_instance_valid(weapon_controller) and is_instance_valid(weapon_controller.weapon_state_chart):
		weapon_controller.weapon_state_chart.send_event("OnIdle")
