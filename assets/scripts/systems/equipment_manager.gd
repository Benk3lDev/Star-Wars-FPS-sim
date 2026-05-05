extends Node3D

@onready var hand_anchor = $"../HandAnchor"
@export var weapon_controller : WeaponController



func _ready():
	InventoryGlobal.hotbar_selection_changed.connect(_on_item_selected)
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)


func _on_hotbar_updated(index: int, item: ItemData):
	if index == InventoryGlobal.active_slot_index:
		_update_active_item(item)


func _on_item_selected(_index: int, item: ItemData):
	_update_active_item(item)


func _update_active_item(item: ItemData):
	_clear_hands()
	
	if item:
		if Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(item)
		
		if item.weapon_stats and "weapon_position" in item.weapon_stats:
			hand_anchor.position = item.weapon_stats.weapon_position
			weapon_controller.activate_weapon(item.weapon_stats)
		else:
			hand_anchor.position = Vector3.ZERO
		
		if item.item_model:
			var weapon = item.item_model.instantiate()
			hand_anchor.add_child(weapon)
	
	else:
		Managers.weapon_manager.activate_weapon(null)
		weapon_controller.deactivate_weapon()


func _clear_hands():
	for child in hand_anchor.get_children():
		child.queue_free()
