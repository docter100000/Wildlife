extends Node

enum Tool {
	TILL, WATERING_TOOL, COMPOST, FERTILIZE,
	PLANT, REMOVE_FLORA,
	CAMERA, HIDE_PLACE,
	DIG_POND
}

var active_tool: Tool = Tool.TILL
var selected_flora_id: StringName = &""

# Disturbance amounts per tool — tune to feel right
const TOOL_DISTURBANCE := {
	Tool.TILL:         1.0,
	Tool.WATERING_TOOL:0.1,
	Tool.COMPOST:      0.3,
	Tool.FERTILIZE:    0.15,
	Tool.PLANT:        0.4,
	Tool.REMOVE_FLORA: 0.6,
	Tool.CAMERA:       0.0,
	Tool.HIDE_PLACE:   0.5,
	Tool.DIG_POND:     1.0,
}

func use_at(tile_pos: Vector2i) -> void:
	var lm: LandManager = get_node("/root/Main/LandManager")
	var tg: TileGrid    = lm.tile_grid
	if not tg.is_valid(tile_pos): return

	# Add disturbance first — animal trust updates on next day tick
	var dist: float = TOOL_DISTURBANCE.get(active_tool, 0.0)
	if dist > 0.0:
		tg.add_disturbance(tile_pos, dist)

	match active_tool:
		Tool.TILL:
			_do_till(lm, tile_pos)
		Tool.WATERING_TOOL:
			_do_water(lm, tile_pos)
		Tool.COMPOST:
			_do_compost(lm, tile_pos)
		Tool.FERTILIZE:
			_do_fertilize(lm, tile_pos)
		Tool.PLANT:
			_do_plant(lm, tile_pos)
		Tool.REMOVE_FLORA:
			_do_remove(lm, tile_pos)
		Tool.DIG_POND:
			_do_dig_pond(lm, tile_pos)

func _do_till(lm: LandManager, pos: Vector2i) -> void:
	var soil := lm.get_or_create_soil(pos)
	if not soil.is_tilled:
		soil.till()
		lm.tile_grid.active_tiles[pos] = true
		
		var terrain = get_node_or_null("/root/Main/Terrain")
		if terrain and terrain.has_method("till_tile"):
			var world_pos = lm.tile_grid.tile_to_world(pos)
			terrain.till_tile(world_pos, lm.tile_grid.tile_size)

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
	lm.remove_flora_at(pos)  # use the public wrapper

func _do_dig_pond(lm: LandManager, pos: Vector2i) -> void:
	var soil := lm.get_or_create_soil(pos)
	soil.moisture = 1.0 # Ponds hold max moisture
	lm.tile_grid.active_tiles[pos] = true
	
	var terrain = get_node_or_null("/root/Main/Terrain")
	if terrain and terrain.has_method("dig_pond_tile"):
		var world_pos = lm.tile_grid.tile_to_world(pos)
		terrain.dig_pond_tile(world_pos, lm.tile_grid.tile_size)
