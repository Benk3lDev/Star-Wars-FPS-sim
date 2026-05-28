class_name NPCWeaponController extends Node

## Explicitly wire this node path picker to your manually placed Marker3D muzzle node
@export var muzzle_node: Marker3D

var npc: NPC
var can_fire_next: bool = true
var fire_rate_timer: float = 0.0

func _ready() -> void:
	npc = get_parent() as NPC
	if not npc:
		push_error("NPCWeaponController: Parent node is not an NPC!")
		return
		
	print("NPCWeaponController is ready for: ", npc.name)
	
	# Fallback safe catcher if node wasn't manually dragged into inspector slot
	if not muzzle_node:
		muzzle_node = npc.get_node_or_null("Muzzle") as Marker3D

func _process(delta: float) -> void:
	if fire_rate_timer > 0.0:
		fire_rate_timer -= delta
		if fire_rate_timer <= 0.0:
			can_fire_next = true

## Centralized capability checker feeding back into your Combat State Chart scripts
func can_fire() -> bool:
	if not is_instance_valid(npc) or npc.active_weapon_stats == null:
		return false
	return has_ammo() and can_fire_next

## Read ammo directly off the unified root parameters we unpacked from ItemData resources
func has_ammo() -> bool:
	if not is_instance_valid(npc): return false
	return npc.current_ammo > 0

## Called externally by your custom combat_fire_state script loop ticks
func npc_fire_weapon(target: CharacterBody3D) -> void:
	# Double check internal mechanics conditions before triggering ammunition depletion calculations
	if not can_fire() or not is_instance_valid(target):
		return
		
	var weapon = npc.active_weapon_stats

	# 1. DEDUCT AMMO ON THE INDEPENDENT ENEMY INSTANCE
	npc.current_ammo = max(0, npc.current_ammo - 1)
	
	# 2. ENGAGE COOLDOWN TIMING CADENCE WINDOWS
	can_fire_next = false
	fire_rate_timer = 1.0 / weapon.fire_rate

	# 3. DIRECT BALLISTICS DEPLOYMENT SYSTEM 
	if weapon.is_hit_scan:
		_perform_hitscan(target)
	else:
		_spawn_projectile(target)

func _perform_hitscan(target: CharacterBody3D) -> void:
	var weapon = npc.active_weapon_stats
	var spawn_pos = muzzle_node.global_position if muzzle_node else npc.global_position
	var space_state = muzzle_node.get_world_3d().direct_space_state if muzzle_node else npc.get_world_3d().direct_space_state
	
	# Aim straight for player center chest mass height (approx +1m up from their base position vector)
	var target_chest = target.global_position + Vector3(0, 1.0, 0)
	var base_direction = (target_chest - spawn_pos).normalized()
	
	var accuracy_spread = (100 - weapon.accuracy) / 1000.0
	
	# Create a look-at helper basis matching the trajectory angle vector
	# This replaces the player's 'camera.global_transform.basis' lookup for the AI!
	var look_transform = npc.global_transform.looking_at(target_chest, Vector3.UP)
	var forward_basis = look_transform.basis

	for i in weapon.pellet_count:
		var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
		var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
		var direction = base_direction + (Vector3(accuracy_x, accuracy_y, 0) * forward_basis)

		if weapon.pellet_count > 1:
			var spread_x = randf_range(-weapon.spread_angle, weapon.spread_angle)
			var spread_y = randf_range(-weapon.spread_angle, weapon.spread_angle)
			direction += Vector3(spread_x, spread_y, 0) * forward_basis
	
		var to = spawn_pos + direction.normalized() * weapon.range
		var query = PhysicsRayQueryParameters3D.create(spawn_pos, to)
		
		# Exclude the shooter body from colliding with its own hitscan raycast beams
		query.exclude = [npc.get_rid()]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)

		if result:
			_spawn_impact_marker(result.position)
			
			var hit_body = result.collider
			if hit_body and hit_body is Node3D:
				# Use your unified Health component nested route search check parameters
				var health = hit_body.get_node_or_null("HealthComponent") as HealthComponent
				if not health:
					health = hit_body.get_node_or_null("Components/HealthComponent") as HealthComponent
					
				if health:
					var shape_id = result.get("shape", -1)
					health.take_damage(int(weapon.damage), "bullet", null, shape_id)

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

func _spawn_projectile(target: CharacterBody3D) -> void:
	var weapon = npc.active_weapon_stats
	if not weapon or not weapon.projectile_scene: return
	
	var spawn_pos = muzzle_node.global_position if muzzle_node else npc.global_position
	var target_chest = target.global_position + Vector3(0, 1.0, 0)
	var base_direction = (target_chest - spawn_pos).normalized()
	
	var projectile = weapon.projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos

	var accuracy_spread = (100 - weapon.accuracy) / 1000.0
	var look_transform = npc.global_transform.looking_at(target_chest, Vector3.UP)
	var forward_basis = look_transform.basis
	
	var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
	var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
	var direction = base_direction + Vector3(accuracy_x, accuracy_y, 0) * forward_basis
	var velocity = direction * weapon.projectile_speed
	
	if direction.is_equal_approx(Vector3.UP) or direction.is_equal_approx(Vector3.DOWN):
		projectile.look_at(projectile.global_position + direction, Vector3.FORWARD)
	else:
		projectile.look_at(projectile.global_position + direction, Vector3.UP)

	# Clean injection directly hitting your Projectile.gd setup script parameters method loop!
	projectile.setup(velocity, weapon.damage)

## Called placeholder route by combat_reload_state.gd when magazines drop empty
func npc_reload_weapon() -> void:
	print("🔊 [NPC WEAPON CONTROLLER] Executing reload cell audio clicks.")
