extends RayCast3D

var current_object
var held_object : RigidBody3D = null
var current_carry_data : ObjectData = null
var original_collision_mask : int
var original_collision_layer : int

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
		if not object: return
		
		# --- ROBUS ROOT SCANNER ---
		# If the raycast accidentally strikes a child collision shape or sub-mesh model,
		# climb up the tree to find the actual master BaseObject node script!
		var target_interactable = object
		while target_interactable and not target_interactable.has_method("pickup_item") and not target_interactable.has_method("grab_item"):
			target_interactable = target_interactable.get_parent()
			
		# If we hit a dead end, fall back to the original object
		if not target_interactable:
			target_interactable = object
		# --------------------------
		
		if Input.is_action_just_pressed("interact"):
			if target_interactable.has_method("pickup_item"):
				target_interactable.pickup_item()
			elif target_interactable.has_method("grab_item"):
				current_carry_data = target_interactable.grab_item()
				# Critically pass the resolved root node script into your carry loops!
				start_carrying(target_interactable, current_carry_data)


func start_carrying(obj: RigidBody3D, data: ObjectData):
	held_object = obj
	original_collision_mask = held_object.collision_mask
	original_collision_layer = held_object.collision_layer
	current_carry_data = data
	
	# 1. Turn on physics interpolation freezing so it stops falling
	held_object.freeze = true
	
	# 2. THE MASK FIX: While holding the item, tell it to ONLY look at Layer 1 (Environment)
	# This ensures the item rolls over tables/walls cleanly, but completely bypasses 
	# Layer 2 (Actors), preventing the carried barrel from hitting the player's face mesh.
	held_object.collision_mask = 1 
	
	# 3. Disconnect its presence from Layer 3 so other loose raycasts pass through it
	held_object.set_collision_layer_value(3, false)


func drop_item():
	if held_object:
		# Restore original layout settings cleanly
		held_object.collision_mask = original_collision_mask
		held_object.collision_layer = original_collision_layer
		held_object.freeze = false
		held_object = null
		current_carry_data = null


func update_held_object(delta):
	var target_pos = hold_pos.global_transform.origin
	if current_carry_data:
		target_pos += hold_pos.global_transform.basis * current_carry_data.hold_offset
	
	# High-frequency linear interpolation ensures it glides smoothly to hand positions
	held_object.global_transform.origin = lerp(held_object.global_transform.origin, target_pos, delta * 20.0)
	held_object.global_rotation = hold_pos.global_rotation
