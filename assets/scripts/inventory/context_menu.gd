extends PanelContainer

signal action_selected(action_type: String, item_data: ItemData, slot_pos: Vector2i)

@onready var equip_button = $VBoxContainer/Equip
@onready var unequip_button = $VBoxContainer/Unequip

var current_item : ItemData
var current_slot_pos : Vector2i


func _ready():
	hide()


func open(item: ItemData, slot_pos: Vector2i, mouse_pos: Vector2):
	current_item = item
	current_slot_pos = slot_pos
	global_position = mouse_pos
	
	var is_equipped = InventoryGlobal.equipped_armor.values().has(item)
	
	if item.item_type == "Armor":
		equip_button.visible = not is_equipped
		unequip_button.visible = is_equipped
	else:
		equip_button.hide()
		unequip_button.hide()
	
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
	action_selected.emit("equip", current_item, current_slot_pos)
	hide()

func _on_unequip_pressed() -> void:
	action_selected.emit("unequip", current_item, current_slot_pos)
	hide()


func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(get_global_mouse_position()):
			hide()
