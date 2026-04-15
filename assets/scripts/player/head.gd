class_name CameraController extends Node3D

var sensitivity = 0.2
@export_category("References")
@export var player_controller : PlayerController
@export var component_mouse_capture : MouseCaptureComponent
@export_category("Camera Settings")
@export_group("Camera Tilt")
@export_range(-90, -60) var tilt_lower_limit : int = -90
@export_range(60, 90) var tilt_upper_limit : int = 90

var _rotation : Vector3

@export_category("Leaning Vars")
@export var lean_angle : float = 20
@export var lean_offset : float = 0.25
@export var lean_speed : float = 8
var current_lean : float = 0
@export_group("Crouch Verticle Movement")
@export var crouch_offset : float = 0.0
@export var crouch_speed : float = 3.0
@export_group("Step Smoothing")
@export var step_speed : float = 8.0

var _target_height : float
var _step_smoothing: bool = false

var offset_height : float

const DEFAULT_HEIGHT : float = 0.5


func _ready() -> void:
	_rotation = player_controller.rotation
	offset_height = DEFAULT_HEIGHT

func _process(delta: float) -> void:
	update_camera_rotation(component_mouse_capture._mouse_input, delta)
	
	# Head lean
	current_lean = lerp(current_lean, player_controller.target_lean, delta * lean_speed)
	
	var target_tilt : float = deg_to_rad(-lean_angle) * current_lean
	var target_offset : float = lean_offset * current_lean

	rotation.z = lerp(rotation.z, target_tilt, delta * lean_speed)
	position.x = lerp(position.x, target_offset, delta * lean_speed)


	
	if _step_smoothing:
		_target_height = lerp(_target_height, 0.0, step_speed * delta)
		if abs(_target_height) < 0.01:
			_target_height = 0.0
			_step_smoothing = false
		
		position.y = offset_height + _target_height


func update_camera_rotation(input: Vector2, delta) -> void:
	_rotation.x += input.y
	_rotation.y += input.x
	_rotation.x = clamp(_rotation.x, deg_to_rad(tilt_lower_limit), deg_to_rad(tilt_upper_limit))

	var _player_rotation = Vector3(0.0, _rotation.y ,0.0)
	var _camera_rotation = Vector3(_rotation.x, 0.0, 0.0)

	transform.basis = Basis.from_euler(_camera_rotation)
	player_controller.update_rotation(_player_rotation)

	rotation.z = 0.0


func update_camera_height(delta: float, direction: int) -> void:
	if position.y >= crouch_offset and position.y <= DEFAULT_HEIGHT:
		position.y = clampf(position.y + (crouch_speed * direction) * delta, crouch_offset, DEFAULT_HEIGHT)

	if offset_height >= crouch_offset and offset_height <= DEFAULT_HEIGHT:
		offset_height = clampf(offset_height + (crouch_speed * direction) * delta, crouch_offset, DEFAULT_HEIGHT)


func smooth_step(height_change : float):
	_target_height -= height_change
	_step_smoothing = true
