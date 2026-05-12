class_name InventoryUI extends Control

@onready var item_layer = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/InventoryContainer/ItemLayer
@onready var context_menu = $ContextMenu
@onready var details_panel = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/ItemDetailsContainer/DetailsPanel
@onready var details_texture = %Texture
@onready var name_label = %NameLabel
@onready var desc_label = %DescLabel

@export var inventory_grid : ItemGrid

var grid_array := []
var current_held_item_size : Vector2i
var highlighted_slots: Array = []
var current_hovered_slot
var held_item_data: ItemData = null
var active_preview_node: Control = null
var last_original_pos : Vector2i
var original_rotation : bool

func _ready() -> void:
	InventoryGlobal.ui_node = self
	context_menu.action_selected.connect(_on_context_menu_action)
	
	# Connect the grid's right-click signal to your existing menu request function
	if inventory_grid:
		inventory_grid.context_menu_requested.connect(_on_context_menu_requested)


func _on_context_menu_requested(item: ItemData, pivot_pos: Vector2i, mouse_pos: Vector2):
	context_menu.open(item, pivot_pos, mouse_pos)



func _on_context_menu_action(action_type: String, item_data: ItemData, slot_pos: Vector2i) -> void:
	match action_type:
		"drop":
			if item_data == null: return
			print("Dropping item: ", item_data.item_name, " from ", slot_pos)
			
			# 1. Convert the 2D coordinate positions back into a flat 1D array index
			var grid_width = InventoryGlobal.dimensions.x
			var flat_array_index : int = slot_pos.x + (slot_pos.y * grid_width)
			
			# 2. Call your existing drop function to spawn the RigidBody3D scene actor
			if has_method("drop_item_into_world"):
				InventoryGlobal.drop_item_into_world(flat_array_index)
			elif InventoryGlobal.has_method("drop_item_into_world"):
				InventoryGlobal.drop_item_into_world(flat_array_index)
				
			# 3. Simultaneously execute the temporary/persistent data cleanup method.
			# This clears out mirroring registrations from your 10 hotbar slots
			# and turns off 'is_equipped_now' status values.
			if InventoryGlobal.has_method("remove_item"):
				InventoryGlobal.remove_item(item_data)
				
			# 4. Force the UI grid layout container to redraw its slots cleanly
			if inventory_grid:
				inventory_grid.refresh_ui()
			
		"equip":
			# FIX: Changed item_data.resource_name to item_data.name
			print("Equipping armor item piece: ", item_data.item_name)
			
			var raw_slot_type : String = str(item_data.armor_type)
			var target_slot_type : String = raw_slot_type
			if raw_slot_type == "Belt":
				if not InventoryGlobal.equipped_armor.has("Belt1"):
					target_slot_type = "Belt1"
				elif not InventoryGlobal.equipped_armor.has("Belt2"):
					target_slot_type = "Belt2"
				else:
					target_slot_type = "Belt1"
			
			InventoryGlobal.equipped_armor[target_slot_type] = item_data
			item_data.is_equipped_now = true
			InventoryGlobal.armor_equipped.emit(target_slot_type, item_data)
			
		"unequip":
			# FIX: Changed item_data.resource_name to item_data.name
			print("Unequipping armor item piece: ", item_data.item_name)
			
			var target_slot_type : String = ""
			for slot_key in InventoryGlobal.equipped_armor.keys():
				if InventoryGlobal.equipped_armor[slot_key] == item_data:
					target_slot_type = slot_key
					break
			
			if target_slot_type != "":
				InventoryGlobal.equipped_armor.erase(target_slot_type)
				item_data.is_equipped_now = false
				InventoryGlobal.armor_unequipped.emit(target_slot_type)
			else:
				print("Could not find this item in the equipped armor dictionary!")
			
			if inventory_grid:
				inventory_grid.refresh_ui()
