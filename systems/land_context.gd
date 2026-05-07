class_name LandContext
extends RefCounted

# Flora present: id → maturity (0–1, where 1 = fully mature)
var flora_maturity: Dictionary = {}

# Current worm density across the land (average tiles/m²)
var worm_density: float = 0.0

# Count of resident animals by species id
var resident_counts: Dictionary = {}

# How disturbed the land is right now (0 = silent, 1 = heavy work)
var disturbance_level: float = 0.0

# Is it currently night in the day/night cycle
var is_night: bool = false

# Total land area in hectares
var land_area_ha: float = 0.0

# Nesting sites available by type (string → count)
var nesting_sites: Dictionary = {}

# Helper: is flora X present at minimum maturity threshold?
func flora_at(id: StringName, min_maturity: float = 0.0) -> bool:
	return flora_maturity.get(id, 0.0) >= min_maturity

func rival_present(rival_id: StringName) -> bool:
	return resident_counts.get(rival_id, 0) > 0

# ── Stubs for Phase 8 (Tile Grid) ───────────────────────────────────

# Maps tile position → invasive pressure 0–1
var invasive_pressure: Dictionary = {}
# Sets of tile positions with active disease
var fungal_tiles:      Array[Vector2i] = []
var viral_tiles:       Array[Vector2i] = []

func invasive_pressure_at(pos: Vector2i) -> float:
	return invasive_pressure.get(pos, 0.0)

func fungal_infection_at(pos: Vector2i) -> bool:
	return pos in fungal_tiles

func viral_infection_at(pos: Vector2i) -> bool:
	return pos in viral_tiles
