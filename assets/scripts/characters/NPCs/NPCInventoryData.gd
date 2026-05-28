class_name NPCInventoryData extends Resource

## The active item configuration slots populated in the Godot inspector
@export var slots : Array[ItemData] = []

## Searches the slot collection and returns the first item containing weapon metrics
func get_first_weapon_item() -> ItemData:
	for item in slots:
		# Safety check: Ensure the slot isn't empty in the inspector array
		if is_instance_valid(item):
			# String validation matching "Weapon" exactly as specified in your item_type enum property
			if item.item_type == "Weapon" or item.item_type == "WEAPON":
				# Ensure the nested weapon statistics block actually exists inside it
				if item.weapon_stats != null:
					return item
				
	return null

## Adds an item safely to the active slots collection array
func add_item(item: ItemData) -> void:
	if is_instance_valid(item):
		slots.append(item)

## Removes an item safely from the active slots collection array
func remove_item(item: ItemData) -> void:
	if item in slots:
		slots.erase(item)
