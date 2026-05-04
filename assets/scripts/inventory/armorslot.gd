extends "res://assets/scripts/inventory/slot.gd"

@export_enum("Head", "Chest", "Belt1", "Belt2", "Backpack") var slot_type: String

@onready var icon_display = $Icon


func _ready():
	InventoryGlobal.armor_equipped.connect(_on_armor_equipped)
	InventoryGlobal.armor_unequipped.connect(_on_armor_unequipped)


func can_recieve_item(item_data) -> bool:
	return item_data.item_type == slot_type


func _can_drop_data(at_position, data) -> bool:
	var item_resource = data.get("item_data")
	if not item_resource:
		return false
	return item_resource.item_type == slot_type


func _drop_data(at_position, data):
	var item_resource = data.get("item_data")
	equip_item_visually(item_resource)


func equip_item_visually(item_resource):
	item_stored = item_resource
	icon_display.texture = item_resource.hotbar_icon


func _on_armor_equipped(type: String, item_data: ItemData):
	if type == slot_type:
		var icon_node = get_node_or_null("Icon")
		
		if icon_node:
			icon_node.texture = item_data.hotbar_icon
			icon_node.show()
		else:
			texture = item_data.hotbar_icon


func _on_armor_unequipped(type: String):
	if type == slot_type:
		icon_display.texture = null
