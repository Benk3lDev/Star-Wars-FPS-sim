class_name CloneTrooper extends Enemy


@export var health_component : HealthComponent
@onready var state_chart : StateChart = $StateChart
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	super._ready()
	health_component.died.connect(_on_death)


func _on_death() -> void:
	print("Clone Trooper defeated!")
	queue_free()
