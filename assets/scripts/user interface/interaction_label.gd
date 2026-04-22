extends Label

@onready var interaction_raycast = $"../../../CameraController/Camera3D/InteractionRaycast"

func _process(delta: float) -> void:
	if interaction_raycast.is_colliding():
		var collider = interaction_raycast.get_collider()
		
		if "item_data" in collider and collider.item_data != null:
			text = collider.item_data.item_name
		else:
			text = ""
	else:
		text = ""
