extends RayCast3D

var current_object
@onready var interaction_label = $"../../../Interact_UI/ColorRect/InteractionLabel"

func _process(delta: float) -> void:
	
	if is_colliding():
		var object = get_collider()
		
		if object.has_method("pickup_item"):
			if Input.is_action_pressed("interact"):
				var resource = object.pickup_item()
		
		if object == current_object:
			return
		else:
			current_object = object
	else:
		current_object = null
