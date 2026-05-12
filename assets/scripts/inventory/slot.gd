extends TextureRect

signal slot_entered(slot)
signal slot_exited(slot)

@onready var filter = $StatusFilter


var slot_ID
var is_hovering := false
enum States {DEFAULT, TAKEN, FREE}
var state = States.DEFAULT
var item_stored = null
var grid_pos : Vector2i



func set_color(a_state = States.DEFAULT) -> void:
	match a_state:
		States.DEFAULT:
			filter.color = Color(Color.WHITE, 0.0)
		States.TAKEN:
			filter.color = Color(Color.RED, 0.2)
		States.FREE:
			filter.color = Color(Color.GREEN, 0.2)



func _process(delta: float) -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		if not is_hovering:
			is_hovering = true
			emit_signal("slot_entered", self)
	else:
		if is_hovering:
			is_hovering = false
			emit_signal("slot_exited",self)


func _get_drag_data(at_position):
	if item_stored == null: return null
	
	var slot_data = InventoryGlobal.get_slot_at(grid_pos.x, grid_pos.y)
	if slot_data == null or slot_data.item_resource == null:
		return null
	
	var pivot_pos = InventoryGlobal.find_pivot_of_item_at(grid_pos.x, grid_pos.y)
	
	var main_ui = get_tree().get_root().find_child("Inventory_UI", true, false)
	if main_ui:
		main_ui.held_item_data = item_stored
		main_ui.current_held_item_size = item_stored.get_size()
	
	var preview = TextureRect.new()
	preview.texture = item_stored.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(InventoryGlobal.slot_size, InventoryGlobal.slot_size)
	set_drag_preview(preview)
	
	return {
		"item_data": item_stored,
		"origin_pivot": pivot_pos,
		"origin_node": self,
		"type": "ivnentory"
	}


func _can_drop_data(at_position, data):
	var item_resource = data.get("item_data")
	
	if not item_resource:
		return false
	
	if data.get("source_type") == "hotbar":
		return true
	
	var grid = owner.grid_container
	var local_mouse = grid.get_local_mouse_position()
	
	var gx = int(local_mouse.x / size.x)
	var gy = int(local_mouse.y / size.y)
	
	var item_size = item_resource.get_size()
	
	return InventoryGlobal.is_space_available(gx, gy, item_size.x, item_size.y)


func _drop_data(at_position, data):

	# Hotbar movement
	if data.get("source_type") == "hotbar":
		var h_index = data.get("hotbar_index")
		InventoryGlobal.clear_hotbar_slot(h_index)
		return

	# Inventory grid movement
	var item_resource = data.get("item_data")
	var origin = data.get("original_pos")
		#print("DEBUG: origin_pivot value is ", origin)
	if origin != null:
		InventoryGlobal.remove_item_at_pos(origin.x, origin.y)
	
	var grid = owner.grid_container
	var local_mouse = grid.get_local_mouse_position()
	var gx = int(local_mouse.x / size.x)
	var gy = int(local_mouse.y / size.y)
	
	InventoryGlobal.place_item_at(gx, gy, item_resource)


func set_highlight(is_visible: bool, is_valid: bool = true) -> void:
	if not is_visible:
		set_color(States.DEFAULT)
	elif is_valid:
		set_color(States.FREE)
	else: set_color(States.TAKEN)
