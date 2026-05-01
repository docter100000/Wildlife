class_name AnimalStateMachine
extends RefCounted

# Call once per in-game day per animal.
# ctx is a LandContext — see Phase 4.
static func tick(
    instance: AnimalInstance,
    ctx: LandContext
) -> void:

    match instance.state:
        SpeciesData.State.ABSENT:
            _tick_absent(instance, ctx)
        SpeciesData.State.VISITING:
            _tick_visiting(instance, ctx)
        SpeciesData.State.RESIDENT:
            _tick_resident(instance, ctx)

static func _tick_absent(
    i: AnimalInstance, ctx: LandContext
) -> void:
    if not TierManager.is_unlocked(i.data):
        return
    if FloraChecker.visit_conditions_met(i.data, ctx):
        # Random chance each day — rarer species visit less often
        var roll_chance := _visit_probability(i.data.rarity)
        if randf() < roll_chance:
            i.state = SpeciesData.State.VISITING

static func _tick_visiting(
    i: AnimalInstance, ctx: LandContext
) -> void:
    if not FloraChecker.visit_conditions_met(i.data, ctx):
        # Conditions deteriorated — animal leaves
        i.state = SpeciesData.State.ABSENT
        return
    if ctx.disturbance_level <= i.data.visit_disturbance_max:
        i.record_undisturbed_visit()
    else:
        i.disturb(ctx.disturbance_level)
        return
    if i.can_attempt_residency() \
       and FloraChecker.residency_conditions_met(i.data, ctx):
        i.state = SpeciesData.State.RESIDENT

static func _tick_resident(
    i: AnimalInstance, ctx: LandContext
) -> void:
    # Residents leave only on severe sustained disturbance
    if ctx.disturbance_level > 0.8:
        i.disturb(ctx.disturbance_level)
        if i.trust_counter < 0.1:
            i.state = SpeciesData.State.VISITING
    else:
        # Slowly rebuild trust while resident and undisturbed
        i.trust_counter = minf(1.0, i.trust_counter + 0.05)

static func _visit_probability(rarity: SpeciesData.Rarity) -> float:
    match rarity:
        SpeciesData.Rarity.COMMON:    return 0.6
        SpeciesData.Rarity.UNCOMMON:  return 0.3
        SpeciesData.Rarity.RARE:      return 0.1
        SpeciesData.Rarity.LEGENDARY: return 0.03
        _:                             return 0.5
