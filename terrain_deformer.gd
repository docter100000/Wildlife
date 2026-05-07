extends MeshInstance3D
class_name TerrainDeformer

@export var brush_radius: float = 3.0
@export var brush_strength: float = 0.5

var _array_mesh: ArrayMesh
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _terrain_material: Material

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var _is_digging: bool = false
var _is_raising: bool = false

enum ToolMode { NONE = 0, DIG_RAISE = 1, SMOOTH = 2 }
var active_tool_mode: ToolMode = ToolMode.NONE

func _ready() -> void:
	# Make sure we have a mesh to start with
	if not mesh:
		var plane = PlaneMesh.new()
		plane.size = Vector2(50, 50)
		plane.subdivide_width = 100
		plane.subdivide_depth = 100
		mesh = plane
		
	# Preserve the original material (if any)
	_terrain_material = mesh.surface_get_material(0)
	
	# Convert primitive or other meshes into an ArrayMesh
	var st = SurfaceTool.new()
	st.create_from(mesh, 0)
	var arrays = st.commit_to_arrays()
	
	_array_mesh = ArrayMesh.new()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if _terrain_material:
		_array_mesh.surface_set_material(0, _terrain_material)
		
	self.mesh = _array_mesh
	
	# Setup Collision for Raycasting and Physics
	_static_body = StaticBody3D.new()
	add_child(_static_body)
	_collision_shape = CollisionShape3D.new()
	_static_body.add_child(_collision_shape)
	
	_update_collision()
	
	if SaveManager.should_load_on_start:
		load_from_disk()

func _update_collision() -> void:
	if _array_mesh:
		# create_trimesh_shape() creates a ConcavePolygonShape3D that perfectly fits the terrain
		_collision_shape.shape = _array_mesh.create_trimesh_shape()

func _process(delta: float) -> void:
	if _is_digging or _is_raising:
		_perform_raycast_and_deform(delta)

func _unhandled_input(event: InputEvent) -> void:
	if active_tool_mode == ToolMode.NONE:
		# If no tool is selected, don't allow interactions
		_is_digging = false
		_is_raising = false
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_digging = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_raising = event.pressed

func _perform_raycast_and_deform(delta: float) -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera: 
			return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_length = 1000.0
	var ray_end = ray_origin + ray_dir * ray_length
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result:
		# Check if we hit ourselves (the static body belonging to this terrain)
		if result.collider == _static_body:
			deform_terrain(result.position, _is_raising, delta)

func deform_terrain(global_hit_position: Vector3, raise: bool, delta: float) -> void:
	var local_hit = to_local(global_hit_position)
	
	var arrays = _array_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	
	var modified = false
	var strength = brush_strength * delta
	
	if active_tool_mode == ToolMode.DIG_RAISE:
		if not raise:
			strength = -strength
			
		for i in range(vertices.size()):
			var v = vertices[i]
			var dist = Vector2(v.x, v.z).distance_to(Vector2(local_hit.x, local_hit.z))
			if dist < brush_radius:
				# Create a plateau (flat center) so it doesn't come to a sharp point
				var inner_radius = brush_radius * 0.4
				var falloff = 1.0
				if dist > inner_radius:
					falloff = smoothstep(brush_radius, inner_radius, dist)
					
				vertices[i].y += strength * falloff
				modified = true
				
	elif active_tool_mode == ToolMode.SMOOTH:
		# Pass 1: Find average height of vertices within brush radius
		var total_height = 0.0
		var count = 0
		for i in range(vertices.size()):
			var v = vertices[i]
			var dist = Vector2(v.x, v.z).distance_to(Vector2(local_hit.x, local_hit.z))
			if dist < brush_radius:
				total_height += v.y
				count += 1
				
		if count > 0:
			var avg_height = total_height / float(count)
			# Pass 2: Pull vertices towards the average height
			for i in range(vertices.size()):
				var v = vertices[i]
				var dist = Vector2(v.x, v.z).distance_to(Vector2(local_hit.x, local_hit.z))
				if dist < brush_radius:
					var inner_radius = brush_radius * 0.4
					var falloff = 1.0
					if dist > inner_radius:
						falloff = smoothstep(brush_radius, inner_radius, dist)
					
					# Lerp height towards average, scaled by strength
					var t = clamp(strength * 5.0 * falloff, 0.0, 1.0)
					vertices[i].y = lerp(v.y, avg_height, t)
					modified = true
			
	if modified:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_apply_updated_arrays(arrays)

func _apply_updated_arrays(arrays: Array) -> void:
	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var st = SurfaceTool.new()
	st.create_from(_array_mesh, 0)
	st.generate_normals()
	
	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	
	if _terrain_material:
		_array_mesh.surface_set_material(0, _terrain_material)
	
	_update_collision()

func till_tile(world_pos: Vector3, tile_size: float) -> void:
	var local_hit = to_local(world_pos)
	
	var arrays = _array_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	
	var modified = false
	var radius = tile_size * 0.6 
	var target_depth = -0.25
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var dist = Vector2(v.x, v.z).distance_to(Vector2(local_hit.x, local_hit.z))
		if dist < radius:
			var inner_radius = radius * 0.4
			var falloff = 1.0
			if dist > inner_radius:
				falloff = smoothstep(radius, inner_radius, dist)
				
			vertices[i].y = lerp(v.y, target_depth, falloff)
			modified = true
			
	if modified:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_apply_updated_arrays(arrays)

func dig_pond_tile(world_pos: Vector3, tile_size: float) -> void:
	var local_hit = to_local(world_pos)
	
	var arrays = _array_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	
	var modified = false
	var radius = tile_size * 0.8
	var target_depth = -0.5
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var dist = Vector2(v.x, v.z).distance_to(Vector2(local_hit.x, local_hit.z))
		if dist < radius:
			var inner_radius = radius * 0.5
			var falloff = 1.0
			if dist > inner_radius:
				falloff = smoothstep(radius, inner_radius, dist)
				
			vertices[i].y = lerp(v.y, target_depth, falloff)
			modified = true
			
	if modified:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_apply_updated_arrays(arrays)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func get_vertices() -> PackedVector3Array:
	if _array_mesh:
		var arrays = _array_mesh.surface_get_arrays(0)
		return arrays[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()

func apply_vertices(saved_vertices: PackedVector3Array) -> void:
	if _array_mesh and saved_vertices.size() > 0:
		var arrays = _array_mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_VERTEX].size() == saved_vertices.size():
			arrays[Mesh.ARRAY_VERTEX] = saved_vertices
			_apply_updated_arrays(arrays)

func save_to_disk() -> void:
	var verts = get_vertices()
	SaveManager.save_game(verts, [])

func load_from_disk() -> void:
	var data = SaveManager.load_game()
	if data.has("terrain"):
		apply_vertices(data["terrain"])
