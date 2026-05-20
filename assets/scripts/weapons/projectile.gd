class_name Projectile extends Area3D

var velocity: Vector3
var damage: float

var has_impacted : bool = false

func _ready() -> void:
	# Keep this as a fallback for slower/larger objects or environment hits
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if has_impacted:
		return
		
	var space_state = get_world_3d().direct_space_state
	var start_pos = global_position
	var end_pos = global_position + velocity * delta

	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)

	if result:
		global_position = result.position
		# Extract the hit shape index from the raycast data dictionary safely
		var shape_id = result.get("shape", -1)
		_on_hit_detected(result.collider, shape_id)
		return

	global_position = end_pos


func setup(vel: Vector3, dmg: float) -> void:
	velocity = vel
	damage = dmg


# Standard body entered callback for environment hits
func _on_body_entered(body: Node3D) -> void:
	_on_hit_detected(body, -1)


# New consolidated hit logic that handles the body shape
func _on_hit_detected(body: Node3D, shape_id: int) -> void:
	if has_impacted:
		return
	has_impacted = true
	
	print("Projectile hit: ", body.name, " at ", global_position, " | Shape ID: ", shape_id)
	_spawn_impact_marker(global_position)
	
	var health = body.get_node_or_null("Components/HealthComponent") as HealthComponent
	if not health:
		health = body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		# Pass null for the source parameter so shape_id fills the 4th argument slot
		health.take_damage(int(damage), "blaster", null, shape_id)
	
	queue_free()


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
