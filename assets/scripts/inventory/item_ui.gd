extends TextureRect

var item_data : ItemData


func update_visuals():
	if item_data:
		texture = item_data.icon
		var display_width = item_data.width
		var display_height = item_data.height
		if item_data.is_rotated:
			display_width = item_data.height
			display_height = item_data.width
