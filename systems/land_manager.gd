class_name LandManager
extends Node

signal animal_state_changed(instance: AnimalInstance, old_state, new_state)

var _instances: Array[AnimalInstance] = []

# flora_instances: Vector2i tile position → FloraInstance
var _flora_instances: Dictionary = {}
# soil_tiles: Vector2i → SoilTile
var _soil_tiles: Dictionary = {}

var _cached_flora_maturity: Dictionary = {}

func _ready() -> void:
	get_node("/root/TierManager").connect("species_unlocked", _on_species_unlocked)
	get_node("/root/TimeSystem").connect("day_passed", _on_day_passed)
	if get_node("/root/TimeSystem").has_signal("season_passed"):
		get_node("/root/TimeSystem").connect("season_passed", _on_season_passed)

func _on_species_unlocked(data: SpeciesData) -> void:
	_instances.append(AnimalInstance.new(data))

func _on_day_passed() -> void:
	var ctx := _build_context()
	print("--- Day passed! Evaluating Land Context ---")
	for inst in _instances:
		var prev := inst.state
		AnimalStateMachine.tick(inst, ctx)
		if inst.state != prev:
			var state_names = {
				SpeciesData.State.ABSENT: "ABSENT",
				SpeciesData.State.VISITING: "VISITING",
				SpeciesData.State.RESIDENT: "RESIDENT"
			}
			print("> [", inst.data.display_name, "] changed state: ", state_names[prev], " -> ", state_names[inst.state])
			animal_state_changed.emit(inst, prev, inst.state)
	_debug_print_states()

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

	# ── Worm density: average across all tilled tiles ───────────────
	var total_worms := 0.0
	var tile_count  := 0
	for pos in _soil_tiles:
		var s: SoilTile = _soil_tiles[pos]
		if s.is_tilled:
			total_worms += s.worm_density
			tile_count  += 1
	ctx.worm_density = (total_worms / maxf(tile_count, 1)) * 100.0 + _debug_worm_density

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
func _calc_disturbance()  -> float:  return 0.0
func _calc_land_area()    -> float:  return 1.0
func _is_night()          -> bool:   return false

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

	# Rebuild LandContext flora_maturity after all growth applied
	_refresh_context_flora()

func plant_flora(flora_id: StringName, pos: Vector2i) -> bool:
	var fdata = get_node("/root/SpeciesRegistry").get_flora(flora_id)
	if not fdata or not get_node("/root/TierManager").is_flora_unlocked(fdata):
		return false
	if _flora_instances.has(pos):
		return false  # tile already occupied
	var inst := FloraInstance.new(fdata, pos)
	_flora_instances[pos] = inst
	if not _soil_tiles.has(pos):
		_soil_tiles[pos] = SoilTile.new(pos)
		
	var bs = get_parent().get_node_or_null("BlockSpawner")
	if bs and bs.has_method("spawn_flora_block"):
		inst.block_node = bs.spawn_flora_block(fdata, _tile_to_world(pos))
	return true

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
	var bs = get_parent().get_node_or_null("BlockSpawner")
	if bs and bs.has_method("update_flora_scale"):
		bs.update_flora_scale(inst)
