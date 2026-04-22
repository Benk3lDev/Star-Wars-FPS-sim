extends Control

@onready var grid_container = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

@export var slot_scene : PackedScene
@export var dimensions : Vector2i

var grid_array := []


func _ready():
	for child in grid_container.get_children():
		child.queue_free()
	
	var total_slots = dimensions.x * dimensions.y
	InventoryGlobal.inventory.resize(total_slots)
	
	for i in range(total_slots):
		create_slot()


func create_slot():
	grid_container.columns = dimensions.x

	var new_slot = slot_scene.instantiate()
	grid_container.add_child(new_slot)
	new_slot.slot_entered.connect(_on_slot_mouse_entered)
	new_slot.slot_exited.connect(_on_slot_mouse_exited)


func _on_slot_mouse_entered(a_Slot):
	a_Slot.set_color(a_Slot.States.TAKEN)


func _on_slot_mouse_exited(a_Slot):
	a_Slot.set_color(a_Slot.States.DEFAULT)
