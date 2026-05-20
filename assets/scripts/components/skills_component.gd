class_name SkillsComponent extends Node


@export var attributes : AttributesComponent
@export var skills_list : Array[SkillData] = []

@export var is_cybernetic : bool

var skills : Dictionary = {}

var max_hp : int
var hp_boost : float# multiplier for using health items
var max_stamina : int
var stamina_regen : float#multiplier for regenerating stamina
var stamina_depletion_mult : float = 1.0
var max_cybernetic_mana : int
var cm_boost : float# multiplier for using cybernetic mana items
var shock_dam_res : float# shock/electrical damage resistance
var blaster_dam_res : float # blaster damage resistance
var bullet_dam_res : float# sluglugger damage resistance
var phys_dam_res : float# melee damage resistance
var explosive_dam_res : float
var poison_dam_res : float
var sprint_speed : float
var crouch_speed : float


func _ready() -> void:
	skills.clear()
	for skill in skills_list:
		if skill and skill.skill_id != "":
			skills[skill.skill_id] = skill
		else:
			push_warning("Found an empty slot or missing skill_id in skills_list!")
	
	recalculate_all_stats()


func recalculate_all_stats() -> void:
	var attrs = attributes.character_attributes
	if not attrs:
		return
	
	var light_blaster_total = skills["light_blasters_skill"].get_total_value(attrs)
	var heavy_blaster_total = skills["heavy_blasters_skill"].get_total_value(attrs)
	var melee_total = skills["melee_skill"].get_total_value(attrs)
	var explosives = skills["explosives_skill"].get_total_value(attrs)
	var mechanics = skills["mechanics_skill"].get_total_value(attrs)
	var splicing = skills["splicing_skill"].get_total_value(attrs)
	var medical = skills["medical_skill"].get_total_value(attrs)
	var stealth = skills["stealth_skill"].get_total_value(attrs)
	
	# HP Setup
	var vit_bonus = (5.0 / 2.0) * attrs.vitality
	max_hp = 200 + int(vit_bonus * vit_bonus)
	
	hp_boost = (medical / 100) + 1
	
	# Stamina Setup
	var const_bonus = 2 * (attrs.constitution - 1)
	max_stamina = 100 + (const_bonus * const_bonus)
	
	stamina_regen = 2 * attrs.vitality
	
	stamina_depletion_mult = 1.0 - (attrs.vitality * 0.05)
	
	# CM Setup
	if is_cybernetic:
		max_cybernetic_mana = 100 + (attrs.intelligence * 10)
		
		cm_boost = 1 + (mechanics * 0.1)
	
	# Movement Speed
	sprint_speed = 6.0 + ((attrs.dexterity - 1) * 0.1)
	crouch_speed = 2.0 + (attrs.dexterity * 0.01)
