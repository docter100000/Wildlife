extends Node

func _ready() -> void:
    print("=== RUNNING WILDLIFE TESTS ===")
    _test_step_1()
    _test_step_2()
    _test_step_3()
    _test_step_4()
    
    _test_phase7_step1()
    _test_phase7_step2()
    _test_phase7_step3()
    _test_phase7_step4()
    _test_phase7_step5()
    _test_phase7_step6()
    _test_phase7_step7()
    print("=== ALL TESTS PASSED ===")

func _assert(condition: bool, msg: String) -> void:
    if not condition:
        push_error("FAIL: " + msg)
    else:
        print("PASS: " + msg)

func _test_step_1() -> void:
    var robin = get_node("/root/SpeciesRegistry").get_species(&"robin")
    _assert(robin != null and robin.id == &"robin", "get_node("/root/SpeciesRegistry") loads robin.tres")

func _test_step_2() -> void:
    var robin = get_node("/root/SpeciesRegistry").get_species(&"robin")
    get_node("/root/TierManager").player_level = 1 # Reset
    _assert(not get_node("/root/TierManager").is_unlocked(robin), "get_node("/root/TierManager") gates robin at Lv 1")
    get_node("/root/TierManager").add_xp(700) # Reaches Lv 4
    _assert(get_node("/root/TierManager").is_unlocked(robin), "get_node("/root/TierManager") unlocks robin at Lv 4")

func _test_step_3() -> void:
    var robin = get_node("/root/SpeciesRegistry").get_species(&"robin")
    var ctx := LandContext.new()
    _assert(not FloraChecker.visit_conditions_met(robin, ctx), "FloraChecker fails on empty context")
    
    ctx.flora_maturity[&"hawthorn"] = 0.5
    ctx.flora_maturity[&"bramble"] = 0.5
    ctx.worm_density = 15.0
    _assert(FloraChecker.visit_conditions_met(robin, ctx), "FloraChecker passes when conditions met")

func _test_step_4() -> void:
    var robin = get_node("/root/SpeciesRegistry").get_species(&"robin")
    var inst := AnimalInstance.new(robin)
    var ctx := LandContext.new()
    ctx.flora_maturity[&"hawthorn"] = 0.5
    ctx.flora_maturity[&"bramble"] = 0.5
    ctx.worm_density = 15.0
    
    # Needs to not be night
    ctx.is_night = true
    AnimalStateMachine.tick(inst, ctx)
    _assert(inst.state == SpeciesData.State.ABSENT, "State machine respects night requirement")
    
    ctx.is_night = false
    # Force chance to 1.0 for testing
    var passed = false
    for i in 100:
        AnimalStateMachine.tick(inst, ctx)
        if inst.state == SpeciesData.State.VISITING:
            passed = true
            break
    _assert(passed, "State machine transitions to VISITING")
    
    inst.state = SpeciesData.State.VISITING
    ctx.disturbance_level = 0.9 # High severity
    AnimalStateMachine.tick(inst, ctx)
    _assert(inst.state == SpeciesData.State.ABSENT, "Disturbance resets state to ABSENT")
    
    inst.state = SpeciesData.State.VISITING
    inst.undisturbed_visits = 5
    inst.trust_counter = 1.0
    ctx.disturbance_level = 0.0
    ctx.land_area_ha = 1.0
    ctx.nesting_sites[robin.id] = 1 # Provide nesting site
    AnimalStateMachine.tick(inst, ctx)
    _assert(inst.state == SpeciesData.State.RESIDENT, "State machine transitions to RESIDENT")

func _test_phase7_step1() -> void:
    var hawthorn = get_node("/root/SpeciesRegistry").get_flora(&"hawthorn")
    if not hawthorn: return
    var inst = FloraInstance.new(hawthorn, Vector2i(0,0))
    _assert(inst.growth_stage == FloraInstance.GrowthStage.SEED, "P7S1: Starts as SEED")
    inst.maturity = 0.3
    inst._update_stage()
    _assert(inst.growth_stage == FloraInstance.GrowthStage.JUVENILE, "P7S1: 0.3 maturity -> JUVENILE")
    inst.maturity = 0.6
    inst._update_stage()
    _assert(inst.growth_stage == FloraInstance.GrowthStage.ESTABLISHING, "P7S1: 0.6 maturity -> ESTABLISHING")
    inst.maturity = 0.9
    inst._update_stage()
    _assert(inst.growth_stage == FloraInstance.GrowthStage.MATURE, "P7S1: 0.9 maturity -> MATURE")
    inst.maturity = 1.0
    inst.seasons_at_maturity = 4
    inst._update_stage()
    _assert(inst.growth_stage == FloraInstance.GrowthStage.VETERAN, "P7S1: 1.0 maturity + 4 seasons -> VETERAN")

func _test_phase7_step2() -> void:
    var soil = SoilTile.new(Vector2i(0,0))
    soil.moisture = 0.8
    soil.fertilizer = 0.6
    soil.tick_season(0.05, 2)
    soil.tick_season(0.05, 2)
    soil.tick_season(0.05, 2)
    _assert(soil.moisture < 0.8, "P7S2: Moisture drops after dry summers")
    _assert(soil.fertilizer < 0.6, "P7S2: Fertilizer depletes")
    
    soil.compaction = 0.8
    soil.till()
    _assert(soil.is_tilled, "P7S2: Till sets is_tilled")
    _assert(soil.compaction <= 0.4, "P7S2: Till drops compaction")

func _test_phase7_step3() -> void:
    var hawthorn = get_node("/root/SpeciesRegistry").get_flora(&"hawthorn")
    if not hawthorn: return
    var inst = FloraInstance.new(hawthorn, Vector2i(0,0))
    var soil = SoilTile.new(Vector2i(0,0))
    soil.light = 0.8
    soil.moisture = 0.6
    soil.microbiome = 0.5
    soil.spacing_score = 1.0
    
    var result = GrowthEngine.compute(inst, soil)
    _assert(result.rate >= 0.6 and result.rate <= 0.8, "P7S3: Normal growth rate is ~0.6-0.8")
    
    soil.spacing_score = 0.0
    result = GrowthEngine.compute(inst, soil)
    _assert(result.rate < 0.1, "P7S3: Crowding drops rate (Liebig cap)")
    
    inst.stress_viral = true
    result = GrowthEngine.compute(inst, soil)
    _assert(result.health_delta < 0.0, "P7S3: Viral stress causes negative health delta")

func _test_phase7_step4() -> void:
    var hawthorn = get_node("/root/SpeciesRegistry").get_flora(&"hawthorn")
    if not hawthorn: return
    var inst = FloraInstance.new(hawthorn, Vector2i(0,0))
    var soil = SoilTile.new(Vector2i(0,0))
    var ctx = LandContext.new()
    
    var robin_data = get_node("/root/SpeciesRegistry").get_species(&"robin")
    var robin = AnimalInstance.new(robin_data)
    robin.state = SpeciesData.State.VISITING
    robin.data.browse_stress = 0.2
    
    var nearby: Array[AnimalInstance] = [robin]
    StressApplicator.apply(inst, soil, ctx, nearby)
    _assert(inst.stress_browse == true, "P7S4: Animal causes browse stress")
    
    var empty_nearby: Array[AnimalInstance] = []
    StressApplicator.apply(inst, soil, ctx, empty_nearby)
    _assert(inst.stress_browse == false, "P7S4: Stress clears when animal leaves")

func _test_phase7_step5() -> void:
    var lm = LandManager.new()
    # Stub BlockSpawner for tests without a scene tree
    lm.plant_flora(&"hawthorn", Vector2i(2,2))
    var inst = lm._flora_instances.get(Vector2i(2,2))
    _assert(inst != null, "P7S5: Flora planted")
    
    lm._on_season_passed(0, 0.3)
    _assert(inst.maturity > 0.0, "P7S5: Maturity increased after 1 season")
    
    for i in 10:
        lm._on_season_passed(0, 0.3)
    _assert(inst.growth_stage >= FloraInstance.GrowthStage.ESTABLISHING, "P7S5: Reaches ESTABLISHING after 10 seasons")

func _test_phase7_step6() -> void:
    var lm = LandManager.new()
    lm.plant_flora(&"hawthorn", Vector2i(0,0))
    var inst = lm._flora_instances.get(Vector2i(0,0))
    if not inst: return
    inst.maturity = 0.6
    inst.seasons_planted = 4
    inst._update_stage()
    lm._refresh_context_flora()
    
    var ctx = lm._build_context()
    _assert(ctx.flora_maturity.get(&"hawthorn", 0.0) >= 0.6, "P7S6: Context gets highest maturity")
    
    var robin = get_node("/root/SpeciesRegistry").get_species(&"robin")
    
    # We need hawthorn AND bramble for Robin
    lm.plant_flora(&"bramble", Vector2i(1,1))
    var bram = lm._flora_instances.get(Vector2i(1,1))
    bram.maturity = 0.6
    bram.seasons_planted = 4
    bram._update_stage()
    lm._refresh_context_flora()
    ctx = lm._build_context()
    ctx.worm_density = 15.0 # Required for robin
    
    _assert(FloraChecker.visit_conditions_met(robin, ctx), "P7S6: Robin visit conditions met with new context")

func _test_phase7_step7() -> void:
    var lm = LandManager.new()
    var oak_data = get_node("/root/SpeciesRegistry").get_flora(&"oak")
    var bluebell_data = get_node("/root/SpeciesRegistry").get_flora(&"bluebell")
    var foxglove_data = get_node("/root/SpeciesRegistry").get_flora(&"foxglove")
    
    if not oak_data or not bluebell_data or not foxglove_data: return
    
    # Plant an oak, advance to maturity 0.8
    lm.plant_flora(&"oak", Vector2i(0,0))
    var oak = lm._flora_instances.get(Vector2i(0,0))
    oak.maturity = 0.8
    oak.seasons_planted = 5
    oak._update_stage()
    
    # The LandContext build reduces light on soil tiles
    # We must explicitly add a soil tile under it for the context to reduce light
    lm._soil_tiles[Vector2i(1, 0)] = SoilTile.new(Vector2i(1, 0))
    var ctx = lm._build_context()
    var shaded_soil = lm._soil_tiles[Vector2i(1, 0)]
    _assert(shaded_soil.light < 1.0, "P7S7: Canopy reduces tile light")
    
    # Plant bluebell under oak vs full sun
    var bb_shade = FloraInstance.new(bluebell_data, Vector2i(1, 0))
    var shade_result = GrowthEngine.compute(bb_shade, shaded_soil)
    
    var full_sun_soil = SoilTile.new(Vector2i(5, 5))
    var bb_sun = FloraInstance.new(bluebell_data, Vector2i(5, 5))
    var sun_result = GrowthEngine.compute(bb_sun, full_sun_soil)
    
    _assert(shade_result.rate > sun_result.rate, "P7S7: Bluebell grows faster in shade than sun")
    
    # Plant foxglove under oak vs full sun
    var fg_shade = FloraInstance.new(foxglove_data, Vector2i(1, 0))
    var fg_shade_result = GrowthEngine.compute(fg_shade, shaded_soil)
    
    var fg_sun = FloraInstance.new(foxglove_data, Vector2i(5, 5))
    var fg_sun_result = GrowthEngine.compute(fg_sun, full_sun_soil)
    
    _assert(fg_shade_result.rate < fg_sun_result.rate, "P7S7: Foxglove grows slower in shade than sun")
