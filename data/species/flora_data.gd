class_name FloraData
extends Resource

@export var id: StringName
@export var display_name: String
@export var tier: int
@export var block_color: Color = Color.WHITE
@export var unlock_level: int = 1

# Growth system preferences (0–1 normalised)
@export var preferred_light: float    = 0.7
@export var preferred_moisture: float = 0.6
@export var light_tolerance: float    = 0.3  # ±range before penalty
@export var moisture_tolerance: float = 0.3

# What this flora contributes when mature (read by SpeciesData checks)
@export var provides_nesting: bool   = false
@export var provides_canopy: bool   = false
@export var worm_density_bonus: float = 0.0
@export var maturity_seasons: int   = 1  # seasons to count as established

# Which other flora IDs are needed nearby to grow here
@export var needs_companion_flora: Array[StringName] = []

# ── Invasive behaviour (leave at defaults for normal plants) ─────────
@export var is_invasive: bool         = false
@export var spread_radius: int        = 2     # tiles per season
@export var spread_chance: float      = 0.35  # per eligible neighbour
@export var spread_min_maturity: float= 0.6   # must be this mature to spread
@export var soil_poison_radius: int   = 0     # tiles of soil damage around it
@export var soil_poison_strength: float= 0.0  # microbiome reduction per season
