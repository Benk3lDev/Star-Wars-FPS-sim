class_name SquadComponent extends Node

enum Rank { REGULAR, CORPORAL, SERGEANT, LIEUTENANT }

@export_category("Chain of Command")
@export var character_rank : Rank = Rank.REGULAR
@export var commanding_lieutenant : NPC = null
@export var squad_sergeant : NPC = null
@export var squad_corporal : NPC = null

# Runtime dynamic tracking
var squad_members : Array[NPC] = []
var has_called_for_help : bool = false

func _ready() -> void:
	call_deferred("_register_squad")

func _register_squad() -> void:
	var my_npc = get_parent() as NPC
	if not is_instance_valid(my_npc) or character_rank == Rank.LIEUTENANT: 
		return
		
	# Find physical comrades already placed in the world grid tree
	var all_actors = get_tree().get_nodes_in_group("actors")
	for actor in all_actors:
		if actor is NPC and actor != my_npc:
			var other_squad = actor.get_node_or_null("SquadComponent")
			if not other_squad:
				other_squad = actor.get_node_or_null("Components/SquadComponent")
				
			# Group together if we share the exact same physical squad sergeant!
			if other_squad and other_squad.squad_sergeant == squad_sergeant and squad_sergeant != null:
				squad_members.append(actor)
				
	squad_members.append(my_npc)

func get_active_commander() -> NPC:
	if is_instance_valid(squad_sergeant) and not squad_sergeant.is_dead:
		return squad_sergeant
	if is_instance_valid(squad_corporal) and not squad_corporal.is_dead:
		return squad_corporal
	return null

func evaluate_squad_wipe_threshold() -> bool:
	if squad_members.size() <= 1: return true
	var dead_count : float = 0.0
	for member in squad_members:
		if not is_instance_valid(member) or member.is_dead:
			dead_count += 1.0
	return (dead_count / float(squad_members.size())) >= 0.60
