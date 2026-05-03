extends PanelContainer

signal action_selected(action_type: String, item_data: ItemData, slot_pos: Vector2i)


var current_item : ItemData
var current_slot_pos : Vector2i


func _ready():
	hide()


func open(item: ItemData, slot_pos: Vector2i, mouse_pos: Vector2):
	current_item = item
	current_slot_pos = slot_pos
	global_position = mouse_pos
	
	global_position += Vector2(5, 5)
	
	show()


func _on_drop_pressed() -> void:
	action_selected.emit("drop", current_item, current_slot_pos)
	hide()


func _on_use_pressed():
	print("use")
	#action_selected.emit("use", current_item, current_slot_pos)
	hide()


func _on_equip_pressed():
	print("equip")
	#action_selected.emit("equip", current_item, current_slot_pos)
	hide()


func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(get_global_mouse_position()):
			hide()
