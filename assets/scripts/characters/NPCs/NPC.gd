class_name NPC extends CharacterBody3D

@export var attributes : AttributesComponent
@export var npc_resource : NPCResource 
@export var health_component : HealthComponent
@export var inventory_data : NPCInventoryData

# Centralized perception metrics
@export_group("AI Perception")
@export var max_sight_distance: float = 20.0
@export_range(0.0, 360.0) var field_of_view: float = 90.0

@export_group("AI Behavior")
@export var behavior_profile: NPCBehaviorProfile
@export var state_machine_scene: PackedScene

@export_group("Modular Patrol Settings")
## Drag and drop Marker3D nodes from your level scene here to build a custom loop path.
## If left completely empty, this specific NPC will patrol randomly around its spawn.
@export var custom_waypoints: Array[NodePath] = []
@export var random_patrol_radius: float = 6.0

# 1. Define the macro states
enum MacroState { AT_EASE, ALERTED, COMBAT }

# 2. Track the active state
var current_macro_state: MacroState = MacroState.AT_EASE

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var sprite : AnimatedSprite3D = $SpriteAnchor/AnimatedSprite3D
@onready var vision : NPCVisionSensor = $NPCVisionSensor

# Active runtime components
var active_sm: Node = null
var state_chart: StateChart = null
var current_combat_target: CharacterBody3D = null
var is_dead: bool = false

#animation components
var anim_prefix : String
const DIR_NAMES = ["_front", "_front_left", "_left", "_rear_left", "_rear", "_rear_right", "_right", "_front_right"]

func _ready() -> void:
	add_to_group("actors")
	
	if health_component:
		health_component.died.connect(_on_death)
		
	if npc_resource and npc_resource.sprite_frames:
		sprite.sprite_frames = npc_resource.sprite_frames
		
	if inventory_data:
		inventory_data = inventory_data.duplicate()

	# Enforce a strict chronological initialization sequence
	_execute_npc_stat_pipeline()
	
	# Instantiate state machines only AFTER core data metrics are fully built
	initialize_modular_behavior()
	
	print("🌍 [MAP DIAGNOSTIC] Current World 3D Navigation Map RID: ", get_world_3d().get_navigation_map())
	print("🤖 [MAP DIAGNOSTIC] Agent Navigation Map RID: ", nav_agent.get_navigation_map())


func _execute_npc_stat_pipeline() -> void:
	# Step 1: Ensure the baseline attributes component has its data ready
	if not attributes or not attributes.character_attributes:
		push_error("NPC Pipeline Broken: Attributes Component or data resource is missing!")
		return
		
	# Step 2: Grab the skills component child node
	var skills_component = get_node_or_null("SkillsComponent")
	
	# Step 3: Command Skills to run calculations from the bound Attributes
	if is_instance_valid(skills_component):
		skills_component.attributes = attributes # Explicit link verification
		skills_component.initialize_skills()     # Run recalculate_all_stats()
	else:
		push_error("NPC Pipeline Broken: SkillsComponent node could not be found!")
		return
		
	# Step 4: Command Health to bind the final calculation results from Skills
	if is_instance_valid(health_component):
		health_component.skills_component = skills_component # Explicit link verification
		health_component.initialize_health()
	else:
		push_error("NPC Pipeline Broken: HealthComponent node is missing or unassigned!")

func initialize_modular_behavior() -> void:
	if state_machine_scene:
		active_sm = state_machine_scene.instantiate()
		# INJECT FIRST: Pass the parent NPC reference downwards BEFORE adding to child tree
		if active_sm.has_method("initialize_with_npc"):
			active_sm.initialize_with_npc(self)
		add_child(active_sm)
		state_chart = active_sm.get_node("StateChart")
		


func _process(delta: float) -> void:
	if is_dead: return
	
	if is_instance_valid(sprite) and sprite.sprite_frames:
		update_billboard_animation()
		
	# Weapon chart is now optional! The AI only needs a behavior profile, movement chart, and vision.
	if behavior_profile and state_chart and is_instance_valid(vision):
		behavior_profile.evaluate_behavior(self, vision, state_chart)


func update_billboard_animation() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera: return
		
	var direction_to_cam = (camera.global_position - global_position)
	direction_to_cam.y = 0.0
	direction_to_cam = direction_to_cam.normalized()
	
	var npc_forward = -global_transform.basis.z
	npc_forward.y = 0.0
	npc_forward = npc_forward.normalized()
	
	var angle = npc_forward.signed_angle_to(direction_to_cam, Vector3.UP)
	if angle < 0: angle += TAU
		
	var dir_index = round(angle / (TAU / 8.0))
	dir_index = int(dir_index) % 8
	
	var lookup_prefix = anim_prefix if anim_prefix != "" else "idle"
	var final_anim_name = lookup_prefix + DIR_NAMES[dir_index]
	
	if sprite.sprite_frames.has_animation(final_anim_name):
		sprite.play(final_anim_name)
	else:
		# If "walk_front_left" doesn't exist, try falling back to standard "walk_front"
		var simple_fallback = lookup_prefix + "_front"
		if sprite.sprite_frames.has_animation(simple_fallback):
			sprite.play(simple_fallback)
		else:
			sprite.play("idle_front")

func _on_death() -> void:
	is_dead = true
	sprite.play("death-fromFront_front")
	queue_free()
