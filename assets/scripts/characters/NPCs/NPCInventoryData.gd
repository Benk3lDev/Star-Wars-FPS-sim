class_name NPCInventoryData extends Resource


@export var items : Array[Resource] = []

func add_item(item: Resource) -> void:
	if item:
		items.append(item)

func remove_item(item: Resource) -> void:
	if item in items:
		items.erase(item)
