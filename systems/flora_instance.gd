class_name FloraInstance
extends RefCounted

enum GrowthStage {
    SEED,        # just planted, not yet visible
    SEEDLING,    # 0.0–0.25 maturity
    JUVENILE,    # 0.25–0.5
    ESTABLISHING,# 0.5–0.75
    MATURE,      # 0.75–1.0
    VETERAN      # maturity == 1.0 AND seasons_at_maturity >= threshold
}

var data: FloraData
var tile_pos: Vector2i        # grid position this instance occupies

# Growth state
var maturity: float = 0.0     # 0.0 (seed) → 1.0 (fully mature)
var health: float = 1.0       # 0.0 (dead) → 1.0 (perfect)
var growth_stage: GrowthStage = GrowthStage.SEED
var seasons_planted: int = 0
var seasons_at_maturity: int = 0

# Last season's computed inputs (stored for debug readout)
var last_light: float = 0.0
var last_moisture: float = 0.0
var last_microbiome: float = 0.0
var last_spacing: float = 1.0
var last_fertilizer: float = 0.0
var last_growth_rate: float = 0.0

# Active stress flags — set by StressApplicator each season
var stress_browse: bool    = false
var stress_trample: bool   = false
var stress_fungal: bool    = false
var stress_viral: bool     = false
var stress_invasive: bool  = false
var stress_drought: bool   = false
var stress_waterlog: bool  = false

# Fertilizer applied this season (consumed each tick)
var fertilizer_level: float = 0.0

# Visual node — set by BlockSpawner
var block_node: MeshInstance3D = null

func _init(flora_data: FloraData, pos: Vector2i) -> void:
    data = flora_data
    tile_pos = pos

func is_mature() -> bool:
    return maturity >= 0.75

func is_established() -> bool:
    # "Established" means mature enough to satisfy flora dependency checks
    return seasons_planted >= data.maturity_seasons and maturity >= 0.5

func is_dead() -> bool:
    return health <= 0.0

func get_maturity_for_context() -> float:
    # What LandContext.flora_maturity receives — 0 if not established yet
    return maturity if is_established() else 0.0

func _update_stage() -> void:
    if maturity >= 1.0:
        seasons_at_maturity += 1
        growth_stage = GrowthStage.VETERAN \
            if seasons_at_maturity >= 4 \
            else GrowthStage.MATURE
    elif maturity >= 0.75: growth_stage = GrowthStage.MATURE
    elif maturity >= 0.50: growth_stage = GrowthStage.ESTABLISHING
    elif maturity >= 0.25: growth_stage = GrowthStage.JUVENILE
    elif maturity >  0.0:  growth_stage = GrowthStage.SEEDLING
    else:                  growth_stage = GrowthStage.SEED
