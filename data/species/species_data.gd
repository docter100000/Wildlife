class_name SpeciesData
extends Resource

enum Category { FLORA, FUNGI, INVERTEBRATE, REPTILE, BIRD, MAMMAL }
enum Rarity   { COMMON, UNCOMMON, RARE, LEGENDARY, INVASIVE }
enum State    { ABSENT, VISITING, RESIDENT }

# Identity
@export var id: StringName
@export var display_name: String
@export var category: Category
@export var tier: int        # 1–5
@export var rarity: Rarity

# Block colour used in prototype view (hex string)
@export var block_color: Color = Color.WHITE

# Flora this species needs present to even consider visiting
# Array of StringName IDs from FloraData
@export var visit_flora_required: Array[StringName] = []

# Min density / maturity needed per required flora (parallel array)
@export var visit_flora_thresholds: Array[float] = []

# Additional numeric conditions for visiting
@export var visit_min_worm_density: float = 0.0
@export var visit_min_prey_count: int   = 0
@export var visit_requires_night: bool  = false
@export var visit_disturbance_max: float = 1.0  # 0=no disturbance, 1=any ok

# How many undisturbed visits before residency becomes possible
@export var visits_needed_for_residency: int = 5

# Extra conditions layered on top of visit conditions
@export var reside_flora_required: Array[StringName] = []
@export var reside_flora_thresholds: Array[float] = []
@export var reside_needs_nesting_site: bool = false
@export var reside_min_territory_ha: float = 0.0
@export var reside_rival_excludes: Array[StringName] = []

# Player level needed before this species can appear at all
@export var unlock_level: int = 1

# Stress multipliers applied to plant growth when this animal is present
@export var browse_stress: float = 0.0   # 0 = none, 1 = max browse
@export var trample_stress: float = 0.0
