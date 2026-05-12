class_name WeaponManager extends Node

@export var player: PlayerController

var current_equipped_item: ItemData
var current_slot: int = 1

func _ready() -> void:
	add_to_group("weapon_manager")
	InventoryGlobal.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	
	# Fetch initial assignment on spawn frames
	var active_item = InventoryGlobal.hotbar_items.get(InventoryGlobal.active_hotbar_index, null)
	if active_item:
		activate_weapon(active_item)

func _on_hotbar_selection_changed(index: int, item_data: ItemData) -> void:
	current_slot = index + 1 # Convert index 0-4 to slot text 1-5
	activate_weapon(item_data)

func activate_weapon(item: ItemData):
	current_equipped_item = item
	if item:
		var name_check = item.item_name if ("item_name" in item and item.item_name != "") else item.name
		var ammo_check = item.ammo if "ammo" in item else 0
		print("WeaponManager active: ", name_check, " | Ammo: ", ammo_check)
	else:
		print("WeaponManager: Active slot cleared.")

func use_ammo(slot: int, amount: int = 1) -> void:
	if current_equipped_item and "ammo" in current_equipped_item:
		current_equipped_item.ammo = max(0, current_equipped_item.ammo - amount)
		print("Fired! Remaining Ammo: ", current_equipped_item.ammo)
		
		# Force your 2D hotbar slot to redraw its numbers instantly
		var hotbar_index = slot - 1
		InventoryGlobal.hotbar_updated.emit(hotbar_index, current_equipped_item)
		
		# Force the inventory screen grid to update its text counters
		if InventoryGlobal.ui_node and InventoryGlobal.ui_node.inventory_grid:
			InventoryGlobal.ui_node.inventory_grid.refresh_ui()

func has_ammo() -> bool:
	if current_equipped_item:
		return "ammo" in current_equipped_item and current_equipped_item.ammo > 0
	return false

func get_current_ammo(amount: int = 1) -> void:
	if current_equipped_item and current_equipped_item.weapon_stats:
		var stats = current_equipped_item.weapon_stats
		stats.ammo = max(0, stats.ammo - amount)
		
		var hotbar_index = current_slot - 1
		InventoryGlobal.hotbar_updated.emit(hotbar_index, current_equipped_item)
		if InventoryGlobal.ui_node and InventoryGlobal.ui_node.inventory_grid:
			InventoryGlobal.ui_node.inventory_grid.refresh_ui()
