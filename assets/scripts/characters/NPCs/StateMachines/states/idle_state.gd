extends Node

var npc: NPC # Injected by the root controller at _ready

# Connect to: StateChart/Root/Movement/Grounded/Idle -> state_entered()
func _on_idle_state_entered() -> void:
	if is_instance_valid(npc):
		npc.velocity.x = 0
		npc.velocity.z = 0
		npc.anim_prefix = "idle"
		
		# Stand completely still for 3 seconds, then trigger the next set-point march
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(npc) and is_instance_valid(npc.state_chart):
				npc.state_chart.send_event("OnWalk")
		)


func _on_idle_state_physics_processing(delta: float) -> void:
	if not npc or npc.is_dead: return
	
	# Apply gravity if the NPC is in the air
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta
		
	# Process physics and collisions smoothly
	npc.move_and_slide()
