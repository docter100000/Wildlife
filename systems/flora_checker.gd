class_name FloraChecker
extends RefCounted

static func visit_conditions_met(
    data: SpeciesData,
    ctx: LandContext
) -> bool:

    # 1. Day/night gate
    if data.visit_requires_night and not ctx.is_night:
        return false

    # 2. All required flora present at minimum maturity
    for i in data.visit_flora_required.size():
        var flora_id    := data.visit_flora_required[i]
        var min_mature  := data.visit_flora_thresholds[i] \
                          if i < data.visit_flora_thresholds.size() \
                          else 0.0
        if not ctx.flora_at(flora_id, min_mature):
            return false

    # 3. Worm density gate
    if ctx.worm_density < data.visit_min_worm_density:
        return false

    # 4. Prey population gate
    if data.visit_min_prey_count > 0:
        var total_prey := 0
        for v in ctx.resident_counts.values():
            total_prey += v
        if total_prey < data.visit_min_prey_count:
            return false

    return true

static func residency_conditions_met(
    data: SpeciesData,
    ctx: LandContext
) -> bool:

    # Visit conditions must still hold
    if not visit_conditions_met(data, ctx):
        return false

    # 1. Extra flora requirements for residency
    for i in data.reside_flora_required.size():
        var flora_id   := data.reside_flora_required[i]
        var min_mature := data.reside_flora_thresholds[i] \
                         if i < data.reside_flora_thresholds.size() \
                         else 0.0
        if not ctx.flora_at(flora_id, min_mature):
            return false

    # 2. Nesting site
    if data.reside_needs_nesting_site:
        if ctx.nesting_sites.get(data.id, 0) == 0 \
           and ctx.nesting_sites.get("generic", 0) == 0:
            return false

    # 3. Territory size
    if ctx.land_area_ha < data.reside_min_territory_ha:
        return false

    # 4. Rival exclusion
    for rival_id in data.reside_rival_excludes:
        if ctx.rival_present(rival_id):
            return false

    return true
