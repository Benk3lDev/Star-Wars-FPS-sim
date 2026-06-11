class_name EquipmentManager extends Node3D

@onready var hand_anchor = $"../HandAnchor"
@export var weapon_controller : WeaponController

var active_muzzle_node : Node3D = null
var weapon_sprite : AnimatedSprite3D = null

func _ready() -> void:
	# Connects cleanly to our unified input broadcasting signals
	InventoryGlobal.hotbar_selection_changed.connect(_on_item_selected)
	InventoryGlobal.hotbar_updated.connect(_on_hotbar_updated)
	
	# --- THE 2.5D SPRITE RIG SETUP ---
	# Dynamically check for or spawn a permanent AnimatedSprite3D node on our hand anchor shell
	weapon_sprite = hand_anchor.get_node_or_null("WeaponSprite3D") as AnimatedSprite3D
	if not weapon_sprite:
		weapon_sprite = AnimatedSprite3D.new()
		weapon_sprite.name = "WeaponSprite3D"
		hand_anchor.add_child(weapon_sprite)
		
		# Retro Doom-style rendering optimization flags:
		weapon_sprite.shaded = true # Catches dynamic 3D light flashes and shadow rays
		weapon_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Preserves crisp pixels
		weapon_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED # Stays locked strictly to weapon orientation angles
		
		# CRITICAL DEPTH DRAW FIX: Prevents weapon from clipping through solid level walls when close
		weapon_sprite.render_priority = 10 
		weapon_sprite.no_depth_test = true # Guarantees gun renders on top of the world geometry layer

	# Cache your pre-established permanent Muzzle node child
	active_muzzle_node = hand_anchor.get_node_or_null("Muzzle")
	if not active_muzzle_node:
		push_warning("EquipmentManager: Missing permanent 'Muzzle' node under HandAnchor! Projectiles may spawn from center.")

func _on_hotbar_updated(index: int, item: ItemData) -> void:
	if index == InventoryGlobal.active_hotbar_index:
		_update_active_item(item)

func _on_item_selected(_index: int, item: ItemData) -> void:
	_update_active_item(item)

func _update_active_item(item: ItemData) -> void:
	_clear_hands()
	
	# Re-cache your pre-established permanent Muzzle node child to re-initialize its tracking
	active_muzzle_node = hand_anchor.get_node_or_null("Muzzle")
	
	if item:
		# Route out to weapon state charts managers
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(item)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(item)
		
		# 1. Position the HandAnchor wrapper node using your ItemData offsets
		if "hand_pos" in item:
			hand_anchor.position = item.hand_pos
			
			if "weapon_stats" in item and item.weapon_stats and is_instance_valid(weapon_controller):
				weapon_controller.activate_weapon(item.weapon_stats)
			elif is_instance_valid(weapon_controller):
				weapon_controller.deactivate_weapon()
		else:
			hand_anchor.position = Vector3.ZERO
			if is_instance_valid(weapon_controller):
				weapon_controller.deactivate_weapon()
		
		# --- 2. THE CHAMELEON SPRITE SWAPPER ---
		if "weapon_sprite_frames" in item and item.weapon_sprite_frames:
			weapon_sprite.sprite_frames = item.weapon_sprite_frames
			weapon_sprite.visible = true
			weapon_sprite.play("idle")
			
			# --- 3. TELEPORT THE PRE-ESTABLISHED MUZZLE NODE ---
			if "weapon_stats" in item and item.weapon_stats and "sprite_muzzle_offset" in item.weapon_stats:
				# Instantly snap your permanent Muzzle to your copied resource coordinates!
				if is_instance_valid(active_muzzle_node):
					active_muzzle_node.position = item.weapon_stats.sprite_muzzle_offset
			else:
				if is_instance_valid(active_muzzle_node):
					active_muzzle_node.position = Vector3(0.15, -0.1, -0.4) # Safe baseline fallback fallback
					
			print("🎨 [EQUIPMENT MANAGER] 2.5D Sprite Loaded. Muzzle teleported to: ", active_muzzle_node.position)
			
		else:
			# Legacy Fallback option in case you want to instantiate an old 3D mesh model scene
			if "item_model" in item and item.item_model:
				weapon_sprite.visible = false
				var hand_item = item.item_model.instantiate()
				hand_anchor.add_child(hand_item)
				hand_item.transform = Transform3D.IDENTITY
				
				# Overwrite our reference tracker using the model's baked muzzle node
				var model_muzzle = hand_item.get_node_or_null("Muzzle")
				if model_muzzle:
					active_muzzle_node = model_muzzle
	else:
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.activate_weapon(null)
		elif get_parent().has_node("WeaponManager"):
			get_parent().get_node("WeaponManager").activate_weapon(null)
			
		if is_instance_valid(weapon_controller):
			weapon_controller.deactivate_weapon()
		hand_anchor.position = Vector3.ZERO
		
		# Reset muzzle position when empty handed
		if is_instance_valid(active_muzzle_node):
			active_muzzle_node.position = Vector3.ZERO

func _clear_hands() -> void:
	# Wipe out old legacy 3D mesh instances, but keep our permanent sprite and muzzle nodes intact
	for child in hand_anchor.get_children():
		if child != weapon_sprite and child.name != "Muzzle":
			child.queue_free()
			
	if weapon_sprite:
		weapon_sprite.visible = false
		weapon_sprite.sprite_frames = null
