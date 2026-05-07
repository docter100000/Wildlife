class_name LandManager
extends Node

@export var tile_grid: TileGrid
@export var block_spawner: BlockSpawner

signal animal_state_changed(instance: AnimalInstance, old_state, new_state)
signal invasive_detected(positions: Array)

var _instances: Array[AnimalInstance] = []

# flora_instances: Vector2i tile position → FloraInstance
var _flora_instances: Dictionary = {}
# soil_tiles: Vector2i → SoilTile
var _soil_tiles: Dictionary = {}

var _cached_flora_maturity: Dictionary = {}

func _ready() -> void:
	TierManager.connect("species_unlocked", _on_species_unlocked)
	TimeSystem.connect("day_passed",    _on_day_passed)
	TimeSystem.connect("season_passed", _on_season_passed)
	# Seed all currently-unlocked species on startup
	for s in SpeciesRegistry.all_unlocked_species(TierManager.player_level):
		_instances.append(AnimalInstance.new(s))

func _on_species_unlocked(data: SpeciesData) -> void:
	_instances.append(AnimalInstance.new(data))

func _on_day_passed() -> void:
	tile_grid.decay_disturbance()
	var ctx := _build_context()
	for inst in _instances:
		var prev := inst.state
		AnimalStateMachine.tick(inst, ctx)
		if inst.state != prev:
			animal_state_changed.emit(inst, prev, inst.state)

func _debug_print_states() -> void:
	var state_names := ["ABSENT", "VISITING", "RESIDENT"]
	var time_sys = get_node_or_null("/root/TimeSystem")
	var current_day = time_sys.current_day if time_sys else 0
	var debug_text = "Day " + str(current_day) + " States:\n"
	for inst in _instances:
		var line = "[%s] state=%s trust=%.2f visits=%d" % [
			inst.data.display_name,
			state_names[inst.state],
			inst.trust_counter,
			inst.undisturbed_visits
		]
		print(line)
		debug_text += line + "\n"
		
	var label = get_node_or_null("../UI/TestPanel/VBoxContainer/DebugLabel")
	if label:
		label.text = debug_text

func _build_context() -> LandContext:
	var ctx := LandContext.new()

	# ── Flora maturity: best established value per species ───────────
	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		var m := inst.get_maturity_for_context()
		if m > 0.0:
			var id := inst.data.id
			ctx.flora_maturity[id] = maxf(ctx.flora_maturity.get(id, 0.0), m)

	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		if not inst.data.is_invasive: continue
		# Build pressure map: invasive presence pressures neighbour tiles
		var pressure := inst.maturity * 0.8
		ctx.invasive_pressure[pos] = pressure
		for n in tile_grid.neighbours(pos, 2):
			ctx.invasive_pressure[n] = maxf(
				ctx.invasive_pressure.get(n, 0.0), pressure * 0.5)

	# ── Worm density: average across all tilled tiles ───────────────
	ctx.worm_density = _calc_worm_density() + _debug_worm_density

	# ── Nesting sites: count flora that provide nesting ──────────────
	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		if inst.is_mature() and inst.data.provides_nesting:
			ctx.nesting_sites[inst.data.id] = \
				ctx.nesting_sites.get(inst.data.id, 0) + 1
			ctx.nesting_sites["generic"] = \
				ctx.nesting_sites.get("generic", 0) + 1

	# ── Canopy light reduction ───────────────────────────────────────
	# For each tile with a mature canopy tree, reduce light on that tile
	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		if inst.data.provides_canopy and inst.is_mature():
			var canopy_radius := 2
			for dx in range(-canopy_radius, canopy_radius + 1):
				for dy in range(-canopy_radius, canopy_radius + 1):
					var neighbour: Vector2i = pos + Vector2i(dx, dy)
					if _soil_tiles.has(neighbour):
						var s: SoilTile = _soil_tiles[neighbour]
						s.light = maxf(0.1, s.light - 0.15 * inst.maturity)

	# ── Remaining fields ────────────────────────────────────────────
	ctx.disturbance_level = _calc_disturbance()
	ctx.land_area_ha      = _calc_land_area()
	ctx.is_night          = _is_night()
	for inst in _instances:
		if inst.state == SpeciesData.State.RESIDENT:
			ctx.resident_counts[inst.data.id] = \
				ctx.resident_counts.get(inst.data.id, 0) + 1
	return ctx

# Stubs — replace with real tile/grid queries
func _calc_worm_density() -> float:
	var total := 0.0
	var count := 0
	for pos in _soil_tiles:
		var s: SoilTile = _soil_tiles[pos]
		if s.is_tilled:
			total += s.worm_density
			count += 1
	return total / maxf(count, 1) * 30.0  # scale to worms/m² range

func _calc_disturbance() -> float:
	return tile_grid.get_average_disturbance()

func _calc_land_area() -> float:
	return tile_grid.get_land_area_ha()

func _is_night() -> bool:
	return TimeSystem.is_night  # wired in Phase 10

var _debug_worm_density: float = 0.0

func debug_plant_flora() -> void:
	plant_flora(&"hawthorn", Vector2i(1, 1))
	plant_flora(&"bramble", Vector2i(-1, -1))
	
	# Force them to mature for testing purposes
	for pos in _flora_instances:
		var inst = _flora_instances[pos]
		inst.maturity = 1.0
		inst.seasons_planted = 4
		inst._update_stage()
		_update_flora_visual(inst)
		
	_refresh_context_flora()
	_debug_worm_density = 15.0

# ── Seasonal Flora Pipeline ──────────────────────────────────────────

func _on_season_passed(season: int, rainfall: float) -> void:
	_update_spacing_scores()
	var ctx := _build_context()  # reuse from Phase 6

	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		var soil: SoilTile     = _soil_tiles.get(pos)
		if not soil or inst.is_dead():
			continue

		# 1. Tick soil conditions
		soil.tick_season(rainfall, season)

		# 2. Apply stress flags
		var nearby := _animals_near_tile(pos, 3)
		StressApplicator.apply(inst, soil, ctx, nearby)

		# 3. Compute growth
		var result := GrowthEngine.compute(inst, soil)

		# 4. Write back to instance
		inst.maturity = clampf(
			inst.maturity + result["growth_delta"], 0.0, 1.0)
		inst.health   = clampf(
			inst.health + result["health_delta"], 0.0, 1.0)
		inst.seasons_planted += 1
		inst._update_stage()

		# 5. Remove dead plants
		if inst.is_dead():
			_remove_flora(pos)
			continue

		# 6. Notify block spawner to update visual scale
		_update_flora_visual(inst)

	var new_infections := InvasiveSpreadSystem.tick(
		_flora_instances, _soil_tiles, tile_grid, self)
	if not new_infections.is_empty():
		# Signal UI to show invasive alert — wire to your HUD in Phase 12
		emit_signal("invasive_detected", new_infections)

	# Rebuild LandContext flora_maturity after all growth applied
	_refresh_context_flora()

func get_or_create_soil(pos: Vector2i) -> SoilTile:
	if not _soil_tiles.has(pos):
		_soil_tiles[pos] = SoilTile.new(pos)
	return _soil_tiles[pos]

func get_soil(pos: Vector2i) -> SoilTile:
	return _soil_tiles.get(pos, null)

func plant_flora(flora_id: StringName, pos: Vector2i) -> bool:
	var fdata = get_node("/root/SpeciesRegistry").get_flora(flora_id)
	if not fdata or not get_node("/root/TierManager").is_flora_unlocked(fdata):
		return false
	if _flora_instances.has(pos):
		return false  # tile already occupied
	var inst := FloraInstance.new(fdata, pos)
	_flora_instances[pos] = inst
	get_or_create_soil(pos)
		
	if block_spawner:
		inst.block_node = block_spawner.spawn_flora_block(fdata, _tile_to_world(pos))
	return true

# Called by InvasiveSpreadSystem to spawn a block without going
# through plant_flora() (which checks unlock level)
func _spawn_flora_block_at(
	data: FloraData, world_pos: Vector3
) -> MeshInstance3D:
	return block_spawner.spawn_flora_block(data, world_pos)

# Expose for ToolSystem
func remove_flora_at(pos: Vector2i) -> void:
	_remove_flora(pos)
	# Clear any lingering invasive pressure at this position
	if tile_grid:
		tile_grid._disturbance[pos] = minf(
			tile_grid._disturbance.get(pos, 0.0) + 0.4, 1.0)

# Called by BlockSpawner after spawning — links block back to instance
func register_flora_block(
	pos: Vector2i, node: MeshInstance3D
) -> void:
	var inst: FloraInstance = _flora_instances.get(pos)
	if inst: inst.block_node = node

func _update_spacing_scores() -> void:
	for pos in _soil_tiles:
		var neighbours := 0
		for offset in [Vector2i(1,0),Vector2i(-1,0),
						Vector2i(0,1),Vector2i(0,-1)]:
			if _flora_instances.has(pos + offset):
				neighbours += 1
		_soil_tiles[pos].spacing_score = 1.0 - (neighbours / 4.0)

func _animals_near_tile(
	_pos: Vector2i, _radius: int
) -> Array[AnimalInstance]:
	# Returns all non-absent animals whose block is within radius tiles
	# Stub: return all active instances for now
	var result: Array[AnimalInstance] = []
	for a in _instances:
		if a.state != SpeciesData.State.ABSENT:
			result.append(a)
	return result

func _remove_flora(pos: Vector2i) -> void:
	var inst: FloraInstance = _flora_instances.get(pos)
	if inst and inst.block_node:
		inst.block_node.queue_free()
	_flora_instances.erase(pos)

func _tile_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * 1.0, 0.0, pos.y * 1.0)

func _refresh_context_flora() -> void:
	# Keep context in sync after growth — used by next animal tick
	_cached_flora_maturity.clear()
	for pos in _flora_instances:
		var inst: FloraInstance = _flora_instances[pos]
		# _cached_ctx maintained as a field, updated before each animal tick
		_cached_flora_maturity[inst.data.id] = \
			maxf(_cached_flora_maturity.get(inst.data.id, 0.0),
				 inst.get_maturity_for_context())

func _update_flora_visual(inst: FloraInstance) -> void:
	if block_spawner:
		block_spawner.update_flora_scale(inst)
