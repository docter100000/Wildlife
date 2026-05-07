extends Node

signal day_passed()
signal season_passed(season: int, rainfall: float)
signal year_passed(year: int)
signal hour_changed(hour: int)

# 0=spring 1=summer 2=autumn 3=winter
const SEASON_NAMES   := ["Spring","Summer","Autumn","Winter"]
const DAYS_PER_SEASON := 7   # tune: more = slower progression
const HOURS_PER_DAY   := 24
const REAL_SECS_PER_HOUR := 30.0

# Rainfall per season (0–1) — drive these from a random curve later
const SEASON_RAINFALL: Array[float] = [0.35, 0.12, 0.28, 0.20]

var current_hour:   int = 6    # start at dawn
var current_day:    int = 0
var current_season: int = 0    # 0=spring
var current_year:   int = 1
var is_night:       bool = false
var time_scale:     float = 1.0  # 0 = paused

var _elapsed: float = 0.0

func _process(delta: float) -> void:
    if time_scale <= 0.0: return
    _elapsed += delta * time_scale
    while _elapsed >= REAL_SECS_PER_HOUR:
        _elapsed -= REAL_SECS_PER_HOUR
        _advance_hour()

func _advance_hour() -> void:
    current_hour = (current_hour + 1) % HOURS_PER_DAY
    is_night = current_hour >= 20 or current_hour < 5
    hour_changed.emit(current_hour)
    if current_hour == 0:
        _advance_day()

func _advance_day() -> void:
    current_day += 1
    day_passed.emit()
    if current_day >= DAYS_PER_SEASON:
        current_day = 0
        _advance_season()

func _advance_season() -> void:
    var rain := SEASON_RAINFALL[current_season]
    season_passed.emit(current_season, rain)
    current_season = (current_season + 1) % 4
    if current_season == 0:
        current_year += 1
        year_passed.emit(current_year)

func get_season_name() -> String:
    return SEASON_NAMES[current_season]

func pause()  -> void: time_scale = 0.0
func resume() -> void: time_scale = 1.0
func fast_forward(scale: float = 5.0) -> void: time_scale = scale
