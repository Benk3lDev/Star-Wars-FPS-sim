class_name NPC extends CharacterBody3D

@export var attributes : AttributesComponent
@export var npc_resource : NPCResource 
@export var health_component : HealthComponent
@export var inventory_data : NPCInventoryData

# Centralized perception metrics
@export_group("AI Perception")
@export var max_sight_distance: float = 20.0
@export_range(0.0, 360.0) var field_of_view: float = 90.0

@export_group("AI Alert Parameters")
## The coordinates the AI will walk toward to investigate a threat
var alert_target_position: Vector3 = Vector3.ZERO
## Tracks if we are currently performing the regional search loop
var is_searching_alert_zone: bool = false

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
@onready var weapon_controller : Node = $NPCWeaponController

# Active runtime components
var active_sm: Node = null
var state_chart: StateChart = null
var current_combat_target: CharacterBody3D = null
var is_dead: bool = false
var true_faction : GameManager.Faction
var faction : GameManager.Faction
var active_weapon_item : ItemData = null
var active_weapon_stats : Weapon = null
var current_ammo: int = 0

#animation components
var anim_prefix : String
const DIR_NAMES = ["_front", "_front_left", "_left", "_rear_left", "_rear", "_rear_right", "_right", "_front_right"]

func _ready() -> void:
	add_to_group("actors")
	
	if health_component:
		health_component.died.connect(_on_death)
		
	if npc_resource and npc_resource.sprite_frames:
		sprite.sprite_frames = npc_resource.sprite_frames

	# --- UNIFIED INVENTORY PARSING REGION ---
	if inventory_data:
		# Deep duplicate ensures unique runtime counters for individual enemy copies
		inventory_data = inventory_data.duplicate(true)
		
		# Find our gun item in the container array
		active_weapon_item = inventory_data.get_first_weapon_item()
		
		if active_weapon_item:
			# Unnest the embedded weapon stats resource block
			active_weapon_stats = active_weapon_item.weapon_stats
			
			# Pull baseline runtime stats (like ammo) from either item variable fields or weapons
			current_ammo = active_weapon_stats.max_ammo
			
			print("🎒 [INVENTORY] NPC '", name, "' equipped: ", active_weapon_stats.weapon_name)
			print("   -> Target Shooting Range: ", active_weapon_stats.range, "m | Initial Magazine: ", current_ammo)
		else:
			print("🎒 [INVENTORY] NPC '", name, "' spawned completely unarmed.")

	# Chronological pipeline initializers
	_execute_npc_stat_pipeline()
	initialize_modular_behavior()


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
