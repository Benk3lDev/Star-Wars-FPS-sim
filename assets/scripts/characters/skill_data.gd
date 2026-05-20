class_name SkillData extends Resource

@export var skill_id : String
@export var skill_name: String
@export var allocated_points: int = 0

# Which attributes influence this skill?
@export var primary_attribute: String = ""
@export var secondary_attribute: String = ""

# How much weight do the attributes have? (e.g., 2 points per Dex)
@export var primary_multiplier: float = 2.0
@export var secondary_multiplier: float = 1.0

# Calculate total value dynamically
func get_total_value(char_attrs: CharacterAttributes) -> int:
	var total = allocated_points
	
	if char_attrs and primary_attribute in char_attrs:
		total += int(char_attrs.get(primary_attribute) * primary_multiplier)
		
	if char_attrs and secondary_attribute != "" and secondary_attribute in char_attrs:
		total += int(char_attrs.get(secondary_attribute) * secondary_multiplier)
		
	return clamp(total, 0, 100)
