class_name NPCVisionSensor extends Node3D

var npc: NPC
var head_node: CollisionShape3D = null

func _ready() -> void:
	npc = get_parent() as NPC
	
	# Looks for the existing head collision shape in the scene tree for vision origin
	if npc.has_node("HitboxArea/Head"):
		head_node = npc.get_node("HitboxArea/Head") as CollisionShape3D
	else:
		push_warning("NPCVisionSensor couldn't find 'HitboxArea/Head' node! Falling back to root coordinate position.")

## Pure sensor scan. Returns the closest visible enemy right now, caching nothing.
func scan_for_enemies() -> CharacterBody3D:
	if not npc or npc.is_dead:
		return null

	# Scan for dynamic entities registered in our automated group pool
	var targets = get_tree().get_nodes_in_group("actors")
	var closest_enemy: CharacterBody3D = null
	var closest_distance: float = npc.max_sight_distance 
	
	for target in targets:
		if target == npc:
			continue 
			
		# --- DYNAMIC ROOT LAYER UNIFICATION ---
		# Read the displayed uniform faction directly from the CharacterBody3D root variables
		var discovered_faction = target.faction if "faction" in target else GameManager.Faction.CIVILIAN

		# CRITICAL MATH RULE FIX: You must evaluate line of sight FIRST, 
		# before executing faction behavior profile rules!
		if is_entity_visible(target):
			var hostile_match = is_hostile_towards(target)
			
			if hostile_match:
				var origin_pos = head_node.global_position if head_node else npc.global_position
				var distance = origin_pos.distance_to(target.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = target
		
	return closest_enemy

func is_hostile_towards(target: Node) -> bool:
	if not npc:
		return false
		
	# FIX: Read the uniform faction variable straight off your NPC's main body root scope!
	var my_faction = npc.faction
	var target_faction = target.faction if "faction" in target else GameManager.Faction.CIVILIAN

	# MATCH YOUR SPECIFIC RELATIONS MATRIX
	match my_faction:
		GameManager.Faction.REPUBLIC:
			return target_faction == GameManager.Faction.CIS or \
				   target_faction == GameManager.Faction.PLF or \
				   target_faction == GameManager.Faction.MERC
			
		GameManager.Faction.CIS:
			return target_faction == GameManager.Faction.REPUBLIC or \
				   target_faction == GameManager.Faction.PLF or \
				   target_faction == GameManager.Faction.MERC
			
		GameManager.Faction.PLF:
			return target_faction == GameManager.Faction.REPUBLIC or \
				   target_faction == GameManager.Faction.CIS or \
				   target_faction == GameManager.Faction.MERC
			
		GameManager.Faction.MERC:
			return target_faction == GameManager.Faction.REPUBLIC or \
				   target_faction == GameManager.Faction.CIS or \
				   target_faction == GameManager.Faction.PLF
			
		GameManager.Faction.CIVILIAN:
			return false
			
	return false

func is_entity_visible(target: CharacterBody3D) -> bool:
	if not is_instance_valid(target) or ("is_dead" in target and target.is_dead):
		return false
		
	var vision_origin: Vector3 = npc.global_position
	if is_instance_valid(head_node):
		vision_origin = head_node.global_position
		
	var distance = vision_origin.distance_to(target.global_position)
	if distance > npc.max_sight_distance:
		return false
		
	var to_target = (target.global_position - vision_origin)
	to_target.y = 0.0
	to_target = to_target.normalized()
	
	var npc_forward = -npc.global_transform.basis.z
	npc_forward.y = 0.0
	npc_forward = npc_forward.normalized()
	
	var dot_product = npc_forward.dot(to_target)
	var fov_threshold = cos(deg_to_rad(npc.field_of_view / 2.0))
	
	if dot_product < fov_threshold:
		return false
		
	return _has_line_of_sight(vision_origin, target)

func _has_line_of_sight(origin: Vector3, target: CharacterBody3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var target_chest = target.global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(origin, target_chest)
	
	query.exclude = [npc.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	if result:
		return result.collider == target
		
	return false
