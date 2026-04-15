class_name Weapon extends Resource

@export var weapon_name: String = "Pistol"
@export var damage: float = 25.0
@export var max_ammo: int = 12
@export var fire_rate: float = 2.0
@export var is_automatic: bool = false
@export var range: float = 25.0
@export_range(0, 100) var accuracy: int = 100
@export var projectile_speed: float = 50.0
@export var is_hit_scan: bool = true
@export var weapon_model: PackedScene
@export var projectile_scene: PackedScene
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0
@export var weapon_position: Vector3 = Vector3(0.2, -0.2, -0.3)
