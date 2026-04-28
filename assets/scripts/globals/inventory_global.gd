extends Node


var inventory = []
var grid_width : int
var grid_height : int

signal inventory_updated

var player_node : Node3D = null

func _ready() -> void:
	grid_width = 5
	grid_height = 6
	_initialize_inventory()


func _initialize_inventory():
	inventory.clear()
	for i in range(grid_width * grid_height):
		inventory.append({"is_occupied": false, "item_resource": null})


func get_slot_at(x: int, y: int):
	var index = x +(y * grid_width)
	if index >= 0 and index < inventory.size():
		return inventory[index]
	return null


func is_space_available(x: int, y: int, w: int, h: int) -> bool:
	for i in range(x, x + w):
		for j in range(y, y + h):
			if i >= grid_width or j >= grid_height: return false
			
			var index = i + (j * grid_width)
			if inventory[index].get("is_occupied", false):
				return false
	return true


func add_item(item_data: ItemData):
	var w = item_data.width
	var h = item_data.height
	
	for y in range(grid_height - h + 1):
		for x in range(grid_width - w + 1):
			if is_space_available(x, y, w, h):
				_fill_grid_slots(x, y, w, h, item_data)
				print("Placed ", item_data.item_name, " at ", x, ", ", y)
				inventory_updated.emit()
				return true
		print("No space for item!")
	return false


func _fill_grid_slots(x: int, y: int, w: int, h: int, item_data):
	for i in range(x, x + w):
		for j in range(y, y + h):
			var index = i + (j * grid_width)
			
			if index >= inventory.size(): continue
			
			# Create a NEW dictionary to force the array to update
			var new_slot_data = {
				"is_occupied": true,
				"item_resource": item_data if (i == x and j == y) else null,
				"is_pivot": (i == x and j == y)
			}
			
			# Overwrite the index directly
			inventory[index] = new_slot_data


func place_item_at(x: int, y: int, data: ItemData):
	var w = data.height if data.is_rotated else data.width
	var h = data.width if data.is_rotated else data.height
	
	_fill_grid_slots(x, y, w, h, data)
	inventory_updated.emit()


func remove_item_at_pos(x: int, y: int):
	var pivot_slot = get_slot_at(x, y)
	if pivot_slot == null or pivot_slot.item_resource == null: return
	
	var data = pivot_slot.item_resource
	var w = data.get("width", 1)
	var h = data.get("height", 1)
	
	for i in range(x, x + w):
		for j in range(y, y + h):
			var index = i + (j * grid_width)
			inventory[index] = {"is_occupied": false}
		inventory_updated.emit()


func set_player_reference(player):
	player_node = player
