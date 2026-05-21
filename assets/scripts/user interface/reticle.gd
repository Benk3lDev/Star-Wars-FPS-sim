extends Control

# Holds our verified 3D reference safely
var equipment_manager : Node3D = null

@onready var reticle_texture : TextureRect = $ReticleTexture

func _ready() -> void:
	# Center the texture's pivot point on itself
	reticle_texture.pivot_offset = reticle_texture.size / 2.0
	
	# Wait one frame to ensure the level tree and player are fully initialized
	await get_tree().process_frame
	
	# Find the EquipmentManager via its global group
	var managers = get_tree().get_nodes_in_group("equipment_manager")
	if managers.size() > 0:
		# --- THE CRITICAL FIX: Extract index 0 out of the array ---
		equipment_manager = managers[0] as Node3D
		print("Reticle UI: Successfully hooked onto: ", equipment_manager.name)
	else:
		push_error("Reticle UI: Could not find any node in the 'equipment_manager' group!")

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	
	# --- VISUAL FALLBACK SAFETY LOOP ---
	# If unarmed or unlinked, keep the crosshair pinned to the center of the screen
	if not camera or not is_instance_valid(equipment_manager) or not is_instance_valid(equipment_manager.active_muzzle_node):
		show()
		var screen_center = get_viewport_rect().size / 2.0
		reticle_texture.global_position = screen_center - (reticle_texture.size / 2.0)
		return
		
	# Target the live "Muzzle" marker sitting inside your weapon item model scene
	var muzzle = equipment_manager.active_muzzle_node
		
	# --- 3D TO 2D TRACKING LOOP ---
	# Calculate a 3D position vector 2 meters directly out in front of where the muzzle barrel points
	var muzzle_forward_point = muzzle.global_position + (-muzzle.global_transform.basis.z * 2.0)
	
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
