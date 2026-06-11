extends Node

var npc : NPC # Injected by NPCStateMachine at ready

# Configuration: Type your default animation length here if it differs from the weapon resource baseline
const DEFAULT_ANIM_BASE_DURATION : float = 2.0 

# Runtime Tracking Variables
var dynamic_reload_duration : float = 2.0
var animation_speed_scale : float = 1.0
var reload_timer : float = 0.0
var is_reloading : bool = false

func _on_combat_reload_state_entered() -> void:
	if not is_instance_valid(npc) or npc.active_weapon_stats == null:
		_finalize_reload()
		return
		
	var weapon = npc.active_weapon_stats
	print("🔄 [ENEMY RELOAD]: NPC '", npc.name, "' is reloading a ", weapon.weapon_name)
	
	# 1. HALT PHYSICS MOMENTUM
	npc.velocity = Vector3.ZERO
	npc.move_and_slide()
	
	# 2. EXTRACT THE NPC'S SKILL TOTAL FROM ITS SYSTEM DICTIONARY
	var skill_score: int = 0
	if is_instance_valid(npc.skills_component) and npc.skills_component.has_method("get_weapon_skill_total"):
		skill_score = npc.skills_component.get_weapon_skill_total(weapon.weapon_skill_key)
		
	# 3. CALCULATE THE DYNAMIC RELOAD TIME REDUCTION
	var skill_float: float = float(skill_score)
	var speed_modifier: float = 1.0 - (clamp(skill_float, 0.0, 100.0) * 0.005)
	
	# Compute the precise duration this state will occupy
	dynamic_reload_duration = weapon.reload_time * speed_modifier
	
	# 4. COMPUTE THE SPRITE FRAME-RATE MULTIPLIER (Dynamic Variant)
	# Formula: Native Sprite Animation Length / Skill-Adjusted Duration
	# This guarantees that the animation will speed up or slow down 
	# to finish exactly the same frame the lock-out timer hits zero!
	var native_anim_time: float = weapon.base_animation_length if "base_animation_length" in weapon else 2.0
	
	if dynamic_reload_duration > 0.001:
		animation_speed_scale = native_anim_time / dynamic_reload_duration
	else:
		animation_speed_scale = 1.0
	
	# 5. ENGAGE RUNTIME TIMERS
	reload_timer = dynamic_reload_duration
	is_reloading = true
	
	# Change animation prefix immediately on entry
	npc.anim_prefix = "combat_reload"
	
	# Force an immediate visual redrawing step
	if npc.has_method("update_billboard_animation"):
		npc.update_billboard_animation()

func _on_combat_reload_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead or not is_reloading: 
		return
		
	# 1. Maintain body rotation lock toward your combat enemy target while reloading
	var target = npc.current_combat_target
	if is_instance_valid(target):
		var target_pos = target.global_position
		target_pos.y = npc.global_position.y
		
		if (target_pos - npc.global_position).length_squared() > 0.001:
			var target_transform = npc.global_transform.looking_at(target_pos, Vector3.UP)
			npc.global_transform.basis = npc.global_transform.basis.slerp(target_transform.basis, 8.0 * delta)

	# 2. RUN ANIMATION SPEED PLAYBACK SCALING INJECTION
	# If your 8-directional billboard system uses an AnimatedSprite3D or SpriteFrames node,
	# we inject our custom speed scale straight into the engine's playback property slot!
	if is_instance_valid(npc.sprite) and "speed_scale" in npc.sprite:
		npc.sprite.speed_scale = animation_speed_scale

	# 3. TICK DOWN THE DYNAMIC LOCK TIMERS
	reload_timer -= delta
	
	if reload_timer <= 0.0:
		_finalize_reload()

func _finalize_reload() -> void:
	is_reloading = false
	
	# Reset sprite engine framerates back to their default standard speed baseline
	if is_instance_valid(npc) and is_instance_valid(npc.sprite) and "speed_scale" in npc.sprite:
		npc.sprite.speed_scale = 1.0
		
	if is_instance_valid(npc) and npc.active_weapon_stats != null:
		# REFILL THE CHAMBER TO MAX CAPACITY
		npc.current_ammo = npc.active_weapon_stats.max_ammo
		print("✅ [ENEMY RELOAD] Refill complete! Current Ammo: ", npc.current_ammo)
		
		# Micro-event to exit the loading lock and return back to chasing/running parameters
		if is_instance_valid(npc.state_chart):
			npc.state_chart.send_event("OnCombatRun")
