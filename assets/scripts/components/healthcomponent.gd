class_name HealthComponent extends Node

signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int, damage_type: String)
signal died

@export var skills_component : SkillsComponent
@export var head_shape_index : int = 1
@export var headshot_multiplier : float = 2.0
@export var actor : CharacterBody3D

var max_health : int
var current_health : int
var is_alive : bool = true

func initialize_health() -> void:
	# Enforce baseline alive states to protect against frame-zero math truncation bugs
	is_alive = true
	
	# Fetch your dynamic max health from skills component if it's there
	if is_instance_valid(skills_component):
		max_health = skills_component.max_hp
	else:
		max_health = 100 # Fallback safety buffer
		
	current_health = max_health
	print("❤️ [HEALTH COMPONENT] Spawning player with full health pool: ", current_health, " | is_alive: ", is_alive)


func take_damage(amount: int, damage_type: String, source: Node3D = null, shape_id: int = -1) -> void:
	if not is_alive:
		return
	
	var resistance : float = 0.0
	
	# SENSOR SAFEGUARD: Ensure skills_component actually exists before reading its variables
	if is_instance_valid(skills_component):
		match damage_type:
			"shock": resistance = skills_component.shock_dam_res
			"blaster": resistance = skills_component.blaster_dam_res
			"bullet": resistance = skills_component.bullet_dam_res
			"physical": resistance = skills_component.phys_dam_res
			"explosive": resistance = skills_component.explosive_dam_res
			"poison": resistance = skills_component.poison_dam_res # Fixed a typo here ("posion" -> "poison")
	
	# Calculate standard mitigated damage cleanly
	var final_damage : int = max(1, int(amount * (1.0 - resistance)))
	print("Hit registered! Basic damage calculation: ", final_damage)
	
	# Apply headshot multiplier safely
	if shape_id == head_shape_index:
		final_damage = int(final_damage * headshot_multiplier)
		print("Headshot! Multiplier applied: ", headshot_multiplier, " | Total Damage: ", final_damage)
	
	current_health -= final_damage
	
	# --- TRIGGER CAMERA DAMAGE KICK ---
	# 1. Get the parent player node shell
	var parent_actor = get_parent()
	# Fallback if your components sit inside a structural "Components" Node3D container folder
	if parent_actor and parent_actor.name == "Components":
		parent_actor = parent_actor.get_parent()
		
	# 2. Extract the camera_effects reference we exported on the PlayerController script
	if parent_actor and "camera_effects" in parent_actor:
		var cam_fx = parent_actor.camera_effects
		if is_instance_valid(cam_fx) and cam_fx.has_method("add_damage_kick"):
			
			# 3. Determine the 3D source position of the damage
			var source_position: Vector3 = Vector3.ZERO
			if is_instance_valid(source):
				source_position = source.global_position
			else:
				# If hit by a projectile, it passes null for source. 
				# Fallback to generating a random direction so the camera still kicks dynamically!
				var random_angle = randf() * TAU
				source_position = parent_actor.global_position + Vector3(cos(random_angle), 0, sin(random_angle))
			
			# 4. Invoke your CameraEffects calculations! 
			# Pass your target Pitch angle (e.g. 5.0 degrees) and Roll angle (e.g. 8.0 degrees)
			cam_fx.add_damage_kick(5.0, 8.0, source_position)
			
			# Optional: Simultaneously trigger your built-in screen shake effect for heavy hits!
			if cam_fx.has_method("add_screen_shake"):
				cam_fx.add_screen_shake(0.2, 0.3)
	# ----------------------------------
	
	# Grab correct max HP fallback value for interface UI alerts
	var max_hp_reference = skills_component.max_hp if is_instance_valid(skills_component) else 100
	health_changed.emit(current_health, max_hp_reference)
	damage_taken.emit(final_damage, damage_type)
	
	print("🩸 Remaining NPC Health Pool: ", current_health)
	
	if current_health <= 0:
		die()

func heal(amount: float) -> void:
	if not is_alive:
		return
	# Implement clean logic clamping to max HP reference later

func die() -> void:
	is_alive = false # Toggle alive tracker status flag cleanly
	died.emit()
