extends RayCast3D

var current_object
var held_object : RigidBody3D = null
var current_carry_data : ObjectData = null
var original_collision_mask : int

@onready var interaction_label = $"../../../Interact_UI/ColorRect/InteractionLabel"
@onready var hold_pos = $"../HoldPos"

func _process(delta: float) -> void:
	if held_object:
		update_held_object(delta)
		
		if Input.is_action_just_pressed("interact"):
			drop_item()
		return
	
	if is_colliding():
		var object = get_collider()
		
		if Input.is_action_just_pressed("interact"):
			if object.has_method("pickup_item"):
				object.pickup_item()
			elif object.has_method("grab_item"):
				current_carry_data = object.grab_item()
				start_carrying(object, current_carry_data)


func start_carrying(obj: RigidBody3D, data: ObjectData):
	held_object = obj
	original_collision_mask = held_object.collision_mask
	current_carry_data = data
	held_object.freeze = true
	held_object.set_collision_layer_value(1, false)


func drop_item():
	if held_object:
		held_object.collision_mask = original_collision_mask
		held_object.freeze = false
		held_object = null
		current_carry_data = null


func update_held_object(delta):
	var target_pos = hold_pos.global_transform.origin
	if current_carry_data:
		target_pos += hold_pos.global_transform.basis * current_carry_data.hold_offset
	
	held_object.global_transform.origin = lerp(held_object.global_transform.origin, target_pos, delta * 20.0)
	held_object.global_rotation = hold_pos.global_rotation
