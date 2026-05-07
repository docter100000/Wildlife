extends RichTextLabel

@export var land_manager: LandManager
var _visible_overlay := false

func _ready() -> void:
    visible = false

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_debug"):  # map F1 in InputMap
        _visible_overlay = !_visible_overlay
        visible = _visible_overlay

func _process(_delta: float) -> void:
    if not _visible_overlay: return
    var b := PackedStringArray()

    # ── Time ────────────────────────────────────────────────────────
    b.append("[b]Time[/b]  Yr %d  %s  Day %d  Hr %02d  %s\n" % [
        TimeSystem.current_year,
        TimeSystem.get_season_name(),
        TimeSystem.current_day,
        TimeSystem.current_hour,
        "NIGHT" if TimeSystem.is_night else "DAY"
    ])

    # ── Player ──────────────────────────────────────────────────────
    b.append("[b]Player[/b]  Lv %d  XP %d  Tool: %s\n" % [
        TierManager.player_level,
        TierManager.current_xp,
        ToolSystem.Tool.keys()[ToolSystem.active_tool]
    ])

    if not land_manager:
        text = "ERROR: LandManager export not assigned in Inspector!"
        return

    # ── Land ────────────────────────────────────────────────────────
    b.append("[b]Land[/b]  %.2f ha  Disturbance: %.2f\n" % [
        land_manager.tile_grid.get_land_area_ha(),
        land_manager.tile_grid.get_average_disturbance()
    ])

    # ── Animals ─────────────────────────────────────────────────────
    b.append("[b]Animals[/b]\n")
    var states := ["ABSENT","VISIT","RESIDE"]
    for inst in land_manager._instances:
        var col := "gray"
        if inst.state == 1: col = "yellow"
        if inst.state == 2: col = "green"
        b.append("  [color=%s]%s[/color] — %s  trust:%.2f  visits:%d\n" % [
            col,
            inst.data.display_name,
            states[inst.state],
            inst.trust_counter,
            inst.undisturbed_visits
        ])

    # ── Flora ───────────────────────────────────────────────────────
    b.append("[b]Flora[/b]\n")
    var stage_names := ["SEED","SEEDLING","JUV","ESTAB","MATURE","VETERAN"]
    for pos in land_manager._flora_instances:
        var inst: FloraInstance = land_manager._flora_instances[pos]
        var stress_flags := ""
        if inst.stress_browse:   stress_flags += "B"
        if inst.stress_drought:  stress_flags += "D"
        if inst.stress_fungal:   stress_flags += "F"
        if inst.stress_invasive: stress_flags += "I"
        if inst.stress_viral:    stress_flags += "V"
        if inst.stress_waterlog: stress_flags += "W"
        b.append("  %s @(%d,%d) %s m:%.2f h:%.2f r:%.2f%s\n" % [
            inst.data.display_name,
            pos.x, pos.y,
            stage_names[inst.growth_stage],
            inst.maturity,
            inst.health,
            inst.last_growth_rate,
            " [color=red][%s][/color]" % stress_flags if stress_flags else ""
        ])

    text = "".join(b)
