extends Node3D
class_name CameraPivot

@export var move_speed: float = 20.0
@export var rotate_speed: float = 3.0
@export var zoom_speed: float = 0.1

@export var pitch_zoomed_out: float = -75.0
@export var pitch_zoomed_in: float = -10.0
@export var distance_zoomed_out: float = 35.0
@export var distance_zoomed_in: float = 2.0
@export var min_camera_clearance: float = 1.5

var target_zoom: float = 0.5
var current_zoom: float = 0.5

@onready var camera: Camera3D = $Camera3D

func _process(delta: float) -> void:
	# 1. Smoothly interpolate zoom
	current_zoom = lerp(current_zoom, target_zoom, 10.0 * delta)
	
	# 2. Movement (WASD)
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	if input_dir != Vector2.ZERO:
		var forward := global_transform.basis.z * input_dir.y
		var right := global_transform.basis.x * input_dir.x
		var move_dir := (forward + right).normalized()
		# Flatten the movement so it doesn't try to fly up/down purely based on rotation
		move_dir.y = 0 
		move_dir = move_dir.normalized()
		
		var speed_multiplier = lerp(0.2, 1.0, current_zoom)
		if Input.is_physical_key_pressed(KEY_SHIFT):
			speed_multiplier *= 2.0
			
		global_position += move_dir * move_speed * speed_multiplier * delta
	
	# 3. Rotation via keys (Q/E)
	var rotate_dir = 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		rotate_dir += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		rotate_dir -= 1.0
		
	if rotate_dir != 0.0:
		rotate_y(rotate_dir * rotate_speed * delta)
		
	_update_terrain_following(delta)

func _update_terrain_following(delta: float) -> void:
	if not camera: return
	
	var space_state = get_world_3d().direct_space_state
	
	# --- Pivot Terrain Snap ---
	# Raycast straight down from the pivot to keep the focus point directly on the ground
	var p_query = PhysicsRayQueryParameters3D.create(Vector3(global_position.x, 1000.0, global_position.z), Vector3(global_position.x, -1000.0, global_position.z))
	var p_result = space_state.intersect_ray(p_query)
	if p_result:
		global_position.y = lerp(global_position.y, p_result.position.y, 15.0 * delta)

	# --- Camera Ideal Position ---
	var target_pitch = lerp(pitch_zoomed_in, pitch_zoomed_out, current_zoom)
	var target_distance = lerp(distance_zoomed_in, distance_zoomed_out, current_zoom)
	
	# Calculate ideal local position based purely on our Viva Pinata zoom angles
	var temp_transform = Transform3D()
	temp_transform.basis = Basis.from_euler(Vector3(deg_to_rad(target_pitch), 0, 0))
	var ideal_local_pos = temp_transform.basis.z * target_distance
	
	# Convert to ideal global position
	var ideal_global_pos = global_transform * ideal_local_pos
	
	# --- Camera Mountain Clearance ---
	# Check the terrain height exactly where the camera wants to be
	var c_query = PhysicsRayQueryParameters3D.create(Vector3(ideal_global_pos.x, 1000.0, ideal_global_pos.z), Vector3(ideal_global_pos.x, -1000.0, ideal_global_pos.z))
	var c_result = space_state.intersect_ray(c_query)
	if c_result:
		var terrain_y = c_result.position.y
		var safe_y = terrain_y + min_camera_clearance
		# If the mountain is higher than our ideal camera height, push the ideal position up!
		if ideal_global_pos.y < safe_y:
			ideal_global_pos.y = safe_y
			
	# Smoothly move the actual camera to the collision-safe ideal position
	camera.global_position = camera.global_position.lerp(ideal_global_pos, 15.0 * delta)
	
	# Force the camera to always look exactly at the Pivot. 
	# If we raised the camera over a mountain, this naturally tilts it down further to keep focus!
	var look_transform = camera.global_transform.looking_at(global_position, Vector3.UP)
	camera.global_transform.basis = camera.global_transform.basis.slerp(look_transform.basis, 20.0 * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - zoom_speed, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + zoom_speed, 0.0, 1.0)
			
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			rotate_y(-event.relative.x * 0.005)
