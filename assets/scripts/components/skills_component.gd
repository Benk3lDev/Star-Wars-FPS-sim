class_name SkillsComponent extends Node

@export var attributes : AttributesComponent
@export var skills_list : Array[SkillData] = []
@export var is_cybernetic : bool

var skills : Dictionary = {}

var max_hp : int
var hp_boost : float
var max_stamina : int
var stamina_regen : float
var stamina_depletion_mult : float = 1.0
var max_cybernetic_mana : int
var cm_boost : float
var shock_dam_res : float
var blaster_dam_res : float 
var bullet_dam_res : float
var phys_dam_res : float
var explosive_dam_res : float
var poison_dam_res : float
var sprint_speed : float
var crouch_speed : float

func initialize_skills() -> void:
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
		push_error("SkillsComponent failed to calculate: character_attributes is missing!")
		return
	
	# Fetch dynamic values using your automated method to verify key integrity on startup
	var medical_total = get_weapon_skill_total("medical_skill")
	var mechanics_total = get_weapon_skill_total("mechanics_skill")
	var stealth_total = get_weapon_skill_total("stealth_skill")
	
	var vit_bonus = (5.0 / 2.0) * attrs.vitality
	max_hp = 200 + int(vit_bonus * vit_bonus)
	
	hp_boost = (float(medical_total) / 100.0) + 1.0
	
	var const_bonus = 2 * (attrs.constitution - 1)
	max_stamina = 100 + (const_bonus * const_bonus)
	stamina_regen = 2 * attrs.vitality
	stamina_depletion_mult = 1.0 - (attrs.vitality * 0.05)
	
	if is_cybernetic:
		max_cybernetic_mana = 100 + (attrs.intelligence * 10)
		cm_boost = 1.0 + (float(mechanics_total) * 0.1)
	
	# Fetch stealth total or fallback dexterity attributes smoothly
	var dexterity_stat = float(attrs.dexterity)
	sprint_speed = 6.0 + ((dexterity_stat - 1.0) * 0.1)
	crouch_speed = 2.0 + (dexterity_stat * 0.01)


## THE UNIVERSAL BRIDGE: Keep this exactly as you have it established!
func get_weapon_skill_total(skill_key: String) -> int:
	if not attributes or not attributes.character_attributes:
		return 0
		
	# Verify that the key requested exists in our active skill registry dictionary
	if skills.has(skill_key) and skills[skill_key] != null:
		var skill_resource = skills[skill_key]
		if skill_resource.has_method("get_total_value"):
			return int(skill_resource.get_total_value(attributes.character_attributes))
			
	return 0
