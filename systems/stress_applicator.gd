class_name StressApplicator
extends RefCounted

static func apply(
    inst:     FloraInstance,
    soil:     SoilTile,
    ctx:      LandContext,
    nearby_animals: Array[AnimalInstance]
) -> void:

    # ── Clear all stress flags first ─────────────────────────────────
    inst.stress_browse   = false
    inst.stress_trample  = false
    inst.stress_fungal   = false
    inst.stress_viral    = false
    inst.stress_invasive = false
    inst.stress_drought  = false
    inst.stress_waterlog = false

    # ── Animal-caused stress ─────────────────────────────────────────
    for animal in nearby_animals:
        if animal.state == SpeciesData.State.ABSENT:
            continue
        if animal.data.browse_stress > 0.0:
            inst.stress_browse = true
        if animal.data.trample_stress > 0.0:
            inst.stress_trample = true

    # ── Soil condition stress ────────────────────────────────────────
    # Drought: moisture well below species preference
    var moisture_diff := inst.data.preferred_moisture - soil.moisture
    if moisture_diff > inst.data.moisture_tolerance + 0.2:
        inst.stress_drought = true

    # Waterlogging: moisture well above species preference
    var overwater_diff := soil.moisture - inst.data.preferred_moisture
    if overwater_diff > inst.data.moisture_tolerance + 0.25:
        inst.stress_waterlog = true

    # ── Invasive competition ─────────────────────────────────────────
    # If an invasive flora exists on a neighbouring tile, apply stress
    if ctx.invasive_pressure_at(inst.tile_pos) > 0.3:
        inst.stress_invasive = true

    # ── Disease spread ───────────────────────────────────────────────
    # Fungal: spreads from neighbouring infected plants in damp conditions
    if ctx.fungal_infection_at(inst.tile_pos) and soil.moisture > 0.7:
        inst.stress_fungal = true

    # Viral: spreads from neighbouring infected plants regardless of moisture
    if ctx.viral_infection_at(inst.tile_pos):
        inst.stress_viral = true
