class_name PlayerController extends CharacterBody3D

# Export a variable to adjust sensitivity from the editor
@export var debug : bool = false
@export var crouch_height : float = 1
@export var stand_height : float = 2
@export_category("References")
@export var camera : CameraController
@export var state_chart : StateChart
@export var camera_effects : CameraEffects
@export var weapon_controller : WeaponController
@export var step_handler : StepHandlerComponent
@export_category("Movement Settings")
@export_group("Easing")
@export var acceleration : float = .2
@export var deceleration : float = .5
@export_group("Speed")
@export var default_speed : float = 5
@export var walk_speed : float = 3
@export var crouch_speed : float = 2
@export var sprint_speed : float = 6.5
var current_speed_modifier = 0
@export_category("Jump Settings")
@export var jump_velocity : float = 4.5
@export var fall_velocity_threshold : float = -5.0


@onready var standing_collision = $StandingCollision
@onready var crouching_collision = $CrouchingCollision
@onready var crouch_check = $CrouchCheck
@onready var lean_check = $LeanCheck
@onready var interaction_raycast = $CameraController/Camera3D/InteractionRaycast


var _input_dir : Vector2 = Vector2.ZERO
var _movement_velocity : Vector3 = Vector3.ZERO
var target_lean : float = 0.0
var can_lean : bool
var is_move : bool
var is_crouch : bool
var current_fall_velocity : float
var previous_velocity : Vector3

# Get gravity from project settings to keep consistent
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	InventoryGlobal.set_player_reference(self)


func crouch() -> void:
	is_crouch = true
	current_speed_modifier = crouch_speed
	standing_collision.disabled = true
	crouching_collision.disabled = false

func stand() -> void:
	is_crouch = false
	current_speed_modifier = default_speed
	standing_collision.disabled = false
	crouching_collision.disabled = true

func jog():
	current_speed_modifier = default_speed

func walk():
	current_speed_modifier = walk_speed

func sprint():
	current_speed_modifier = sprint_speed

func jump() -> void:
	velocity.y += jump_velocity

func check_fall_speed() -> bool:
	if current_fall_velocity < fall_velocity_threshold:
		current_fall_velocity = 0.0
		return true
	else:
		current_fall_velocity
		return false


func _unhandled_input(event: InputEvent):
	# Hotbar scroll select
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventoryGlobal.set_active_slot(InventoryGlobal.active_slot_index - 1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventoryGlobal.set_active_slot(InventoryGlobal.active_slot_index + 1)
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			InventoryGlobal.set_active_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			InventoryGlobal.set_active_slot(9)


func _input(event: InputEvent) -> void:

# Leaning
	# Lean Check
	if is_crouch and not lean_check.is_colliding():
		can_lean = true
	elif not is_move and not lean_check.is_colliding():
		can_lean = true
	else:
		can_lean = false
	# Set target_lean
	if Input.is_action_pressed("lean_left") and can_lean:
		target_lean = -1.0
	elif Input.is_action_pressed("lean_right") and can_lean:
		target_lean = 1.0
	else:
		target_lean = 0.0

	if event.is_action_pressed("ui_inventory"):
		InventoryGlobal.ui_node.visible = !InventoryGlobal.ui_node.visible
		
		get_tree().paused = !get_tree().paused
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_rotation(rotation_input) -> void:
	global_transform.basis = Basis.from_euler(rotation_input)


func _physics_process(delta):
	previous_velocity = velocity
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Get input direction
	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Calculate movement relative to the player's current rotation
	var current_velocity = Vector2(_movement_velocity.x, _movement_velocity.z)
	var direction = (transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)).normalized()
	
	var CURRENT_SPEED = current_speed_modifier
	
	if direction:
		is_move = true
		current_velocity = lerp(current_velocity, Vector2(direction.x, direction.z) * CURRENT_SPEED, acceleration)
	else:
		is_move = false
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration)

	_movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)
	
	velocity = _movement_velocity

	move_and_slide()

	if is_on_floor():
		step_handler.handle_step_climbing()

func get_input_direction() -> Vector2:
	return _input_dir
