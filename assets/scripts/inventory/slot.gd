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


func _can_drop_data(at_position, data):
	var item_resource = data.get("item_data")
	if not item_resource:
		return false
	
	var grid = owner.grid_container
	var local_mouse = grid.get_local_mouse_position()
	
	var gx = int(local_mouse.x / size.x)
	var gy = int(local_mouse.y / size.y)
	
	var item_size = item_resource.get_size()
	
	return InventoryGlobal.is_space_available(gx, gy, item_size.x, item_size.y)


func _drop_data(at_position, data):
	var item_resource = data.get("item_data")
	var grid = owner.grid_container
	var local_mouse = grid.get_local_mouse_position()
	
	var gx = int(local_mouse.x / size.x)
	var gy = int(local_mouse.y / size.y)
	
	InventoryGlobal.place_item_at(gx, gy, item_resource)
