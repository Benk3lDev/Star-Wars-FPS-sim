class_name WeaponManager extends Node

@export var player: PlayerController

var current_equipped_item: ItemData
var current_slot: int = 1

func _ready() -> void:
	add_to_group("weapon_manager")
	
	# --- CONNECT THE GLOBAL HOTBAR SIGNAL ENGINE ---
	InventoryGlobal.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	
	# Fetch initial assignment on spawn boot frames if items are already pre-loaded
	var active_item = InventoryGlobal.hotbar_items.get(InventoryGlobal.active_hotbar_index, null)
	if active_item:
		activate_weapon(active_item)


## Intermediate listener that catches hotbar switching events
func _on_hotbar_selection_changed(index: int, item_data: ItemData) -> void:
	current_slot = index + 1 # Convert 0-4 code array index back to gameplay slots 1-5
	
	# Safely pass the active item payload straight to your existing code block
	activate_weapon(item_data)


func activate_weapon(item: ItemData):
	current_equipped_item = item
	if item:
		# Use fallback lookup parameter strings if .item_name is ever empty
		var name_check = item.item_name if "item_name" in item and item.item_name != "" else item.name
		print("WeaponManager received: ", name_check, " with ammo: ", item.ammo)
		
		# Put your physical 3D mesh instantiating/enabling model switches here!
	else:
		print("WeaponManager: Hands are now empty.")
		# Turn off visibilities of any visual weapons currently held in hand models


func use_ammo(slot: int, amount: int = 1) -> void:
	if current_equipped_item:
		current_equipped_item.ammo = max(0, current_equipped_item.ammo - amount)
		print("Fired! Remaining Ammo: ", current_equipped_item.ammo)

func has_ammo() -> bool:
	if current_equipped_item and current_equipped_item.weapon_stats:
		return current_equipped_item.ammo > 0
	return false

func get_current_ammo(amount: int = 1) -> void:
	if current_equipped_item and current_equipped_item.weapon_stats:
		var stats = current_equipped_item.weapon_stats
		stats.ammo = max(0, stats.ammo - amount)
		print("Fired! ", stats.weapon_name, " Ammo: ", stats.ammo)
