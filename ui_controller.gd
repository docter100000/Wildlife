extends CanvasLayer

@onready var terrain: TerrainDeformer = $"../Terrain"

@onready var tool_selector: OptionButton = $MarginContainer/VBoxContainer/ToolSelector
@onready var settings_panel: PanelContainer = $MarginContainer/VBoxContainer/SettingsPanel
@onready var system_menu: MenuButton = $MarginContainer/SystemMenu

@onready var radius_slider: HSlider = $MarginContainer/VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/RadiusBox/RadiusSlider
@onready var strength_slider: HSlider = $MarginContainer/VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/StrengthBox/StrengthSlider

@onready var add_xp_button: Button = $TestPanel/VBoxContainer/AddXPButton
@onready var next_day_button: Button = $TestPanel/VBoxContainer/NextDayButton
@onready var plant_flora_button: Button = $TestPanel/VBoxContainer/PlantFloraButton

func _ready() -> void:
	# Populate the dropdown menu with the new ToolSystem enum
	tool_selector.clear()
	for tool_key in ToolSystem.Tool.keys():
		tool_selector.add_item(tool_key.capitalize())
	
	# Connect signals for dynamic updates
	tool_selector.item_selected.connect(_on_tool_selected)
	radius_slider.value_changed.connect(_on_radius_changed)
	strength_slider.value_changed.connect(_on_strength_changed)
	
	# Set initial slider values from the terrain script
	if terrain:
		radius_slider.value = terrain.brush_radius
		strength_slider.value = terrain.brush_strength
		
	# System Menu
	var popup = system_menu.get_popup()
	popup.id_pressed.connect(_on_system_menu_id_pressed)
		
	# Test Buttons
	add_xp_button.pressed.connect(_on_add_xp_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)
	plant_flora_button.pressed.connect(_on_plant_flora_pressed)
		
	# Initialize state
	_on_tool_selected(0)

func _on_tool_selected(index: int) -> void:
	# Hide the old terrain settings panel and disable mesh deformation
	settings_panel.hide()
	if terrain: 
		terrain.active_tool_mode = TerrainDeformer.ToolMode.NONE
		
	# Update the new ToolSystem
	var active_tool := index as ToolSystem.Tool
	ToolSystem.active_tool = active_tool
	
	# Default to bramble for testing when plant tool is selected
	if active_tool == ToolSystem.Tool.PLANT:
		ToolSystem.selected_flora_id = &"bramble"

func _on_radius_changed(value: float) -> void:
	if terrain: 
		terrain.brush_radius = value

func _on_strength_changed(value: float) -> void:
	if terrain: 
		terrain.brush_strength = value

func _on_system_menu_id_pressed(id: int) -> void:
	if id == 0:
		if terrain: terrain.save_to_disk()
	elif id == 1:
		if terrain: terrain.load_from_disk()
	elif id == 2:
		get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_add_xp_pressed() -> void:
	get_node("/root/TierManager").add_xp(750)

func _on_next_day_pressed() -> void:
	get_node("/root/TimeSystem")._advance_day()

func _on_plant_flora_pressed() -> void:
	var lm = $"../LandManager"
	if lm:
		lm.debug_plant_flora()
