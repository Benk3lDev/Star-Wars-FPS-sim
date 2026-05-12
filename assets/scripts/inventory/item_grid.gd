class_name ItemGrid extends GridContainer

const SLOT_SIZE : int = 64
@export var inventory_slot_scene : PackedScene
@export var item_canvas : Control
@export var context_menu : PanelContainer

var dimensions : Vector2i
var preview_sprite : TextureRect = null
var target_rotation_deg : float = 0.0
var hovered_slots : Array[Control] = []
var last_calculated_origin : Vector2i = Vector2i(-1, -1)

signal context_menu_requested(item: ItemData, pivot_pos: Vector2i, mouse_pos: Vector2)

func _ready() -> void:
	dimensions = InventoryGlobal.dimensions
	
	self.custom_minimum_size = Vector2(dimensions.x * SLOT_SIZE, dimensions.y * SLOT_SIZE)
	self.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	create_slots()
	InventoryGlobal.inventory_updated.connect(refresh_ui)
	refresh_ui()

func create_slots() -> void:
	self.columns = dimensions.x
	for child in get_children():
		child.queue_free()
			
	for i in dimensions.x * dimensions.y:
		var slot = inventory_slot_scene.instantiate() as Control
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		add_child(slot)

func refresh_ui() -> void:
	if not item_canvas: return
	for child in item_canvas.get_children():
		if child == preview_sprite: 
			continue
		child.queue_free()
	
	var drawn_items: Array[ItemData] = []
	for i in range(InventoryGlobal.slot_data.size()):
		var current_resource = InventoryGlobal.slot_data[i]
		if current_resource and not drawn_items.has(current_resource):
			drawn_items.append(current_resource)
			
			var icon_rect = TextureRect.new()
			icon_rect.texture = current_resource.icon
			icon_rect.layout_mode = 1 
			icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon_rect.size = Vector2(current_resource.size * SLOT_SIZE)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# If the placed item is rotated, match its static visuals and pivot anchor
			if current_resource.is_rotated:
				icon_rect.rotation_degrees = 90.0
				# Pivot from top-left, shifting right by its visual height to keep it in-bounds
				icon_rect.pivot_offset = Vector2.ZERO
				var coords = get_grid_coords_from_index(i)
				icon_rect.position = Vector2((coords.x + current_resource.size.y) * SLOT_SIZE, coords.y * SLOT_SIZE)
			else:
				var coords = get_grid_coords_from_index(i)
				icon_rect.position = Vector2(coords.x * SLOT_SIZE, coords.y * SLOT_SIZE)
				
			item_canvas.add_child(icon_rect)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var local_mouse = get_local_mouse_position()
		var index = get_slot_index_from_coords(local_mouse)
		if index == -1: return
		
		# --- LEFT CLICK: Standard Drag & Drop ---
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_slot_click(index, local_mouse)
			
		# --- RIGHT CLICK: Context Menu ---
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if InventoryGlobal.current_drag_data != null: return
			var cell_coords = get_grid_coords_from_index(index)
			var clicked_item = InventoryGlobal.get_item_at_grid_coords(cell_coords)
			if clicked_item:
				var item_origin = InventoryGlobal.find_item_origin_coords(clicked_item)
				context_menu_requested.emit(clicked_item, item_origin, get_global_mouse_position())


func _input(event: InputEvent) -> void:
	# 1. Update Preview Position on Mouse Move
	if event is InputEventMouseMotion and preview_sprite and InventoryGlobal.current_drag_data:
		update_preview_and_highlights(get_local_mouse_position())
		
	# 2. Handle Rotation Input
	if InventoryGlobal.current_drag_data and (event.is_action_pressed("rotate_item", false, true) or (event is InputEventKey and event.pressed and event.keycode == KEY_R)):
		rotate_held_item()

func rotate_held_item() -> void:
	var item : ItemData = InventoryGlobal.current_drag_data
	item.is_rotated = not item.is_rotated
	
	if item.is_rotated:
		target_rotation_deg = 90.0
		InventoryGlobal.drag_offset = Vector2(InventoryGlobal.drag_offset.y, item.size.x * SLOT_SIZE - InventoryGlobal.drag_offset.x)
	else:
		target_rotation_deg = 0.0
		InventoryGlobal.drag_offset = Vector2(item.size.y * SLOT_SIZE - InventoryGlobal.drag_offset.y, InventoryGlobal.drag_offset.x)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(preview_sprite, "rotation_degrees", target_rotation_deg, 0.15)
	
	# Force an instant frame update to recalculate the highlights for the new rotation shape
	update_preview_and_highlights(get_local_mouse_position())

func handle_slot_click(index: int, local_mouse: Vector2) -> void:
	# STATE A: Hand is empty -> Pick up item
	if InventoryGlobal.current_drag_data == null:
		var cell_coords = get_grid_coords_from_index(index)
		var clicked_item = InventoryGlobal.get_item_at_grid_coords(cell_coords)
		
		if clicked_item:
			# --- REMOVED THE IS_EQUIPPED RESTRICTION THAT LOCKED THE GRID ---
			
			InventoryGlobal.current_drag_data = clicked_item
			InventoryGlobal.drag_source = self
			
			var origin_coords = InventoryGlobal.find_item_origin_coords(clicked_item)
			
			# Lock the pickup coordinates cleanly right at the frame of pickup
			InventoryGlobal.original_pickup_coords = origin_coords
			
			var origin_pixel = Vector2(origin_coords.x * SLOT_SIZE, origin_coords.y * SLOT_SIZE)
			
			if clicked_item.is_rotated:
				var local_click = local_mouse - origin_pixel
				var displacement_adjusted = local_click - Vector2(clicked_item.size.y * SLOT_SIZE, 0.0)
				InventoryGlobal.drag_offset = displacement_adjusted.rotated(deg_to_rad(-90.0))
			else:
				InventoryGlobal.drag_offset = local_mouse - origin_pixel
			
			create_drag_preview()
			InventoryGlobal.remove_item(clicked_item)
			
	# STATE B: Hand is holding an item -> Try to place it
	else:
		var cell_coords = get_grid_coords_from_index(index)
		var item : ItemData = InventoryGlobal.current_drag_data
		
		# If you are dragging an item and click back onto the grid, 
		# we clear the equipped status because you are choosing to relocate it
		item.is_equipped_now = false
		
		var target_origin : Vector2i
		if item.is_rotated:
			var grab_offset = Vector2i(
				floor((item.size.y * SLOT_SIZE - InventoryGlobal.drag_offset.y) / float(SLOT_SIZE)),
				floor(InventoryGlobal.drag_offset.x / float(SLOT_SIZE))
			)
			target_origin = cell_coords - grab_offset
		else:
			var grab_offset = Vector2i(
				floor(InventoryGlobal.drag_offset.x / float(SLOT_SIZE)),
				floor(InventoryGlobal.drag_offset.y / float(SLOT_SIZE))
			)
			target_origin = cell_coords - grab_offset

		var item_size = item.size
		if item.is_rotated:
			item_size = Vector2i(item_size.y, item_size.x)
			
		if InventoryGlobal.check_slot_availability(target_origin, item_size):
			InventoryGlobal.insert_item_at_grid_coords(target_origin, item)
			clear_drag_preview()
		else:
			print("Item doesn't fit here!")


func create_drag_preview() -> void:
	var item : ItemData = InventoryGlobal.current_drag_data
	
	# Set start angle based on current state (handles picking up already-rotated items)
	target_rotation_deg = 90.0 if item.is_rotated else 0.0
	
	preview_sprite = TextureRect.new()
	preview_sprite.texture = item.icon
	preview_sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	preview_sprite.size = item.size * SLOT_SIZE
	preview_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_sprite.rotation_degrees = target_rotation_deg
	
	# Setting the pivot to the exact grab point keeps the item attached to your cursor during lerps
	preview_sprite.pivot_offset = Vector2.ZERO
	
	item_canvas.add_child(preview_sprite)


func get_slot_index_from_coords(local_coords: Vector2) -> int:
	var gx := int(local_coords.x / SLOT_SIZE)
	var gy := int(local_coords.y / SLOT_SIZE)
	if gx < 0 or gx >= dimensions.x or gy < 0 or gy >= dimensions.y: return -1
	return gx + (gy * dimensions.x)

func get_grid_coords_from_index(index: int) -> Vector2i:
	return Vector2i(index % dimensions.x, index / dimensions.x)


func update_preview_and_highlights(mouse_pos: Vector2) -> void:
	var item : ItemData = InventoryGlobal.current_drag_data
	var current_rad = deg_to_rad(preview_sprite.rotation_degrees)
	
	# Compute exact visual transform matrix positioning
	var rotated_offset = Vector2(
		InventoryGlobal.drag_offset.x * cos(current_rad) - InventoryGlobal.drag_offset.y * sin(current_rad),
		InventoryGlobal.drag_offset.x * sin(current_rad) + InventoryGlobal.drag_offset.y * cos(current_rad)
	)
	var rotation_pivot_compensation = Vector2(sin(current_rad) * (item.size.y * SLOT_SIZE), 0.0)
	preview_sprite.position = mouse_pos - rotated_offset + rotation_pivot_compensation
	
	# --- GRID HOVER HIGHLIGHT SYSTEM ---
	var current_index = get_slot_index_from_coords(mouse_pos)
	if current_index == -1:
		clear_slot_highlights()
		return
		
	var cell_coords = get_grid_coords_from_index(current_index)
	var target_origin : Vector2i
	
	if item.is_rotated:
		var grab_offset = Vector2i(
			int((item.size.y * SLOT_SIZE - InventoryGlobal.drag_offset.y) / SLOT_SIZE),
			int(InventoryGlobal.drag_offset.x / SLOT_SIZE)
		)
		target_origin = cell_coords - grab_offset
	else:
		var grab_offset = Vector2i(InventoryGlobal.drag_offset / float(SLOT_SIZE))
		target_origin = cell_coords - grab_offset
		
	# Only update visual nodes if the structural root cell changes to save processing cycles
	if target_origin != last_calculated_origin:
		last_calculated_origin = target_origin
		clear_slot_highlights()
		
		var item_size = Vector2i(item.size.y, item.size.x) if item.is_rotated else item.size
		var is_valid_placement = InventoryGlobal.check_slot_availability(target_origin, item_size)
		
		# Loop through all grid cells this item size overlaps
		for x in range(item_size.x):
			for y in range(item_size.y):
				var check_coord = target_origin + Vector2i(x, y)
				
				# Confirm cell stays inside the layout array bounds
				if check_coord.x >= 0 and check_coord.x < dimensions.x and check_coord.y >= 0 and check_coord.y < dimensions.y:
					var slot_idx = check_coord.x + (check_coord.y * dimensions.x)
					var slot_node = get_child(slot_idx)
					
					if slot_node.has_method("set_highlight"):
						slot_node.set_highlight(true, is_valid_placement)
						hovered_slots.append(slot_node)


func clear_slot_highlights() -> void:
	for slot in hovered_slots:
		if is_instance_valid(slot) and slot.has_method("set_highlight"):
			slot.set_highlight(false)
	hovered_slots.clear()


# Hook clearing functionality into your existing breakdown loop
func clear_drag_preview() -> void:
	clear_slot_highlights()
	last_calculated_origin = Vector2i(-1, -1)
	if preview_sprite:
		preview_sprite.queue_free()
		preview_sprite = null
	InventoryGlobal.current_drag_data = null
	InventoryGlobal.drag_source = null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Only accept drag drop packages coming explicitly from a hotbar slot
	if data is Dictionary and data.has("source_type"):
		return data.get("source_type") == "hotbar"
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var target_hotbar_idx = data.get("hotbar_index")
	var hotbar_item = data.get("item_data") as ItemData
	
	if target_hotbar_idx != null and hotbar_item != null:
		# 1. Scan your grid storage to find the reference matching this hotbar element's name
		for i in range(InventoryGlobal.slot_data.size()):
			var grid_item = InventoryGlobal.slot_data[i]
			if grid_item and grid_item.item_name == hotbar_item.item_name:
				# 2. Turn off its equipped restriction flag and restore full visual brightness
				grid_item.is_equipped_now = false
				break
				
		# 3. Wipe the hotbar container array index clean completely
		InventoryGlobal.clear_hotbar_slot(target_hotbar_idx)
		
		# 4. Redraw your interface maps to instantly apply changes
		refresh_ui()
		print("[ItemGrid] Hotbar item successfully returned to grid array layout upon drag release.")


# Called by the hotbar slot when an item from this grid is successfully dropped into it
func finalize_hotbar_drop() -> void:
	if InventoryGlobal.current_drag_data:
		var item : ItemData = InventoryGlobal.current_drag_data
		
		# Flag it so it dims on the inventory grid array map
		item.is_equipped_now = true
		
		# Destroy the loose floating preview node following the cursor
		if preview_sprite:
			preview_sprite.queue_free()
			preview_sprite = null
			
		# Clean the global tracking registers without erasing the data matrix blocks
		InventoryGlobal.current_drag_data = null
		InventoryGlobal.drag_source = null
		last_calculated_origin = Vector2i(-1, -1)
		clear_slot_highlights()
		
		# Redraw the grid to show the newly duplicated/dimmed item asset block
		refresh_ui()
		print("[ItemGrid] Item locked to original grid coords and visually dimmed.")
