extends Node

signal level_changed(new_level: int)
signal species_unlocked(species_data: SpeciesData)

const XP_THRESHOLDS: Array[int] = [
    0, 150, 380, 700, 1100,          # Lv 1–5  Pioneer
    1600, 2200, 2900, 3700, 4700,    # Lv 6–10 Establishing
    5900, 7300, 9000, 11000, 13500,  # Lv 11–15 Developing
    16500, 20000, 24000, 29000, 35000,# Lv 16–20 Mature
    42000, 50000, 60000, 72000, 86000,# Lv 21–25 Mature cont.
    103000,122000,145000,172000,200000 # Lv 26–30 Apex
]

var current_xp: int = 0

var player_level: int = 1:
    set(v):
        var prev := player_level
        player_level = v
        if v != prev:
            _on_level_changed(prev, v)

func is_unlocked(data: SpeciesData) -> bool:
    return player_level >= data.unlock_level

func is_flora_unlocked(data: FloraData) -> bool:
    return player_level >= data.unlock_level

func _on_level_changed(old_lv: int, new_lv: int) -> void:
    level_changed.emit(new_lv)
    # Announce any species newly crossing the unlock threshold
    for s in SpeciesRegistry.all_unlocked_species(new_lv):
        if s.unlock_level > old_lv:
            species_unlocked.emit(s)

func add_xp(amount: int) -> void:
    current_xp += amount
    var new_lv := player_level
    while new_lv < XP_THRESHOLDS.size() - 1 \
          and current_xp >= XP_THRESHOLDS[new_lv]:
        new_lv += 1
    player_level = new_lv  # triggers setter → signal
