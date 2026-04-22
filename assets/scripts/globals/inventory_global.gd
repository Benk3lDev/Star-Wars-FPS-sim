extends Node


var inventory = []

signal inventory_updated

var player_node : Node3D = null

func _ready() -> void:
	pass


func add_item(item):
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i]["item_type"] == item["item_type"] and inventory[i]["item_effect"] == item["item_effect"]:
			inventory[i]["quantity"] += item["quantity"]
			inventory_updated.emit()
			print("Item added ", inventory)
			return true
		elif inventory[i] == null:
			inventory[i] = item
			inventory_updated.emit()
			print("Item added ", inventory)
			return true
		return false


func remove_item(item_type, item_effect):
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i]["item_type"] == item_type and inventory[i]["item_effect"] == item_effect:
			inventory[i]["quantity"] -= 1
			if inventory[i]["quantity"] <= 0:
				inventory[i] = null
			inventory_updated.emit()
			return true
		return false


func set_player_reference(player):
	player_node = player
