@tool
class_name NPC extends CharacterBody3D

@export var attributes : AttributesComponent
@export var npc_resource : NPCResource 
@export var health_component : HealthComponent
@export var skills_component : SkillsComponent
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

# --- SHIFTED SQUAD RANK SETTINGS (ROOT SCOPE) ---
enum Rank { REGULAR, CORPORAL, SERGEANT, LIEUTENANT }
@export_group("Chain of Command")
@export var character_rank : Rank = Rank.REGULAR
@export var holds_defensive_tactics : bool = true

# INSPECTOR CONFIGURATORS (The Paths)
# These expose path pickers in the inspector for local instance overrides!
@export var commanding_lieutenant_path : NodePath
@export var squad_sergeant_path : NodePath
@export var squad_corporal_path : NodePath

# RUNTIME DATA REGISTRIES (The True Objects)
# Other scripts will query these cached variables during gameplay frames
var commanding_lieutenant : NPC = null
var squad_sergeant : NPC = null
var squad_corporal : NPC = null

# 1. Define the macro states (Matched AT_EASE from your enum layout)
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

# Animation components
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
		inventory_data = inventory_data.duplicate(true)
		active_weapon_item = inventory_data.get_first_weapon_item()
		
		if active_weapon_item:
			active_weapon_stats = active_weapon_item.weapon_stats
			current_ammo = active_weapon_stats.max_ammo
			
			print("🎒 [INVENTORY] NPC '", name, "' equipped: ", active_weapon_stats.weapon_name)
			print("   -> Target Shooting Range: ", active_weapon_stats.range, "m | Initial Magazine: ", current_ammo)
		else:
			print("🎒 [INVENTORY] NPC '", name, "' spawned completely unarmed.")

	# --- RANK DATA LAYER SYNCHRONIZATION ---
	_synchronize_squad_component_data()

	# Chronological pipeline initializers
	_execute_npc_stat_pipeline()
	initialize_modular_behavior()


func _execute_npc_stat_pipeline() -> void:
	if not attributes or not attributes.character_attributes:
		push_error("NPC Pipeline Broken: Attributes Component or data resource is missing!")
		return
	
	if is_instance_valid(skills_component):
		skills_component.attributes = attributes 
		skills_component.initialize_skills()     
	else:
		push_error("NPC Pipeline Broken: SkillsComponent node could not be found!")
		return
		
	if is_instance_valid(health_component):
		health_component.skills_component = skills_component 
		health_component.initialize_health()
	else:
		push_error("NPC Pipeline Broken: HealthComponent node is missing or unassigned!")


func initialize_modular_behavior() -> void:
	if state_machine_scene:
		active_sm = state_machine_scene.instantiate()
		if active_sm.has_method("initialize_with_npc"):
			active_sm.initialize_with_npc(self)
		add_child(active_sm)
		state_chart = active_sm.get_node("StateChart")


func _process(delta: float) -> void:
	if is_dead: return
	
	if is_instance_valid(sprite) and sprite.sprite_frames:
		update_billboard_animation()
		
	if behavior_profile and state_chart and is_instance_valid(vision):
		behavior_profile.evaluate_behavior(self, vision, state_chart)


## Automatically enforces root inspector rank selections down to your component logic
func _synchronize_squad_component_data() -> void:
	# 1. Resolve NodePath configurations into real memory objects
	if commanding_lieutenant_path:
		commanding_lieutenant = get_node_or_null(commanding_lieutenant_path) as NPC
	if squad_sergeant_path:
		squad_sergeant = get_node_or_null(squad_sergeant_path) as NPC
	if squad_corporal_path:
		squad_corporal = get_node_or_null(squad_corporal_path) as NPC

	# 2. Grab the child SquadComponent node
	var squad_comp = get_node_or_null("SquadComponent")
	if not squad_comp:
		squad_comp = get_node_or_null("Components/SquadComponent")
		
	if is_instance_valid(squad_comp):
		# Push our root inspector rank setting onto the component logic variable
		squad_comp.character_rank = int(character_rank)
		
		# PUSH RESOLVED TEMPLATE LINK DATA DOWNWARDS
		squad_comp.commanding_lieutenant = commanding_lieutenant
		squad_comp.squad_sergeant = squad_sergeant
		squad_comp.squad_corporal = squad_corporal
		
		print("🎖️ [NPC ROOT] Initialized '", name, "' as rank: ", Rank.keys()[character_rank])
		
		# Regular grunts don't engage separate defensive hold mechanics, only leadership does
		if character_rank == Rank.REGULAR:
			holds_defensive_tactics = false


# =================================================================
# CHAIN OF COMMAND COMMUNICATIONS NETWORK Channels
# =================================================================

## Executed when an individual squad soldier reports an active target contact up to their supervisor
func receive_trooper_tactical_report(spotted_threat: CharacterBody3D) -> void:
	if is_dead: return
	
	# The leader locks on defensively right on the frame of report
	if not is_instance_valid(current_combat_target):
		current_combat_target = spotted_threat
		alert_target_position = spotted_threat.global_position
		if is_instance_valid(state_chart): 
			state_chart.send_event("OnAlerted")
		
	print("🎖️ [SQUAD COMMAND] Leader '", name, "' acknowledging contact report! Ordering squad deployment.")
	
	# Group Alert Broadcast: Force the rest of the local platoon room to raise weapons
	var my_squad = get_node_or_null("SquadComponent")
	if not my_squad: 
		my_squad = get_node_or_null("Components/SquadComponent")
	
	if my_squad:
		for member in my_squad.squad_members:
			if is_instance_valid(member) and not member.is_dead and member != self:
				if not is_instance_valid(member.current_combat_target):
					member.current_combat_target = spotted_threat
					member.alert_target_position = spotted_threat.global_position
					# Force-alert your troopers if they are still pacing peacefully
					if is_instance_valid(member.state_chart) and member.current_macro_state == MacroState.AT_EASE:
						member.state_chart.send_event("OnAlerted")


## Executed via comm frequencies when a sub-squad Sergeant triggers a 60% wipe casualty event
func receive_sergeant_distress_call(player_target: CharacterBody3D) -> void:
	if is_dead: 
		print("📡 [CHAIN OF COMMAND] Call failed: Lieutenant '", name, "' is KIA!")
		return
	
	if character_rank != Rank.LIEUTENANT:
		return
		
	print("🎖️ [LIEUTENANT COMMAND] Lieutenant '", name, "' broadcasting reinforcement orders to operational squads.")
	
	if current_macro_state != MacroState.COMBAT and is_instance_valid(state_chart):
		current_combat_target = player_target
		alert_target_position = player_target.global_position
		state_chart.send_event("OnCombat")

	# SCAN CHANNELS: Check every active actor currently loaded into the simulation
	var all_actors = get_tree().get_nodes_in_group("actors")
	for actor in all_actors:
		if actor is NPC and actor != self and not actor.is_dead:
			
			var other_squad = actor.get_node_or_null("SquadComponent")
			if not other_squad:
				other_squad = actor.get_node_or_null("Components/SquadComponent")
			
			# 1. Check if the clone belongs to this Lieutenant's command division
			if other_squad and other_squad.commanding_lieutenant == self:
				
				# 2. THE CHAIN OF COMMAND FILTER RULE:
				# Check if this clone's specific squad still has an active leader alive!
				if other_squad.has_qualifying_squad_leader():
					# If their leadership is intact and they are sitting at ease, order deployment!
					if actor.current_macro_state == MacroState.AT_EASE:
						print("🚀 [LIEUTENANT BROADCAST] Dispatching operational trooper: ", actor.name)
						
						actor.current_combat_target = player_target
						actor.alert_target_position = player_target.global_position
						
						if is_instance_valid(actor.state_chart):
							actor.state_chart.send_event("OnCombat")
				else:
					# If the Sergeant and Corporal of this specific squad are dead, 
					# they are cut off from the network and will not receive the order!
					if Engine.get_process_frames() % 120 == 0: # Throttle logs so they don't spam
						print("🔇 [LIEUTENANT BROADCAST] Squad link severed for: '", actor.name, "'. Leadership KIA. Order ignored.")


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
		var simple_fallback = lookup_prefix + "_front"
		if sprite.sprite_frames.has_animation(simple_fallback):
			sprite.play(simple_fallback)


func _on_death() -> void:
	is_dead = true
	if is_instance_valid(sprite) and sprite.sprite_frames.has_animation("death-fromFront_front"):
		sprite.play("death-fromFront_front")
