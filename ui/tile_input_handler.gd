extends Node

@export var camera: Camera3D
@export var tile_grid: TileGrid
@export var ground_y: float = 0.0

func _input(event: InputEvent) -> void:
    if not event is InputEventMouseButton: return
    if not event.pressed: return
    if event.button_index != MOUSE_BUTTON_LEFT: return

    var ray_origin := camera.project_ray_origin(event.position)
    var ray_dir    := camera.project_ray_normal(event.position)

    # Intersect with Y=ground_y plane
    if ray_dir.y >= 0.0: return  # ray pointing up, no ground hit
    var t := (ground_y - ray_origin.y) / ray_dir.y
    var hit_world := ray_origin + ray_dir * t

    var tile := tile_grid.world_to_tile(hit_world)
    if tile_grid.is_valid(tile):
        ToolSystem.use_at(tile)
