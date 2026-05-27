extends Node


var npc : NPC



func _on_fire_state_entered() -> void:
	npc.anim_prefix = "shooting"
