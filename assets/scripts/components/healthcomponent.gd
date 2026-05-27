class_name HealthComponent extends Node

signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int, damage_type: String)
signal died

@export var skills_component : SkillsComponent
@export var head_shape_index : int = 1
@export var headshot_multiplier : float = 2.0
@export var actor : CharacterBody3D

var current_health : int
var is_alive : bool = true

func initialize_health() -> void:
	if is_instance_valid(skills_component):
		current_health = skills_component.max_hp
		print("💖 [HEALTH SYSTEM] Safely linked to SkillsComponent. Max HP initialized to: ", current_health)
	else:
		push_error("HealthComponent failed to initialize: Linked SkillsComponent is invalid or missing max_hp!")


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
