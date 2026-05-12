extends Sprite2D

@onready var quantity_label = $QuantityLabel

var data : ItemData
var size : Vector2:
	get():
		return Vector2(data.dimensions.x, data.dimensions.y) * 64
var grid_pos : Vector2i
var anchor_point: Vector2:
	get():
		return global_position - size / 2


func _ready():
	
	if data:
		texture = data.texture


func set_init_position(pos: Vector2) -> void:
	global_position = pos + size / 2
	anchor_point = global_position - size /2


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var slot_data = InventoryGlobal.inventory[grid_pos.x + (grid_pos.y * InventoryGlobal.grid_width)]
			if slot_data.get("is_occupied", false):
				var px = slot_data.pivot_gx
				var py = slot_data.pivot_gy
				var pivot_slot = InventoryGlobal.inventory[px + (py * InventoryGlobal.grid_width)]
				
				var item = pivot_slot.item_resource
				if item:
					InventoryGlobal.request_context_menu.emit(item, Vector2i(px, py), get_global_mouse_position())
