class_name NPCBehaviorProfile extends Resource

# Virtual function to be overridden by unique profiles (like hostiles or cowards)
func evaluate_behavior(_npc: NPC, _vision: NPCVisionSensor, _movement_chart: StateChart) -> void:
	pass
