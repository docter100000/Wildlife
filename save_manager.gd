extends Node

const SAVE_PATH = "user://terrain_save.dat"

# Flag used to tell the main game scene whether it should load the save file upon starting
var should_load_on_start: bool = false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_terrain(vertices: PackedVector3Array) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Convert the array of vectors into an optimized binary blob
		var bytes = var_to_bytes(vertices)
		file.store_buffer(bytes)
		file.close()
		print("Terrain saved successfully!")

func load_terrain() -> PackedVector3Array:
	if not has_save():
		return PackedVector3Array()
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var bytes = file.get_buffer(file.get_length())
		file.close()
		
		# Decode the binary blob back into a Godot Vector3 Array
		var vertices = bytes_to_var(bytes)
		if typeof(vertices) == TYPE_PACKED_VECTOR3_ARRAY:
			print("Terrain loaded successfully!")
			return vertices
			
	return PackedVector3Array()
