extends Node
class_name NPCStateMachine

# Expose state scripts anchor point if needed for external lookups
@onready var state_scripts = $StateScripts

var npc: NPC

func _ready() -> void:
	# No longer need injection loops here!
	# initialize_with_npc() completely handles everything before frame one.
	if not is_instance_valid(npc):
		push_error("MovementStateMachine was instantiated without calling initialize_with_npc() first!")
	

## Forces immediate parent injection before scene tree entry or _ready() signals fire
func initialize_with_npc(parent_npc: NPC) -> void:
	npc = parent_npc
	_initialize_states_recursive(self, parent_npc)

## Deep-tree scanner: Automatically injects the NPC reference to any depth of your nested folders
func _initialize_states_recursive(current_node: Node, parent_npc: NPC) -> void:
	for child in current_node.get_children():
		# Safely duck-types to verify if the script node uses an 'npc' property
		if "npc" in child:
			child.npc = parent_npc
			
		# Keeps digging downward through your nested compound layers
		if child.get_child_count() > 0:
			_initialize_states_recursive(child, parent_npc)
