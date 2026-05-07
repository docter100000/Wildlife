class_name InvasiveSpreadSystem
extends RefCounted

static func tick(
    flora_instances: Dictionary,
    soil_tiles:      Dictionary,
    tile_grid:       TileGrid,
    land_manager     # LandManager ref for plant_flora
) -> Array[Vector2i]:
    # Returns list of newly infected tile positions (for UI alert)
    var newly_infected: Array[Vector2i] = []

    # Snapshot keys — don't iterate while modifying
    var current_positions := flora_instances.keys()

    for pos in current_positions:
        var inst: FloraInstance = flora_instances[pos]
        if not inst.data.is_invasive: continue
        if inst.maturity < inst.data.spread_min_maturity: continue

        # ── Soil poisoning ───────────────────────────────────────────
        if inst.data.soil_poison_strength > 0.0:
            for n in tile_grid.neighbours(pos, inst.data.soil_poison_radius):
                if soil_tiles.has(n):
                    var s: SoilTile = soil_tiles[n]
                    s.microbiome = maxf(0.0,
                        s.microbiome - inst.data.soil_poison_strength)
                    s.worm_density = maxf(0.0,
                        s.worm_density - inst.data.soil_poison_strength * 0.5)

        # ── Spreading to neighbours ──────────────────────────────────
        for n in tile_grid.neighbours(pos, inst.data.spread_radius):
            if flora_instances.has(n): continue   # tile occupied
            if randf() > inst.data.spread_chance: continue
            # Plant invasive silently — no player unlock check
            var new_inst := FloraInstance.new(inst.data, n)
            new_inst.maturity = 0.05  # tiny seedling
            flora_instances[n] = new_inst
            if not soil_tiles.has(n):
                soil_tiles[n] = SoilTile.new(n)
            tile_grid.active_tiles[n] = true
            # Spawn a block for the new invasive
            new_inst.block_node = land_manager._spawn_flora_block_at(
                inst.data, tile_grid.tile_to_world(n))
            newly_infected.append(n)

    return newly_infected
