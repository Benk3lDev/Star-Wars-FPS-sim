extends TextureRect

@export var slot_index: int

@onready var icon_display = %Icon

func _ready():
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)
	custom_minimum_size = Vector2(InventoryGlobal.slot_size, InventoryGlobal.slot_size)


func _get_drag_data(at_position):
	var item = InventoryGlobal.hotbar_items.get(slot_index)
	if not item:
		return null
	
	var preview = TextureRect.new()
	preview.texture = item.hotbar_icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(60, 60)
	set_drag_preview(preview)
	
	return {
		"item_data": item,
		"source_type": "hotbar",
		"hotbar_index": slot_index
	}


func _can_drop_data(at_position, data) -> bool:
	return data is Dictionary and data.has("item_data")


func _drop_data(at_position, data):
	var new_item = data.get("item_data")
	var source_type = data.get("source_type")
	
	var old_item = InventoryGlobal.hotbar_items.get(slot_index)
	InventoryGlobal.add_item_to_hotbar(slot_index, new_item)
	
	if old_item != null and old_item != new_item:
		if source_type == "hotbar":
			var old_index = data.get("hotbar_index")
			InventoryGlobal.add_item_to_hotbar(old_index, old_item)
		else: 
			var origin = data.get("origin_pivot")
			InventoryGlobal.place_item_at(origin.x, origin.y, old_item)
	elif source_type == "hotbar":
		var old_index = data.get("hotbar_index")
		if old_index != slot_index:
			InventoryGlobal.clear_hotbar_slot(old_index)


func _on_hotbar_updated(index: int, item_data: ItemData):
	if index == slot_index:
		if item_data:
			icon_display.texture = item_data.hotbar_icon
			icon_display.show()
		else:
			icon_display.texture = null
			icon_display.hide()


func _on_hotbar_selection_changed(index: int, _item):
	if index == slot_index:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.5, 1.5, 2.0), 0.1)
	else:
		modulate = Color.WHITE
