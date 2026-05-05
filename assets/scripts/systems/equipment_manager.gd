extends Node3D

@onready var hand_anchor = $"../HandAnchor"


func _ready():
	InventoryGlobal.hotbar_selection_changed.connect(_on_item_selected)
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)


func _on_hotbar_updated(index: int, item: ItemData):
	if index == InventoryGlobal.active_slot_index:
		if item == null:
			_clear_hands()
		else:
			_update_hand_visuals(item)


func _on_item_selected(_index: int, item: ItemData):
	_update_hand_visuals(item)


func _update_hand_visuals(item: ItemData):
	_clear_hands()
	if item and item.get("item_model"):
		var weapon = item.item_model.instantiate()
		hand_anchor.add_child(weapon)


func _clear_hands():
	for child in hand_anchor.get_children():
		child.queue_free()
