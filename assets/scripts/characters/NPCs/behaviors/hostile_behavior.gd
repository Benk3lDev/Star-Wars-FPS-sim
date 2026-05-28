class_name HostileBehavior extends NPCBehaviorProfile

@export_group("Targeting Rules")
@export var lose_target_distance_multiplier: float = 1.3
@export var alert_to_combat_time: float = 5.0

@export_group("Stealth & Disguise Scales")
## The absolute closest a player can get before a disguise is completely blown
@export var min_disguise_fail_distance: float = 2.0
## The absolute maximum range an NPC can spot someone not wearing a disguise
@export var max_base_spot_distance: float = 25.0

# Dynamic timing tracking variables
var alert_escalation_timer: float = 0.0

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

	# 2. Advanced Multi-Layer Detection Scanning Proximity Tick
	if not is_instance_valid(current_target):
		alert_escalation_timer = 0.0 # Reset tracking loop delay if target breaks sightlines
		
		# Pull dynamic entities registered in our automated group pool from the vision sensor
		var potential_targets = vision.get_tree().get_nodes_in_group("actors") if is_instance_valid(vision) else []
		
		for body in potential_targets:
			if body == npc:
				continue
				
			if "is_dead" in body and body.is_dead:
				continue
					
			# Check physical Line of Sight visibility from the sensor node first
			if vision.is_entity_visible(body):
				if _evaluate_stealth_and_disguise(npc, body):
					npc.current_combat_target = body
					current_target = body
					break # Lock focus onto the first valid threat found this frame

	# 3. Macro Routing Folder Engine (Governs high-level compound folders ONLY)
	if is_instance_valid(current_target):
		npc.alert_target_position = current_target.global_position
		npc.is_searching_alert_zone = false
		
		# Scenario A: Already escalated to full Combat, let sub-states run their muscle logic
		if npc.current_macro_state == npc.MacroState.COMBAT: 
			return
			
		# Scenario B: Currently Alerted, check the 5-second continuous visibility threshold
		if npc.current_macro_state == npc.MacroState.ALERTED:
			var frame_delta = npc.get_process_delta_time()
			alert_escalation_timer += frame_delta
			
			if alert_escalation_timer >= alert_to_combat_time:
				print("🔥 [BRAIN] 5 seconds of sustained detection met! Escalating to Combat folder.")
				state_chart.send_event("OnCombat")
		else:
			# Scenario C: AtEase, initial prompt entry transition down into the Alerted folder structure
			alert_escalation_timer = 0.0
			state_chart.send_event("OnAlerted")
	else:
		# No active target visible: Let the sub-state muscle scripts run the show (Search, etc.)
		pass


## LAYERED DETECTION EVALUATION
## Returns true if the NPC successfully uncovers the target as an active enemy threat
func _evaluate_stealth_and_disguise(npc: NPC, target: Node3D) -> bool:
	var distance = npc.global_position.distance_to(target.global_position)
	
	# Fetch the target's stealth skill out of their dictionary setup using attributes calculation
	var target_stealth: float = 0.0
	if target.has_node("Components/SkillsComponent") and target.has_node("Components/AttributesComponent"):
		var target_skills = target.get_node("Components/SkillsComponent")
		var target_attrs = target.get_node("Components/AttributesComponent").character_attributes
		
		if "skills" in target_skills and target_skills.skills.has("stealth_skill") and target_attrs != null:
			# Extraction fix: Grab the SkillData resource object from the map container, 
			# and run its custom total calculation equation using the target's attributes!
			var skill_resource = target_skills.skills["stealth_skill"]
			if skill_resource and skill_resource.has_method("get_total_value"):
				target_stealth = float(skill_resource.get_total_value(target_attrs))

	# Unpack unified variables straight from the CharacterBody3D root scopes!
	var npc_uniform = npc.faction
	var npc_true_faction = npc.true_faction
	
	var target_uniform = target.faction if "faction" in target else GameManager.Faction.CIVILIAN
	var target_true_faction = target.true_faction if "true_faction" in target else GameManager.Faction.CIVILIAN

	# LIVE CONSOLE DIAGNOSTIC LOGGER: Kept active to track exact frame data
	print("🔍 AI SCANNING: Dist: ", distance, " | NPC Uni: ", npc_uniform, " | Target Uni: ", target_uniform)

	# -----------------------------------------------------------------
	# DETECTION SCENARIO A: Target is disguised as the NPC's ally
	# (Their uniform matches the NPC, but their true allegiance is an enemy)
	# -----------------------------------------------------------------
	if target_uniform == npc_uniform and target_true_faction != npc_true_faction:
		# See through the disguise based on distance and stealth skill.
		# A higher stealth skill heavily shrinks the failure zone radius down.
		var stealth_disguise_modifier = remap(clamp(target_stealth, 0.0, 100.0), 0.0, 100.0, 8.0, 0.0)
		var dynamic_see_through_radius = min_disguise_fail_distance + stealth_disguise_modifier
		
		if distance <= dynamic_see_through_radius:
			print("🚨 [DISGUISE BLOWN] NPC saw through uniform at close proximity distance: ", distance)
			return true # Disguise failed, target detected!
			
		return false # Disguise holds, NPC passes them by neutral

	# -----------------------------------------------------------------
	# DETECTION SCENARIO B: Target is wearing an enemy uniform 
	# (No armor equipped / Mismatched Faction)
	# -----------------------------------------------------------------
	if target_uniform != npc_uniform:
		# Shrink open-sightline visibility range if target has high stealth attributes
		var stealth_visibility_reduction = remap(clamp(target_stealth, 0.0, 100.0), 0.0, 100.0, 1.0, 0.4)
		var final_detection_cutoff = max_base_spot_distance * stealth_visibility_reduction
		
		if distance <= final_detection_cutoff:
			print("👁️ [SPOTTED] Enemy uniform identified inside range cutoff threshold: ", distance)
			return true # Target detected!

	return false


func _should_lose_target(npc: NPC, target: CharacterBody3D, vision: NPCVisionSensor) -> bool:
	var vision_origin: Vector3 = npc.global_position
	if is_instance_valid(vision.head_node):
		vision_origin = vision.head_node.global_position
		
	var distance = vision_origin.distance_to(target.global_position)
	var max_tracking_dist = npc.max_sight_distance * lose_target_distance_multiplier
	return distance > max_tracking_dist
