class_name WeaponManager extends Node

@export var player: PlayerController

var current_equipped_item: ItemData
var current_slot: int = 1

func _ready() -> void:
	add_to_group("weapon_manager")


func activate_weapon(item: ItemData):
	current_equipped_item = item
	if item:
		print("WeaponManager received: ", item.item_name, " with ammo: ", item.ammo)
	else:
		print("WeaponManager: Hands are now empty.")


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
