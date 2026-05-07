extends Node

var species: Dictionary = {}  # StringName → SpeciesData
var flora:   Dictionary = {}  # StringName → FloraData

func _ready() -> void:
    _load_dir("res://data/species/animals/", species)
    _load_dir("res://data/species/flora/",   flora)

func _load_dir(path: String, target: Dictionary) -> void:
    var dir := DirAccess.open(path)
    if not dir: return
    dir.list_dir_begin()
    var file := dir.get_next()
    while file != "":
        if file.ends_with(".tres"):
            var res = load(path + file)
            if res and res.id:
                target[res.id] = res
        file = dir.get_next()

func get_species(id: StringName) -> SpeciesData:
    return species.get(id, null)

func get_flora(id: StringName) -> FloraData:
    return flora.get(id, null)

func all_unlocked_species(player_level: int) -> Array:
    return species.values().filter(
        func(s): return s.unlock_level <= player_level
    )
