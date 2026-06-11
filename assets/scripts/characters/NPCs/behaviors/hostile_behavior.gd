class_name HostileBehavior extends NPCBehaviorProfile

@export_group("Targeting Rules")
@export var lose_target_distance_multiplier: float = 1.3
@export var alert_to_combat_time: float = 1.5

@export_group("Stealth & Disguise Scales")
@export var min_disguise_fail_distance: float = 5.0
@export var max_base_spot_distance: float = 25.0

var alert_escalation_timer: float = 0.0
var combat_grace_timer: float = 0.0
const COMBAT_MEMORY_TIME: float = 2.0

func evaluate_behavior(npc: NPC, vision: NPCVisionSensor, state_chart: StateChart) -> void:
	var current_target = npc.current_combat_target
	var frame_delta = npc.get_process_delta_time()
	
	if is_instance_valid(current_target):
		var target_dead = "is_dead" in current_target and current_target.is_dead
		var broke_los = not vision.is_entity_visible(current_target)
		var escaped_distance = _should_lose_target(npc, current_target, vision)
		
		if npc.current_macro_state == npc.MacroState.COMBAT and broke_los and not target_dead and not escaped_distance:
			combat_grace_timer += frame_delta
			if combat_grace_timer >= COMBAT_MEMORY_TIME:
				npc.current_combat_target = null
				current_target = null
		elif not broke_los:
			combat_grace_timer = 0.0
			
		if target_dead or escaped_distance:
			npc.current_combat_target = null
			current_target = null

	if not is_instance_valid(current_target):
		alert_escalation_timer = 0.0
		combat_grace_timer = 0.0
		
		var potential_targets = vision.get_tree().get_nodes_in_group("actors") if is_instance_valid(vision) else []
		for body in potential_targets:
			if body == npc or ("is_dead" in body and body.is_dead): continue
			if vision.is_entity_visible(body):
				if _evaluate_stealth_and_disguise(npc, body):
					npc.current_combat_target = body
					current_target = body
					
					# Report up the chain of command
					var squad_comp = npc.get_node_or_null("SquadComponent")
					if not squad_comp:
						squad_comp = npc.get_node_or_null("Components/SquadComponent")
					if squad_comp:
						var active_leader = squad_comp.get_active_commander()
						if is_instance_valid(active_leader) and active_leader != npc:
							if active_leader.has_method("receive_trooper_tactical_report"):
								active_leader.receive_trooper_tactical_report(body)
					break

	if is_instance_valid(current_target):
		npc.alert_target_position = current_target.global_position
		npc.is_searching_alert_zone = false
		
		var squad_comp = npc.get_node_or_null("SquadComponent")
		if not squad_comp:
			squad_comp = npc.get_node_or_null("Components/SquadComponent")
			
		if squad_comp and squad_comp.character_rank == squad_comp.Rank.SERGEANT and npc.current_macro_state == npc.MacroState.COMBAT:
			if not squad_comp.has_called_for_help and squad_comp.evaluate_squad_wipe_threshold():
				var lieutenant = squad_comp.commanding_lieutenant
				if is_instance_valid(lieutenant) and not lieutenant.is_dead:
					squad_comp.has_called_for_help = true
					if lieutenant.has_method("receive_sergeant_distress_call"):
						lieutenant.receive_sergeant_distress_call(current_target)

		if npc.current_macro_state == npc.MacroState.COMBAT: 
			return
			
		if npc.current_macro_state == npc.MacroState.ALERTED:
			alert_escalation_timer += frame_delta
			if alert_escalation_timer >= alert_to_combat_time:
				state_chart.send_event("OnCombat")
		else:
			alert_escalation_timer = 0.0
			state_chart.send_event("OnAlerted")
	else:
		if npc.current_macro_state == npc.MacroState.COMBAT:
			state_chart.send_event("OnAlerted")

func _evaluate_stealth_and_disguise(npc: NPC, target: Node3D) -> bool:
	var distance = npc.global_position.distance_to(target.global_position)
	var target_stealth: float = 0.0
	
	var target_skills = target.get_node_or_null("SkillsComponent")
	if not target_skills: target_skills = target.get_node_or_null("Components/SkillsComponent")
	var target_attrs = target.get_node_or_null("AttributesComponent")
	if not target_attrs: target_attrs = target.get_node_or_null("Components/AttributesComponent")
	
	if target_skills and target_attrs and target_attrs.character_attributes != null:
		if "skills" in target_skills and target_skills.skills.has("stealth_skill"):
			var skill_resource = target_skills.skills["stealth_skill"]
			if skill_resource and skill_resource.has_method("get_total_value"):
				target_stealth = float(skill_resource.get_total_value(target_attrs.character_attributes))

	var npc_uniform = npc.faction
	var target_uniform = target.faction if "faction" in target else GameManager.Faction.CIVILIAN
	var target_true_faction = target.true_faction if "true_faction" in target else GameManager.Faction.CIVILIAN

	if target_uniform == npc_uniform and target_true_faction != npc.true_faction:
		var stealth_disguise_modifier = remap(clamp(target_stealth, 0.0, 100.0), 0.0, 100.0, 8.0, 0.0)
		return distance <= (min_disguise_fail_distance + stealth_disguise_modifier)

	if target_uniform != npc_uniform:
		var stealth_visibility_reduction = remap(clamp(target_stealth, 0.0, 100.0), 0.0, 100.0, 1.0, 0.4)
		return distance <= (max_base_spot_distance * stealth_visibility_reduction)

	return false

func _should_lose_target(npc: NPC, target: CharacterBody3D, vision: NPCVisionSensor) -> bool:
	var max_tracking_dist = max_base_spot_distance * lose_target_distance_multiplier
	return npc.global_position.distance_to(target.global_position) > max_tracking_dist
