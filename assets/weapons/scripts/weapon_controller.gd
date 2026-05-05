class_name WeaponController extends Node


@export var camera: Camera3D
@export var weapon_state_chart: StateChart
@export var hand_anchor : Node3D


var current_weapon: Weapon
var can_fire_next: bool = true
var fire_rate_timer: float = 0.0


func _ready():
	print("WeaponController is ready and in groups: ", get_groups())


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


func can_fire() -> bool:
	return Managers.weapon_manager.has_ammo() and can_fire_next


func fire_weapon() -> void:
	if can_fire():
		Managers.weapon_manager.use_ammo(Managers.weapon_manager.current_slot)

		can_fire_next = false
		fire_rate_timer = 1.0 / current_weapon.fire_rate

		if current_weapon.is_hit_scan:
			_perform_hitscan()
		else:
			_spawn_projectile()


func _perform_hitscan() -> void:
	if not camera:
		print("No camera assigned!")
		return

	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	
	# Calculate accuracy spread
	var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0
	
	# Fire multiple pellets
	for i in current_weapon.pellet_count:
		var forward = -camera.global_transform.basis.z

		# Add accuracy randomness
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
			print("Hit: ", result.collider.name, " at ", result.position)
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

	# Auto-remove after 2 seconds
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)

func _spawn_projectile() -> void:
	if not current_weapon.projectile_scene:
		print("No projectile scene assigned!")
		return

	if not camera:
		print("No camera assigned!")
		return
	
	var muzzle = hand_anchor.find_child(current_weapon.muzzle_node_name, true, false)
	
	var spawn_pos = camera.global_position
	if muzzle:
		spawn_pos = muzzle.global_position
	
	# Spawn the projectile
	var projectile = current_weapon.projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)

	# Position at camera
	projectile.global_position = spawn_pos

	# Calculate accuracy spread
	var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0

# Calculate direction and velocity
	var forward = -camera.global_transform.basis.z
	
	#Add accuracy randomness to direction
	var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
	var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
	var direction = forward + Vector3(accuracy_x, accuracy_y, 0) * camera.global_transform.basis
	
	var velocity = direction * current_weapon.projectile_speed
	projectile.look_at(projectile.global_position + direction, Vector3.UP)

	# Setup the projectile
	projectile.setup(velocity, current_weapon.damage)


func has_ammo() -> bool:
	if Managers.weapon_manager == null:
		return false
	
	if Managers.weapon_manager.current_equipped_item == null:
		return false
	
	return Managers.weapon_manager.current_equipped_item.ammo > 0
