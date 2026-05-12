class_name WeaponController extends Node

@export var camera: Camera3D
@export var weapon_state_chart: StateChart
@export var hand_anchor : Node3D

var current_weapon: Weapon
var can_fire_next: bool = true
var fire_rate_timer: float = 0.0

func _ready():
	print("WeaponController is ready.")

func activate_weapon(stats: Weapon):
	current_weapon = stats
	can_fire_next = true
	fire_rate_timer = 0.0
	if weapon_state_chart:
		weapon_state_chart.send_event("OnIdle")

func deactivate_weapon():
	current_weapon = null

func _process(delta: float) -> void:
	if fire_rate_timer > 0:
		fire_rate_timer -= delta
		if fire_rate_timer <= 0:
			can_fire_next = true
			
			# --- AUTOMATIC CHAIN FIRE LOOKUP ENGINE ---
			# If the cooldown just finished, check if we should automatically fire again
			if current_weapon and "is_automatic" in current_weapon and current_weapon.is_automatic:
				# Safety check: ensures menu overlays or active item dragging blocks inputs
				if InventoryGlobal.current_drag_data == null and not (InventoryGlobal.ui_node and InventoryGlobal.ui_node.visible):
					# If they are STILL holding the fire key down, execute another fire loop
					if Input.is_action_pressed("attack") and can_fire():
						fire_weapon()


func can_fire() -> bool:
	return has_ammo() and can_fire_next and current_weapon != null

func fire_weapon() -> void:
	if can_fire():
		# Deduct ammo safely via the current weapon manager
		if "weapon_manager" in Managers and Managers.weapon_manager:
			Managers.weapon_manager.use_ammo(Managers.weapon_manager.current_slot)
		elif get_tree().get_first_node_in_group("weapon_manager"):
			var wm = get_tree().get_first_node_in_group("weapon_manager")
			wm.use_ammo(wm.current_slot)

		can_fire_next = false
		fire_rate_timer = 1.0 / current_weapon.fire_rate

		if current_weapon.is_hit_scan:
			_perform_hitscan()
		else:
			_spawn_projectile()

func _perform_hitscan() -> void:
	if not camera: return
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0
	
	for i in current_weapon.pellet_count:
		var forward = -camera.global_transform.basis.z
		var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
		var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
		var direction = forward + Vector3(accuracy_x, accuracy_y, 0) * camera.global_transform.basis

		if current_weapon.pellet_count > 1:
			var spread_x = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			var spread_y = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			direction += Vector3(spread_x, spread_y, 0) * camera.global_transform.basis
	
		var to = from + direction * current_weapon.range
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)

		if result:
			_spawn_impact_marker(result.position)

func _spawn_impact_marker(position: Vector3) -> void:
	var marker = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	marker.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	marker.set_surface_override_material(0, material)

	get_tree().current_scene.add_child(marker)
	marker.global_position = position
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)

func _spawn_projectile() -> void:
	if not current_weapon or not current_weapon.projectile_scene or not camera: return
	
	var spawn_pos = camera.global_position
	if hand_anchor and current_weapon.muzzle_node_name != "":
		var muzzle = hand_anchor.find_child(current_weapon.muzzle_node_name, true, false)
		if muzzle: spawn_pos = muzzle.global_position
	elif hand_anchor:
		spawn_pos = hand_anchor.global_position
	
	var projectile = current_weapon.projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos

	var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0
	var forward = -camera.global_transform.basis.z
	var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
	var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
	var direction = forward + Vector3(accuracy_x, accuracy_y, 0) * camera.global_transform.basis
	var velocity = direction * current_weapon.projectile_speed
	
	if direction.is_equal_approx(Vector3.UP) or direction.is_equal_approx(Vector3.DOWN):
		projectile.look_at(projectile.global_position + direction, Vector3.FORWARD)
	else:
		projectile.look_at(projectile.global_position + direction, Vector3.UP)

	projectile.setup(velocity, current_weapon.damage)

func has_ammo() -> bool:
	var wm = null
	if "weapon_manager" in Managers and Managers.weapon_manager:
		wm = Managers.weapon_manager
	else:
		wm = get_tree().get_first_node_in_group("weapon_manager")
		
	if wm == null or wm.current_equipped_item == null:
		return false
	return "ammo" in wm.current_equipped_item and wm.current_equipped_item.ammo > 0
