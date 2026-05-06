@tool
class_name BaseObject extends RigidBody3D


@export var object_data : ObjectData:
	set(value):
		object_data = value
		if is_inside_tree():
			load_item_model()

@onready var model_container = $ModelContainer


func _ready():
	if object_data:
		load_item_model()


func load_item_model():
	if not model_container:
		return
	
	for child in model_container.get_children():
		child.queue_free()
	
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	
	if object_data and object_data.item_model:
		var model_instance = object_data.item_model.instantiate()
		model_container.add_child(model_instance)
		_setup_collisions(model_instance)


func _setup_collisions(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D:
			var col_shape_node = CollisionShape3D.new()
			col_shape_node.shape = child.mesh.create_convex_shape()
			add_child(col_shape_node)
			
			col_shape_node.transform = child.transform
			
			if Engine.is_editor_hint():
				col_shape_node.owner = get_tree().edited_scene_root
		
		_setup_collisions(child)


func grab_item() -> ObjectData:
	return object_data
