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
	if not npc or npc.is_dead or not npc.npc_resource:
		return null

	# Scan for dynamic entities registered in our automated group pool
	var targets = get_tree().get_nodes_in_group("actors")
	var closest_enemy: CharacterBody3D = null
	var closest_distance: float = npc.max_sight_distance 
	
	for target in targets:
		if target == npc:
			continue 
			
		# --- DIAGNOSTIC SENSOR LOGGER ---
		# Safely grab whatever faction this actor has right now
		var discovered_faction = GameManager.Faction.CIVILIAN
		if "npc_resource" in target and target.npc_resource and "faction" in target.npc_resource:
			discovered_faction = target.npc_resource.faction
		elif target.has_method("get") and target.get("faction") != null:
			discovered_faction = target.get("faction")
		elif "faction" in target:
			discovered_faction = target.faction

		if is_entity_visible(target):
			var hostile_match = is_hostile_towards(target)
			print("👁️ [VISION SCAN] Spotted Actor: '", target.name, "' | Faction: ", GameManager.Faction.keys()[discovered_faction], " | Is Hostile? ", hostile_match)
			
			if hostile_match:
				var origin_pos = head_node.global_position if head_node else npc.global_position
				var distance = origin_pos.distance_to(target.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = target
		
	if closest_enemy:
		print("🎯 [SENSOR RESULT] Locked onto closest target: ", closest_enemy.name)
		
	return closest_enemy

func is_hostile_towards(target: Node) -> bool:
	# Ensure our own data is fully valid before proceeding
	if not npc or not npc.npc_resource:
		return false
		
	var my_faction = npc.npc_resource.faction
	var target_faction = GameManager.Faction.CIVILIAN # Pure default fallback
	
	# 1. ROBUST FACTION EXTRACTION: Check if it's an NPC or the Player
	if "npc_resource" in target and target.npc_resource and "faction" in target.npc_resource:
		# It's an NPC, pull the faction from its custom resource data
		target_faction = target.npc_resource.faction
	elif target.has_method("get") and target.get("faction") != null:
		# Safe engine-level look up for the player's script property
		target_faction = target.get("faction")
	elif "faction" in target:
		# Final structural safety fallback
		target_faction = target.faction

	# 2. MATCH YOUR SPECIFIC RELATIONS MATRIX
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
		
	# 1. High-precision proximity checking
	var distance = vision_origin.distance_to(target.global_position)
	if distance > npc.max_sight_distance:
		return false
		
	# 2. Field of View Cone Checking
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
		
	# 3. Raycast Occlusion Checking (Prevents X-Ray Vision through walls)
	return _has_line_of_sight(vision_origin, target)

func _has_line_of_sight(origin: Vector3, target: CharacterBody3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Raycast from our eye sensor position to the target's center chest height (approx +1.0 meter up)
	var target_chest = target.global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(origin, target_chest)
	
	# Exclude the scanning NPC so the raycast doesn't hit its own collision shapes
	query.exclude = [npc.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	if result:
		# If the first physical object our ray hits is the target actor, sight is clear!
		return result.collider == target
		
	return false
