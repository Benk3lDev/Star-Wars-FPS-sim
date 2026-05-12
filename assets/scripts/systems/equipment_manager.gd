extends Node3D

@onready var hand_anchor = $"../HandAnchor"
@export var weapon_controller : WeaponController

func _ready():
	# Connects cleanly to our unified input broadcasting signals
	InventoryGlobal.hotbar_selection_changed.connect(_on_item_selected)
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)

func _on_hotbar_updated(index: int, item: ItemData):
	if index == InventoryGlobal.active_hotbar_index:
		_update_active_item(item)

func _on_item_selected(_index: int, item: ItemData):
	_update_active_item(item)

func _update_active_item(item: ItemData):
	_clear_hands()
	
	if item:
		# 1. Update the logical weapon manager stats first
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(item)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(item)
		
		# 2. Adjust physical position offsets based on weapon stats
		if item.weapon_stats and "weapon_position" in item.weapon_stats:
			hand_anchor.position = item.weapon_stats.weapon_position
			
			if is_instance_valid(weapon_controller):
				weapon_controller.activate_weapon(item.weapon_stats)
		else:
			hand_anchor.position = Vector3.ZERO
		
		# 3. Instantiate and bind the 3D model asset onto the hand anchor
		if "item_model" in item and item.item_model:
			var weapon = item.item_model.instantiate()
			hand_anchor.add_child(weapon)
			weapon.transform = Transform3D.IDENTITY
	else:
		# Safety fallback: clear hands if an empty slot is selected
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(null)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(null)
			
		if is_instance_valid(weapon_controller):
			weapon_controller.deactivate_weapon()

func _clear_hands():
	for child in hand_anchor.get_children():
		child.queue_free()
