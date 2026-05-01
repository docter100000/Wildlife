extends Node

const SAVE_PATH = "user://terrain_save.dat"

# Flag used to tell the main game scene whether it should load the save file upon starting
var should_load_on_start: bool = false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(terrain_verts: PackedVector3Array, debris_data: Array) -> void:
	var save_dict = {
		"terrain": terrain_verts,
		"debris": debris_data
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Convert the dictionary into an optimized binary blob
		var bytes = var_to_bytes(save_dict)
		file.store_buffer(bytes)
		file.close()
		print("Game saved successfully!")

func load_game() -> Dictionary:
	if not has_save():
		return {}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var bytes = file.get_buffer(file.get_length())
		file.close()
		
		# Decode the binary blob back into a Godot variable
		var data = bytes_to_var(bytes)
		
		# Backwards compatibility: old saves were just PackedVector3Array
		if typeof(data) == TYPE_PACKED_VECTOR3_ARRAY:
			print("Old save format loaded successfully!")
			return { "terrain": data, "debris": [] }
			
		elif typeof(data) == TYPE_DICTIONARY:
			print("Game loaded successfully!")
			return data
			
	return {}
