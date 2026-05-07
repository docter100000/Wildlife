class_name GrowthEngine
extends RefCounted

# Stress multiplier table — matches our simulator design
const STRESS_MULT := {
    "browse"   : 0.75,
    "trample"  : 0.80,
    "fungal"   : 0.60,
    "viral"    : 0.55,
    "invasive" : 0.70,
    "drought"  : 0.65,
    "waterlog" : 0.72,
}

# Max growth per season — tune this to feel right in-game
const MAX_GROWTH_PER_SEASON := 0.08

static func compute(
    inst: FloraInstance,
    soil: SoilTile
) -> Dictionary:
    # Returns { growth_delta: float, health_delta: float, rate: float }

    var d := inst.data

    # ── 1. Score each input against species preferences ─────────────
    var light_score     := _tolerance_score(
                              soil.light, d.preferred_light, d.light_tolerance)
    var moisture_score  := _tolerance_score(
                              soil.moisture, d.preferred_moisture, d.moisture_tolerance)
    var micro_score     := _clamp01(soil.microbiome)
    var spacing_score   := _clamp01(soil.spacing_score)
    var compaction_pen  := 1.0 - soil.compaction * 0.8  # compaction directly hurts

    # ── 2. Soil composite (moisture + microbiome + spacing + compaction)
    var soil_score := (moisture_score + micro_score + spacing_score + compaction_pen) / 4.0

    # ── 3. Base: light × soil (both required — Liebig multiplicative)
    var base := light_score * soil_score

    # ── 4. Fertilizer bonus (only above soil threshold of 0.4)
    var fert_bonus := 0.0
    if soil.fertilizer > 0.0 and soil_score > 0.4:
        fert_bonus = soil.fertilizer * 0.2  # max +0.2 at full fertilizer

    var boosted := minf(1.0, base + fert_bonus)

    # ── 5. Liebig cap: growth cannot exceed worst single factor
    var limiting := minf(light_score,
                    minf(moisture_score,
                    minf(micro_score, spacing_score)))
    var liebig    := minf(boosted, limiting)

    # ── 6. Stress multipliers (stacked multiplicatively)
    var stress_mult := 1.0
    if inst.stress_browse:   stress_mult *= STRESS_MULT["browse"]
    if inst.stress_trample:  stress_mult *= STRESS_MULT["trample"]
    if inst.stress_fungal:   stress_mult *= STRESS_MULT["fungal"]
    if inst.stress_viral:    stress_mult *= STRESS_MULT["viral"]
    if inst.stress_invasive: stress_mult *= STRESS_MULT["invasive"]
    if inst.stress_drought:  stress_mult *= STRESS_MULT["drought"]
    if inst.stress_waterlog: stress_mult *= STRESS_MULT["waterlog"]

    var final_rate := liebig * stress_mult

    # ── 7. Convert rate to deltas ────────────────────────────────────
    var growth_delta := final_rate * MAX_GROWTH_PER_SEASON
    # Health drops when rate is very low or stress is severe
    var health_delta := (final_rate - 0.3) * 0.05
    # Viral blight causes direct health damage regardless of growth
    if inst.stress_viral:
        health_delta -= 0.08

    # Cache inputs on instance for debug overlay
    inst.last_light      = light_score
    inst.last_moisture   = moisture_score
    inst.last_microbiome = micro_score
    inst.last_spacing    = spacing_score
    inst.last_fertilizer = fert_bonus
    inst.last_growth_rate= final_rate

    return {
        "growth_delta": growth_delta,
        "health_delta": health_delta,
        "rate":         final_rate,
    }

# ── Helpers ──────────────────────────────────────────────────────────

static func _tolerance_score(
    actual: float, preferred: float, tolerance: float
) -> float:
    # Returns 1.0 within tolerance band, falls off linearly outside
    var diff := absf(actual - preferred)
    if diff <= tolerance:
        return 1.0
    var falloff := (diff - tolerance) / (1.0 - tolerance + 0.001)
    return clampf(1.0 - falloff, 0.0, 1.0)

static func _clamp01(v: float) -> float:
    return clampf(v, 0.0, 1.0)
