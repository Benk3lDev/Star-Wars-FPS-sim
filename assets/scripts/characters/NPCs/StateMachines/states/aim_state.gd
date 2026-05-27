extends Node

var npc : NPC

func _on_aim_state_entered() -> void:
	print("Combat Aim")
	npc.anim_prefix = "idleaim"
