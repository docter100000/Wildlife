extends Node

@export var camera: Camera3D
@export var tile_grid: TileGrid
@export var ground_y: float = 0.0

var _last_drag_tile := Vector2i(-999, -999)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _handle_interaction(event.position)
        else:
            # Reset tile so we can click it again later if we want
            _last_drag_tile = Vector2i(-999, -999)
            
    elif event is InputEventMouseMotion:
        if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
            _handle_interaction(event.position)

func _handle_interaction(mouse_pos: Vector2) -> void:
    if not camera or not tile_grid: return
    
    var ray_origin := camera.project_ray_origin(mouse_pos)
    var ray_dir    := camera.project_ray_normal(mouse_pos)

    # Intersect with Y=ground_y plane
    if ray_dir.y >= 0.0: return  # ray pointing up, no ground hit
    var t := (ground_y - ray_origin.y) / ray_dir.y
    var hit_world := ray_origin + ray_dir * t

    var tile := tile_grid.world_to_tile(hit_world)
    
    # Only interact if we entered a NEW valid tile
    if tile != _last_drag_tile and tile_grid.is_valid(tile):
        _last_drag_tile = tile
        ToolSystem.use_at(tile)
