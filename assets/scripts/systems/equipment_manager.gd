extends Node3D

@onready var hand_anchor = $"../HandAnchor"
@export var weapon_controller : WeaponController

var active_muzzle_node : Node3D = null

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
	# Reset muzzle when changing items
	active_muzzle_node = null
	
	if item:
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(item)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(item)
		
		if "hand_pos" in item:
			hand_anchor.position = item.hand_pos
			
			if "weapon_stats" in item and item.weapon_stats and is_instance_valid(weapon_controller):
				weapon_controller.activate_weapon(item.weapon_stats)
			elif is_instance_valid(weapon_controller):
				weapon_controller.deactivate_weapon()
		else:
			hand_anchor.position = Vector3.ZERO
			if is_instance_valid(weapon_controller):
				weapon_controller.deactivate_weapon()
		
		if "item_model" in item and item.item_model:
			var hand_item = item.item_model.instantiate()
			hand_anchor.add_child(hand_item)
			hand_item.transform = Transform3D.IDENTITY
			
			# --- EXTRACT THE ACTIVE MUZZLE HERE ---
			# Look for the Marker3D named "Muzzle" inside the freshly spawned weapon model scene
			active_muzzle_node = hand_item.get_node_or_null("Muzzle")
			print("--- EQUIPMENT MANAGER WEAPON SWAP DEBUG ---")
			print("Spawned Item Mesh Name: ", hand_item.name)
			print("Muzzle Found: ", "YES" if active_muzzle_node else "NO")
			
			if not active_muzzle_node:
				push_warning("EquipmentManager: Spawned weapon model is missing a 'Muzzle' node!")
	else:
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(null)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(null)
			
		if is_instance_valid(weapon_controller):
			weapon_controller.deactivate_weapon()
		hand_anchor.position = Vector3.ZERO


func _clear_hands():
	for child in hand_anchor.get_children():
		child.queue_free()
