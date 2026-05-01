class_name SoilTile
extends RefCounted

var position: Vector2i

# All values 0.0–1.0
var moisture: float    = 0.3   # raised by rain, watering, proximity to water
var microbiome: float  = 0.1   # raised by compost, fungi, worm activity
var worm_density: float= 0.0   # raised by tilling + organic matter over time
var light: float       = 1.0   # reduced by canopy overhead (set by tree maturity)
var compaction: float  = 0.0   # raised by trampling, reduced by tilling
var fertilizer: float  = 0.0   # applied by player, decays each season
var is_tilled: bool    = false

# Spacing score derived from neighbours — set by LandManager each season
var spacing_score: float = 1.0

func _init(pos: Vector2i) -> void:
    position = pos

# ── Player tool actions ─────────────────────────────────────────────

func till() -> void:
    is_tilled   = true
    compaction  = maxf(0.0, compaction - 0.4)
    moisture    = minf(1.0, moisture + 0.1)
    # Worm density rises gradually after tilling — not instant

func water(amount: float = 0.2) -> void:
    moisture = minf(1.0, moisture + amount)

func apply_compost() -> void:
    microbiome  = minf(1.0, microbiome + 0.25)
    worm_density= minf(1.0, worm_density + 0.1)
    fertilizer  = minf(1.0, fertilizer + 0.3)

func apply_fertilizer(amount: float = 0.3) -> void:
    fertilizer  = minf(1.0, fertilizer + amount)

# ── Passive seasonal decay ──────────────────────────────────────────

func tick_season(rainfall: float, season: int) -> void:
    # Moisture: replenished by rain, evaporates in summer
    var evap := 0.12 if season == 2 else 0.06  # season 2 = summer
    moisture = clampf(moisture + rainfall - evap, 0.0, 1.0)

    # Microbiome: grows slowly if moisture and organic matter present
    if moisture > 0.3 and worm_density > 0.1:
        microbiome = minf(1.0, microbiome + 0.02)
    else:
        microbiome = maxf(0.0, microbiome - 0.01)

    # Worm density: grows with tilled moist soil, collapses under compaction
    if is_tilled and moisture > 0.25 and compaction < 0.5:
        worm_density = minf(1.0, worm_density + 0.05)
    elif compaction > 0.6:
        worm_density = maxf(0.0, worm_density - 0.08)

    # Fertilizer consumed each season
    fertilizer  = maxf(0.0, fertilizer - 0.25)

    # Compaction increases slightly each season from natural settling
    compaction  = minf(1.0, compaction + 0.01)
