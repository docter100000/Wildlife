class_name TileGrid
extends Node

# Grid dimensions — start small, expand with land purchases later
@export var grid_width:  int = 20
@export var grid_height: int = 20
@export var tile_size:   float = 1.0  # world units per tile

# Tiles that have been tilled at least once (player has interacted)
var active_tiles: Dictionary = {}  # Vector2i → true

# Disturbance map: Vector2i → float 0–1, decays each day
var _disturbance: Dictionary = {}

func is_valid(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < grid_width \
       and pos.y >= 0 and pos.y < grid_height

func world_to_tile(world_pos: Vector3) -> Vector2i:
    return Vector2i(
        int(world_pos.x / tile_size),
        int(world_pos.z / tile_size)
    )

func tile_to_world(pos: Vector2i) -> Vector3:
    return Vector3(
        pos.x * tile_size + tile_size * 0.5,
        0.0,
        pos.y * tile_size + tile_size * 0.5
    )

func neighbours(pos: Vector2i, radius: int = 1) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            if dx == 0 and dy == 0: continue
            var n := pos + Vector2i(dx, dy)
            if is_valid(n): result.append(n)
    return result

# ── Disturbance ──────────────────────────────────────────────────────

func add_disturbance(pos: Vector2i, amount: float, radius: int = 2) -> void:
    # Epicentre gets full amount, falls off with distance
    _disturbance[pos] = minf(1.0, _disturbance.get(pos, 0.0) + amount)
    for n in neighbours(pos, radius):
        var dist := float((n - pos).length())
        var falloff := amount * (1.0 - dist / (radius + 1.0))
        _disturbance[n] = minf(1.0, _disturbance.get(n, 0.0) + falloff)

func get_disturbance(pos: Vector2i) -> float:
    return _disturbance.get(pos, 0.0)

func get_average_disturbance() -> float:
    if _disturbance.is_empty(): return 0.0
    var total := 0.0
    for v in _disturbance.values(): total += v
    return total / _disturbance.size()

func decay_disturbance() -> void:
    # Called each in-game day — disturbance fades naturally
    var to_remove: Array = []
    for pos in _disturbance:
        _disturbance[pos] -= 0.15
        if _disturbance[pos] <= 0.0:
            to_remove.append(pos)
    for pos in to_remove:
        _disturbance.erase(pos)

func get_land_area_ha() -> float:
    # Each tile = tile_size² m² — convert to hectares
    var tile_area_m2 := tile_size * tile_size
    return active_tiles.size() * tile_area_m2 / 10000.0
