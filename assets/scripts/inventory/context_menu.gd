extends PanelContainer

signal action_selected(action_type: String, item_data: ItemData, slot_pos: Vector2i)

@onready var equip_button = $VBoxContainer/Equip
@onready var unequip_button = $VBoxContainer/Unequip

# Use class variables to explicitly preserve data scope across button frames
var current_item : ItemData = null
var current_slot_pos : Vector2i = Vector2i.ZERO

func _ready():
	hide()

func open(item: ItemData, slot_pos: Vector2i, mouse_pos: Vector2):
	if not item: 
		print("[ContextMenu] Error: Opened with null item data!")
		return
		
	# Bind data to the script instance
	current_item = item
	current_slot_pos = slot_pos
	global_position = mouse_pos
	
	var is_equipped = false
	if current_item.item_type == "Armor":
		is_equipped = InventoryGlobal.equipped_armor.values().has(current_item)
		equip_button.visible = not is_equipped
		unequip_button.visible = is_equipped
	else:
		equip_button.hide()
		unequip_button.hide()
	
	global_position += Vector2(5, 5)
	show()

func _on_drop_pressed() -> void:
	if current_item:
		action_selected.emit("drop", current_item, current_slot_pos)
	hide()

func _on_use_pressed():
	hide()

func _on_equip_pressed():
	if current_item:
		# Explicitly verify data is intact right before firing signal
		print("[ContextMenu] Button clicked. Emitting equip for: ", current_item.resource_name)
		action_selected.emit("equip", current_item, current_slot_pos)
	else:
		print("[ContextMenu] Error: Button clicked but current_item was null!")
	hide()

func _on_unequip_pressed() -> void:
	if current_item:
		action_selected.emit("unequip", current_item, current_slot_pos)
	hide()

func _input(event: InputEvent) -> void:
	# Only evaluate mouse button releases
	if event is InputEventMouseButton and not event.pressed:
		# Check if the player released the LEFT mouse button outside the context menu bounds
		if event.button_index == MOUSE_BUTTON_LEFT:
			if visible and not get_global_rect().has_point(get_global_mouse_position()):
				# Use a deferred call to let buttons consume the input event frame first
				callable_hide.call_deferred()

# Helper function to clear state safely when hiding
func callable_hide() -> void:
	hide()
