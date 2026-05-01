class_name AnimalInstance
extends RefCounted

var data: SpeciesData
var state: SpeciesData.State = SpeciesData.State.ABSENT

# Trust rises with undisturbed visits, resets on disturbance
var trust_counter: float = 0.0     # 0–1
var undisturbed_visits: int = 0

# Set by the block spawner when this animal is visualised
var block_node: Node3D = null

func _init(species_data: SpeciesData) -> void:
    data = species_data

func disturb(severity: float = 1.0) -> void:
    trust_counter = maxf(0.0, trust_counter - severity)
    if severity >= 0.5:
        undisturbed_visits = maxi(0, undisturbed_visits - 2)
    if state == SpeciesData.State.VISITING and severity >= 0.8:
        state = SpeciesData.State.ABSENT

func record_undisturbed_visit() -> void:
    undisturbed_visits += 1
    trust_counter = minf(1.0, trust_counter + 0.15)

func can_attempt_residency() -> bool:
    return undisturbed_visits >= data.visits_needed_for_residency
