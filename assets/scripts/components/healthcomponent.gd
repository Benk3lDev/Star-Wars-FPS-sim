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

func _ready() -> void:
	# If we didn't assign the actor in the inspector, find the NPC root automatically
	if not actor:
		var current = get_parent()
		while current and not (current is CharacterBody3D):
			current = current.get_parent()
		actor = current as CharacterBody3D

	# Fallback re-link for skills component if it broke during un-nesting
	if not skills_component:
		skills_component = get_parent().get_node_or_null("SkillsComponent")
		if not skills_component and actor:
			skills_component = actor.get_node_or_null("SkillsComponent")

	# Secure our starting health value safely
	if skills_component:
		current_health = skills_component.max_hp
	else:
		current_health = 100.0


func take_damage(amount: int, damage_type: String, source: Node3D = null, shape_id: int = -1) -> void:
	if not is_alive:
		return
	
	var resistance : float = 0.0
	
	match damage_type:
		"shock": resistance = skills_component.shock_dam_res
		"blaster": resistance = skills_component.blaster_dam_res
		"bullet": resistance = skills_component.bullet_dam_res
		"physical": resistance = skills_component.phys_dam_res
		"explosive": resistance = skills_component.explosive_dam_res
		"posion": resistance = skills_component.poison_dam_res
	
	# Calculate standard mitigated damage first
	var final_damage : int = max(1, int(amount * (1.0 - resistance)))
	
	print("hit! damage: ", final_damage)
	
	# Apply headshot multiplier if the hit shape index matches the head
	if shape_id == head_shape_index:
		final_damage = int(final_damage * headshot_multiplier)
		print("Headshot! Applied multiplier: ", headshot_multiplier)
	
	current_health -= final_damage
	health_changed.emit(current_health, skills_component.max_hp)
	damage_taken.emit(final_damage, damage_type)
	
	if current_health <= 0:
		die()


func heal(amount: float) -> void:
	if not is_alive:
		return


func die() -> void:
	died.emit()
	
