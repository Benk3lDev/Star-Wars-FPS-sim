@tool
extends StaticBody3D


@export var item_data : ItemData:
	set(value):
		item_data = value
		if is_inside_tree():
			load_item_model()

var scene_path : String = "res://assets/scenes/items/inventory_item.tscn"

@onready var model_container = $ModelContainer


func _ready():
	load_item_model()


func load_item_model():
	for child in model_container.get_children():
		child.queue_free()
	
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	
	if item_data and item_data.item_model:
		var model_instance = item_data.item_model.instantiate()
		model_container.add_child(model_instance)
		_setup_collisions(model_instance)


func _setup_collisions(node: Node):
	for child in node.get_children():
		if child is CollisionShape3D:
			child.get_parent().remove_child(child)
			add_child(child)
		
			if Engine.is_editor_hint():
				child.owner = get_tree().edited_scene_root
	
		_setup_collisions(child)


func pickup_item():
	if InventoryGlobal.player_node:
		var success = InventoryGlobal.add_item(item_data)
		
		if success:
			self.queue_free()
		else:
			print("Inventory is full or item doesn't fit!")
