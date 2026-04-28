extends Control

@onready var grid_container = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/Control/GridContainer
@onready var item_layer = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/Control/ItemLayer

@export var slot_scene : PackedScene
@export var dimensions : Vector2i

var grid_array := []
var current_held_item_size = Vector2i(2, 2)
var highlighted_slots: Array = []
var current_hovered_slot

func _ready():
	InventoryGlobal.grid_width = dimensions.x
	InventoryGlobal.grid_height = dimensions.y
	
	InventoryGlobal.inventory.clear()
	for i in range(dimensions.x * dimensions.y):
		var x = i % dimensions.x
		var y = i / dimensions.y
		InventoryGlobal.inventory.append({"is_occupied": false, "item_resource": null})
		create_slot(x, y)
	
	InventoryGlobal.inventory_updated.connect(refresh_items)
		
	item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func create_slot(x, y):
	grid_container.columns = dimensions.x

	var new_slot = slot_scene.instantiate()
	grid_container.add_child(new_slot)
	
	new_slot.grid_pos = Vector2i(x, y)
	
	new_slot.slot_entered.connect(_on_slot_mouse_entered)
	new_slot.slot_exited.connect(_on_slot_mouse_exited)


func refresh_items():
	print("UI: Checking ", InventoryGlobal.inventory.size(), " slots...")
	
	for i in range(InventoryGlobal.inventory.size()):
		var slot_data = InventoryGlobal.inventory[i]
		
		# If it's a dictionary, let's see what's inside if it's occupied
		if slot_data.get("is_occupied", false):
			print("Slot ", i, " is occupied. Is pivot? ", slot_data.get("is_pivot"))
			
			if slot_data.get("is_pivot", false) == true:
				var data = slot_data.get("item_resource")
				print("Found Pivot! Spawning icon for: ", data.item_name)
				spawn_item_icon(i, data)


func spawn_item_icon(slot_index: int, data: ItemData):
	var item_icon = preload("res://assets/scenes/user interface/item_ui.tscn").instantiate()
	item_layer.add_child(item_icon)
	
	item_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	var target_slot = grid_container.get_child(slot_index)
	if target_slot.size.x <= 5:
		await get_tree().process_frame
	
	item_icon.global_position = target_slot.global_position
	
	var slot_size = target_slot.size
	var icon_width = data.width * slot_size.x
	var icon_height = data.height * slot_size.x
	
	item_icon.custom_minimum_size = Vector2(icon_width, icon_height)
	item_icon.texture = data.icon
	item_icon.size = item_icon.custom_minimum_size
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_SCALE
	item_icon.update_visuals()


func get_slots_in_range(start_pos: Vector2i, size: Vector2i) -> Array:
	var affected_slots = []
	for x in range(start_pos.x, start_pos.x + size.x):
		for y in range(start_pos.y, start_pos.y + size.y):
			var index = x + (y * dimensions.x)
			
			if x >= 0 and x < dimensions.x and y >= 0 and y < dimensions.y:
				affected_slots.append(grid_container.get_child(index))
	return affected_slots


func _on_slot_mouse_entered(a_Slot):
	_clear_highlights()
	
	highlighted_slots = get_slots_in_range(a_Slot.grid_pos, current_held_item_size)
	var fits = highlighted_slots.size() == (current_held_item_size.x * current_held_item_size.y)
	current_hovered_slot == a_Slot
	for slot in highlighted_slots:
		if fits:
			slot.set_color(a_Slot.States.FREE)
		else:
			slot.set_color(a_Slot.States.TAKEN)


func _on_slot_mouse_exited(a_Slot):
	if current_hovered_slot == a_Slot:
		_clear_highlights()
		current_hovered_slot = null


func _clear_highlights():
	for slot in highlighted_slots:
		if is_instance_valid(slot):
			slot.set_color(slot.States.DEFAULT)
	highlighted_slots.clear()
