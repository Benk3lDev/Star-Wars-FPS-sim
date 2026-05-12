extends Node


const INVENTORY_ITEM_SCENE = preload("res://assets/scenes/items/inventory_item.tscn")

signal inventory_updated
signal hotbar_updated(index: int, item_data: ItemData)
signal hotbar_selection_changed(index: int, item_data: ItemData)
signal armor_equipped(type: String, item_data: ItemData)
signal armor_unequipped(type: String)

var player : CharacterBody3D
var ui_node : Control
var slot_data : Array[ItemData] = []
var equipped_armor : Dictionary = {}
var hotbar_items : Dictionary = {}
var dimensions : Vector2i = Vector2i(5, 5)
var current_drag_data : ItemData = null
var drag_source : Node = null
var drag_offset : Vector2 = Vector2.ZERO
var original_pickup_coords : Vector2i = Vector2i(-1, -1)
var active_hotbar_index: int = 0

func _ready():
	slot_data.resize(dimensions.x * dimensions.y)
	slot_data.fill(null)


func set_player_reference(player_node: Node) -> void:
	player = player_node


func add_item(item: ItemData) -> bool:
	print("[Inventory Global] Attempting to add item: ", item.item_name if item else null)
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			if check_slot_availability(Vector2i(x, y), item.size):
				insert_item_at_grid_coords(Vector2i(x, y), item)
				print("Item succesfully added at grid position: ", Vector2i(x, y))
				return true
	print("[Inventory Global] Failed to add item.")
	return false


func check_slot_availability(origin: Vector2i, size: Vector2i) -> bool:
	# Ensure the checking size passed from ItemGrid already accounts for rotation 
	# (Our ItemGrid State B code does this automatically)
	for x in range(size.x):
		for y in range(size.y):
			var check_coords = origin + Vector2i(x, y)
			if check_coords.x < 0 or check_coords.x >= dimensions.x or check_coords.y < 0 or check_coords.y >= dimensions.y:
				return false # Out of bounds
			var target_index = check_coords.x + (check_coords.y * dimensions.x)
			if slot_data[target_index] != null:
				return false # Slot occupied
	return true


func insert_item_at_grid_coords(coords: Vector2i, item: ItemData) -> void:
	# Convert 2D layout vectors into your flat 1D array indexes or dictionary mapping keys
	var item_size = item.size
	if item.is_rotated:
		item_size = Vector2i(item_size.y, item_size.x)
		
	# Force override writing to the target cell block maps
	for x in range(item_size.x):
		for y in range(item_size.y):
			var target_cell = coords + Vector2i(x, y)
			var target_index = target_cell.x + (target_cell.y * dimensions.x)
			
			if target_index >= 0 and target_index < slot_data.size():
				slot_data[target_index] = item
				
	# Fire your global updater notification to announce the grid matrix has structurally changed
	inventory_updated.emit()



func update_slot(index: int, new_item: ItemData) -> void:
	slot_data[index] = new_item
	inventory_updated.emit()


func find_item_origin_coords(item: ItemData) -> Vector2i:
	if item == null: return Vector2i(-1, -1)
	
	for i in range(slot_data.size()):
		if slot_data[i] == item:
			return Vector2i(i % dimensions.x, i / dimensions.x)
	
	return Vector2i(-1, -1)


func get_item_at_grid_coords(coords: Vector2i) -> ItemData:
	# Out of bounds guard
	if coords.x < 0 or coords.x >= dimensions.x or coords.y < 0 or coords.y >= dimensions.y:
		return null
		
	var target_index = coords.x + (coords.y * dimensions.x)
	return slot_data[target_index]


func remove_item(item: ItemData) -> void:
	# Mirror the layout size tracking exactly to wipe out every cell cleanly
	var final_size = item.size
	if item.is_rotated:
		final_size = Vector2i(item.size.y, item.size.x)
		
	for i in range(slot_data.size()):
		if slot_data[i] == item:
			slot_data[i] = null
			
	inventory_updated.emit()



func drop_item_into_world(index: int) -> void:
	var item : ItemData = slot_data[index]
	
	if item and player:
		var scene_to_spawn = INVENTORY_ITEM_SCENE
		var item_instance = scene_to_spawn.instantiate() as RigidBody3D
		
		get_tree().root.add_child(item_instance)
		
		
		var drop_offset = -player.global_transform.basis.z * 1.5
		item_instance.global_position = player.global_position + drop_offset
		
		print("Item: ", item.item_name, " dropped into world!")
		update_slot(index, null)


# Registers an item asset reference into a targeted quick-access slot container
func add_item_to_hotbar(index: int, item_data: ItemData) -> void:
	if item_data == null:
		clear_hotbar_slot(index)
		return
		
	# 1. Map the item resource directly to the hotbar index slot
	hotbar_items[index] = item_data
	
	# 2. Flag the object state so your grid dimming/visual mask kicks in
	item_data.is_equipped_now = true
	
	# 3. Broadcast changes globally to refresh the hotbar texture display
	hotbar_updated.emit(index, item_data)
	
	# 4. Refresh the grid canvas if a UI layout is registered
	if ui_node and ui_node.inventory_grid:
		ui_node.inventory_grid.refresh_ui()
		
	print("[InventoryGlobal] Hotbar slot ", index, " assigned to: ", item_data.item_name)


# Clears out data allocations from a targeted hotbar index slot location
func clear_hotbar_slot(index: int) -> void:
	if hotbar_items.has(index):
		var removed_item : ItemData = hotbar_items[index]
		
		# Unflag the object state if it isn't registered in any other weapon/armor slot
		if removed_item:
			removed_item.is_equipped_now = false
			
		hotbar_items.erase(index)
		
	# Broadcast a null footprint payload to clear texture rect displays
	hotbar_updated.emit(index, null)
	print("[InventoryGlobal] Hotbar slot ", index, " completely cleared.")
