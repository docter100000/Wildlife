extends Node

enum Tool {
    TILL, WATER, COMPOST, FERTILIZE,
    PLANT, REMOVE_FLORA,
    CAMERA, HIDE_PLACE
}

var active_tool: Tool = Tool.TILL
var selected_flora_id: StringName = &""

# Disturbance amounts per tool — tune to feel right
const TOOL_DISTURBANCE := {
    Tool.TILL:         1.0,
    Tool.WATER:        0.1,
    Tool.COMPOST:      0.3,
    Tool.FERTILIZE:    0.15,
    Tool.PLANT:        0.4,
    Tool.REMOVE_FLORA: 0.6,
    Tool.CAMERA:       0.0,
    Tool.HIDE_PLACE:   0.5,
}

func use_at(tile_pos: Vector2i) -> void:
    var lm: LandManager = get_node("/root/World/LandManager")
    var tg: TileGrid    = lm.tile_grid
    if not tg.is_valid(tile_pos): return

    # Add disturbance first — animal trust updates on next day tick
    var dist: float = TOOL_DISTURBANCE.get(active_tool, 0.0)
    if dist > 0.0:
        tg.add_disturbance(tile_pos, dist)

    match active_tool:
        Tool.TILL:
            _do_till(lm, tile_pos)
        Tool.WATER:
            _do_water(lm, tile_pos)
        Tool.COMPOST:
            _do_compost(lm, tile_pos)
        Tool.FERTILIZE:
            _do_fertilize(lm, tile_pos)
        Tool.PLANT:
            _do_plant(lm, tile_pos)
        Tool.REMOVE_FLORA:
            _do_remove(lm, tile_pos)

func _do_till(lm: LandManager, pos: Vector2i) -> void:
    var soil := lm.get_or_create_soil(pos)
    soil.till()
    lm.tile_grid.active_tiles[pos] = true

func _do_water(lm: LandManager, pos: Vector2i) -> void:
    lm.get_or_create_soil(pos).water(0.2)

func _do_compost(lm: LandManager, pos: Vector2i) -> void:
    lm.get_or_create_soil(pos).apply_compost()

func _do_fertilize(lm: LandManager, pos: Vector2i) -> void:
    lm.get_or_create_soil(pos).apply_fertilizer(0.3)

func _do_plant(lm: LandManager, pos: Vector2i) -> void:
    if selected_flora_id != &"":
        lm.plant_flora(selected_flora_id, pos)

func _do_remove(lm: LandManager, pos: Vector2i) -> void:
    lm._remove_flora(pos)
