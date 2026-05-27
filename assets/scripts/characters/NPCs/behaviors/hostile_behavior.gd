class_name HostileBehavior extends NPCBehaviorProfile

@export_group("Targeting Rules")
@export var lose_target_distance_multiplier: float = 1.3

func evaluate_behavior(npc: NPC, vision: NPCVisionSensor, state_chart: StateChart) -> void:
	var current_target = npc.current_combat_target
	
	# 1. Active Combat Target Verification
	if is_instance_valid(current_target):
		var target_dead = "is_dead" in current_target and current_target.is_dead
		var broke_los = not vision.is_entity_visible(current_target)
		var escaped_distance = _should_lose_target(npc, current_target, vision)
		
		if target_dead or broke_los or escaped_distance:
			npc.current_combat_target = null
			current_target = null

	# 2. Search Scanning Proximity Tick
	if not is_instance_valid(current_target):
		var spotted_enemy = vision.scan_for_enemies()
		if is_instance_valid(spotted_enemy):
			npc.current_combat_target = spotted_enemy
			current_target = spotted_enemy

	# 3. Macro Routing Folder Engine
	if is_instance_valid(current_target):
		# Cache the world coordinates to the NPC root so muscle scripts can read it
		npc.alert_target_position = current_target.global_position
		npc.is_searching_alert_zone = false
		
		if npc.current_macro_state == npc.MacroState.COMBAT: 
			return
			
		if npc.current_macro_state != npc.MacroState.ALERTED:
			state_chart.send_event("OnAlerted")
	else:
		# If we lose the target entirely, we DO NOT force OnAtEase here.
		# We let the internal sub-states finish inspecting the zone first.
		pass

func _should_lose_target(npc: NPC, target: CharacterBody3D, vision: NPCVisionSensor) -> bool:
	var vision_origin: Vector3 = npc.global_position
	if is_instance_valid(vision.head_node):
		vision_origin = vision.head_node.global_position
	var distance = vision_origin.distance_to(target.global_position)
	var max_tracking_dist = npc.max_sight_distance * lose_target_distance_multiplier
	return distance > max_tracking_dist
