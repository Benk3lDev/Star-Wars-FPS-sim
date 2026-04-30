extends Node


var inventory = []
var grid_width : int = 5
var grid_height : int = 5
var slot_size : int = 64

signal inventory_updated
signal request_context_menu(item_data, grid_pos, mouse_pos)

var player_node : Node3D = null

func _ready() -> void:
	grid_width = 5
	grid_height = 5
	inventory.clear()
	for i in range(grid_width * grid_height):
		inventory.append({"is_occupied": false, "item_resource": null})


func get_slot_at(x: int, y: int):
	var index = x + (y * grid_width)
	if index >= 0 and index < inventory.size():
		return inventory[index]
	return null


func is_space_available(x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or y < 0 or (x + w) > grid_width or (y + h) > grid_height:
		return false
	
	for i in range(x, x + w):
		for j in range(y, y + h):
			if i >= grid_width or j >= grid_height: return false
			
			var index = i + (j * grid_width)
			if inventory[index].get("is_occupied", false):
				return false
	return true


func add_item(new_item: ItemData):
	var item_to_process = new_item.duplicate()
	
	if item_to_process.is_stackable:
		for i in range(inventory.size()):
			var slot = inventory[i]
			if slot.get("is_pivot", false):
				var existing_item = slot.item_resource
				if existing_item and existing_item.item_name == new_item.item_name:
					var space_left = existing_item.max_stack_size - existing_item.quantity
					
					if space_left > 0:
						var amount_to_add = min(space_left, item_to_process.quantity)
						existing_item.quantity += amount_to_add
						item_to_process.quantity -= amount_to_add
						
						if item_to_process.quantity <= 0:
							inventory_updated.emit()
							return true
	
	var size = item_to_process.get_size()
	
	for y in range(grid_height - size.y + 1):
		for x in range(grid_width - size.x + 1):
			if is_space_available(x, y, size.x, size.y):
				_fill_grid_slots(x, y, size.x, size.y, item_to_process)
				inventory_updated.emit()
				return true
	item_to_process.is_rotated = !item_to_process.is_rotated
	size = item_to_process.get_size()
	for y in range(grid_height - size.y + 1):
		for x in range(grid_width - size.x + 1):
			if is_space_available(x, y, size.x, size.y):
				_fill_grid_slots(x, y, size.x, size.y, item_to_process)
				inventory_updated.emit()
				return true
	
	print("No space for item!")
	return false


func _fill_grid_slots(x: int, y: int, w: int, h: int, item_data: ItemData):
	
	for j in range(y, y + h):
		for i in range(x, x + w):
			var index = i + (j * grid_width)
			
			if index >= inventory.size(): continue
			
			# Create a NEW dictionary to force the array to update
			var new_slot_data = {
				"is_occupied": true,
				"item_resource": item_data if (i == x and j == y) else null,
				"is_pivot": (i == x and j == y),
				"pivot_gx": x,
				"pivot_gy": y
			}
			
			# Overwrite the index directly
			inventory[index] = new_slot_data


func place_item_at(gx: int, gy: int, new_item: ItemData) -> bool:
	var index = gx + (gy * grid_width)
	var existing_slot = inventory[index]
	
	if existing_slot.item_resource and existing_slot.item_resource.item_name == new_item.item_name:
		if existing_slot.item_resource.stackable:
			var space_left = existing_slot.item_resource.max_stack_size - existing_slot.item_resource.quantity
			if space_left > 0:
				var amount_to_add = min(space_left, new_item.quantity)
				existing_slot.item_resource.quantity += amount_to_add
				inventory_updated.emit()
				return true
	
	var size = new_item.get_size()
	if is_space_available(gx, gy, size.x, size.y):
		_fill_grid_slots(gx, gy, size.x, size.y, new_item)
		inventory_updated.emit()
		return true
	
	return false


func remove_item_at_pos(x: int, y: int):
	var pivot_slot = get_slot_at(x, y)
	if pivot_slot == null or pivot_slot.item_resource == null: return
	
	var data = pivot_slot.item_resource
	var size = data.get_size()
	var w = size.x
	var h = size.y
	
	for i in range(x, x + w):
		for j in range(y, y + h):
			var index = i + (j * grid_width)
			if index < inventory.size():
				inventory[index] = {"is_occupied": false, "item_resource": null, "is_pivot": false}
		inventory_updated.emit()


func set_player_reference(player):
	player_node = player


func drop_item(gx: int, gy: int):
	var slot = get_slot_at(gx, gy)
	if not slot or not slot.item_resource:
		return
	
	var item_data = slot.item_resource
	
	if player_node and item_data.item_model:
		_spawn_item_in_world(item_data)
		
		remove_item_at_pos(gx, gy)
		print("Dropped: ", item_data.item_name)
		
	else:
		print("Cannot drop: Player missing or Item has no scene!")


func _spawn_item_in_world(item_data: ItemData):
	var item_instance = item_data.item_model.instantiate()
	
	get_tree().root.add_child(item_instance)
	
	var cam = get_viewport().get_camera_3d()
	
	if cam:
		var forward_vector = -cam.global_transform.basis.z
		var spawn_pos = cam.global_position + (forward_vector * 2)
		item_instance.global_position = spawn_pos
		
		if item_instance is RigidBody3D:
			var throw_force = 5.0
			item_instance.apply_central_impulse(forward_vector * throw_force)
	
	else:
		item_instance.global_position = player_node.global_position + Vector3(0, 1.5, -1)
