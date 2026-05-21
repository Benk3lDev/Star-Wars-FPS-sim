class_name NPC extends CharacterBody3D


@export var attributes : AttributesComponent
@export var visual_data : NPCVisuals
@export var health_component : HealthComponent

@onready var state_chart : StateChart = $StateChart
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var sprite : AnimatedSprite3D = $SpriteAnchor/AnimatedSprite3D

const DIR_NAMES = ["_front", "_front_left", "_left", "_rear_left", "_rear", "_rear_right", "_right", "_front_right"]

func _ready() -> void:
	health_component.died.connect(_on_death)
	if visual_data and visual_data.sprite_frames:
		sprite.sprite_frames = visual_data.sprite_frames


func _process(_delta: float) -> void:
	# Keep calculating looking angles relative to player camera every frame
	if is_instance_valid(sprite) and sprite.sprite_frames:
		update_billboard_animation()

func update_billboard_animation() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	# 1. Vector from NPC to Player Camera (flattened horizontally)
	var direction_to_cam = (camera.global_position - global_position)
	direction_to_cam.y = 0.0
	direction_to_cam = direction_to_cam.normalized()
	
	# 2. Vector of where the NPC is currently facing forward (Negative global Z)
	var npc_forward = -global_transform.basis.z
	npc_forward.y = 0.0
	npc_forward = npc_forward.normalized()
	
	# 3. Calculate signed angle on the Y axis
	var angle = npc_forward.signed_angle_to(direction_to_cam, Vector3.UP)
	if angle < 0:
		angle += TAU
		
	# 4. Snap angles to 8 clean sectors (45-degree steps)
	var dir_index = round(angle / (TAU / 8.0))
	dir_index = int(dir_index) % 8
	
	# 5. Piece together "idle" + the directional suffix (e.g., "idle_front_left")
	var final_anim_name = "idle" + DIR_NAMES[dir_index]
	
	# 6. Play the animation safely
	if sprite.sprite_frames.has_animation(final_anim_name):
		sprite.play(final_anim_name)
	else:
		# Fallback to standard front frame if a direction is missing
		sprite.play("idle_front")


func _on_death() -> void:
	print("NPC killed!")
	queue_free()
