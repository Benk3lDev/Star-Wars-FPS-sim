class_name GameManager extends Node

enum Faction {
	REPUBLIC,
	CIS,
	PLF,
	CIVILIAN,
	MERC,
}

func _ready() -> void:
	add_to_group("game_manager")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_exit"):
		get_tree().quit()
	if event.is_action_pressed("dev_reload"):
		get_tree().reload_current_scene()
