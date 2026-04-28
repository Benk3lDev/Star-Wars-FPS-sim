extends Control

@onready var grid_container = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/InventoryContainer/GridContainer
@onready var item_layer = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/InventoryContainer/ItemLayer

@export var slot_scene : PackedScene
@export var dimensions : Vector2i

var grid_array := []
var current_held_item_size : Vector2i
var highlighted_slots: Array = []
var current_hovered_slot
var held_item_data: ItemData = null
var active_preview_node: Control = null

func _ready():
	var total_slots = dimensions.x * dimensions.y
	
	for child in grid_container.get_children():
		child.queue_free()
	
	for i in range(total_slots):
		var x = i % dimensions.x
		var y = i / dimensions.y
		create_slot(x, y)
	
	InventoryGlobal.inventory_updated.connect(refresh_items)
	visibility_changed.connect(_on_visibility_changed)
	
	item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func create_slot(x, y):
	grid_container.columns = dimensions.x

	var new_slot = slot_scene.instantiate()
	grid_container.add_child(new_slot)
	
	new_slot.grid_pos = Vector2i(x, y)
	
	new_slot.slot_entered.connect(_on_slot_mouse_entered)
	new_slot.slot_exited.connect(_on_slot_mouse_exited)


func _on_visibility_changed():
	if is_visible_in_tree():
		await get_tree().process_frame
		refresh_items()


func refresh_items():
	for child in item_layer.get_children():
		child.queue_free()
	
	grid_container.force_update_transform()
	
	await get_tree().process_frame
	
	print("UI: Checking ", InventoryGlobal.inventory.size(), " slots...")
	
	for i in range(InventoryGlobal.inventory.size()):
		var slot_data = InventoryGlobal.inventory[i]
			
		if slot_data.get("is_pivot", false) == true:
			var data = slot_data.get("item_resource")
			print("Found Pivot! Spawning icon for: ", data.item_name)
			spawn_item_icon(i, data)


func spawn_item_icon(slot_index: int, data: ItemData):
	var item_icon = preload("res://assets/scenes/user interface/item_ui.tscn").instantiate()
	item_layer.add_child(item_icon)
	
	item_icon.drag_started.connect(_on_item_drag_started)
	
	item_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	var x = slot_index % InventoryGlobal.grid_width
	var y = slot_index / InventoryGlobal.grid_width
	
	item_icon.item_data = data
	item_icon.grid_pos = Vector2i(x, y)
	
	var target_slot = grid_container.get_child(slot_index)
	while target_slot.position == Vector2.ZERO and slot_index != 0:
		await get_tree().process_frame
	
	item_icon.position = target_slot.position
	
	var slot_size = target_slot.size
	var base_size = Vector2(data.width * slot_size.x, data.height * slot_size.y)
	item_icon.size = base_size
	item_icon.pivot_offset = base_size / 2
	
	if data.is_rotated:
		item_icon.rotation_degrees = 90
		var offset = (base_size.x - base_size.y) / 2
		item_icon.position += Vector2(-offset, offset)
	else:
		item_icon.rotation_degrees = 0
		
	item_icon.texture = data.icon
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.update_visuals()


func get_slots_in_range(start_pos: Vector2i, size: Vector2i) -> Array:
	var affected_slots = []
	for y in range(start_pos.y, start_pos.y + size.y):
		for x in range(start_pos.x, start_pos.x + size.x):
			var index = x + (y * dimensions.x)
			
			if x >= 0 and x < dimensions.x and y >= 0 and y < dimensions.y:
				affected_slots.append(grid_container.get_child(index))
	return affected_slots


func _on_slot_mouse_entered(a_Slot):
	_clear_highlights()
	
	highlighted_slots = get_slots_in_range(a_Slot.grid_pos, current_held_item_size)
	var fits = highlighted_slots.size() == (current_held_item_size.x * current_held_item_size.y)
	current_hovered_slot = a_Slot
	if held_item_data:
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


func _on_item_drag_started(data, preview_node):
	held_item_data = data
	current_held_item_size = data.get_size()
	active_preview_node = preview_node


func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		held_item_data = null
		active_preview_node = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("item_rotate") and held_item_data:
		held_item_data.is_rotated = !held_item_data.is_rotated
		current_held_item_size = held_item_data.get_size()
		
		_update_drag_preview()
		
		if current_hovered_slot:
			_on_slot_mouse_entered(current_hovered_slot)
		
		get_viewport().set_input_as_handled()
		print("Rotated ", held_item_data.item_name)


func _update_drag_preview():
	print("Preview rotation: ", active_preview_node.rotation_degrees)
	if active_preview_node:
		var icon = active_preview_node.find_child("*", true, false)
		if icon is TextureRect:
			var slot_size = grid_container.get_child(0).size
			var base_pixel_size = Vector2(held_item_data.width * slot_size.x, held_item_data.height * slot_size.y)
		
			icon.custom_minimum_size = base_pixel_size
			icon.size = base_pixel_size
			
			icon.pivot_offset = base_pixel_size / 2
		
			if held_item_data.is_rotated:
				icon.rotation_degrees = 90
				var offset = (base_pixel_size.x -base_pixel_size.y) / 2
				icon.position = Vector2(-offset, offset)
			else:
				icon.rotation_degrees = 0
				icon.position = Vector2.ZERO
			
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			
			icon.queue_redraw()
		else:
			print("Error: Could not find TextureRect in preview handle!")
