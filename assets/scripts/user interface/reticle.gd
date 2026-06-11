extends Control

# Holds our local references fetched from the Global Singleton
var equipment_manager : Node3D = null
var weapon_manager : Node = null

@onready var reticle_texture : TextureRect = $ReticleTexture

func _ready() -> void:
	# Center the texture's pivot point on itself
	reticle_texture.pivot_offset = reticle_texture.size / 2.0
	
	# Wait one frame to ensure the global Managers script finished its deferred initialization
	await get_tree().process_frame
	
	# Fetch directly from your global singleton
	if is_instance_valid(Managers.equipment_manager):
		equipment_manager = Managers.equipment_manager
		print("Reticle UI: Successfully hooked onto equipment manager.")
	else:
		push_error("Reticle UI: Equipment manager missing from Global Autoload!")
		
	if is_instance_valid(Managers.weapon_manager):
		weapon_manager = Managers.weapon_manager
		print("Reticle UI: Successfully hooked onto weapon manager.")
	else:
		push_error("Reticle UI: Weapon manager missing from Global Autoload!")

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	
	# --- VISUAL FALLBACK SAFETY LOOP ---
	# Ensure all references, the active muzzle, and equipped weapon items are fully ready
	if not camera or \
	   not is_instance_valid(equipment_manager) or \
	   not is_instance_valid(weapon_manager) or \
	   not is_instance_valid(equipment_manager.active_muzzle_node) or \
	   not weapon_manager.current_equipped_item or \
	   not weapon_manager.current_equipped_item.weapon_stats:
		show()
		var screen_center = get_viewport_rect().size / 2.0
		reticle_texture.global_position = screen_center - (reticle_texture.size / 2.0)
		return
		
	# Target the permanent "Muzzle" marker teleported by the EquipmentManager
	var muzzle = equipment_manager.active_muzzle_node
	var weapon_range = weapon_manager.current_equipped_item.weapon_stats.range
		
	# --- 3D TO 2D TRACKING LOOP ---
	# FIX: Instead of checking the muzzle node's individual local transform basis,
	# we extract the camera's true forward Z-direction vector and project it 
	# starting outward directly from the muzzle's active 3D coordinates.
	var camera_forward = -camera.global_transform.basis.z
	var muzzle_forward_point = muzzle.global_position + (camera_forward * weapon_range)
	
	# Fall back to screen center if the weapon points behind the camera view plane
	if camera.is_position_behind(muzzle_forward_point):
		var screen_center = get_viewport_rect().size / 2.0
		reticle_texture.global_position = screen_center - (reticle_texture.size / 2.0)
		return
		
	show()
	
	# Translate the 3D position vector into 2D viewport pixel coordinates
	var screen_position = camera.unproject_position(muzzle_forward_point)
	
	# Move the UI element over those exact projection coordinates
	reticle_texture.global_position = screen_position - (reticle_texture.size / 2.0)
