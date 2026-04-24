extends CanvasLayer

@onready var terrain: TerrainDeformer = $"../Terrain"

@onready var tool_selector: OptionButton = $MarginContainer/VBoxContainer/ToolSelector
@onready var settings_panel: PanelContainer = $MarginContainer/VBoxContainer/SettingsPanel
@onready var system_menu: MenuButton = $MarginContainer/SystemMenu

@onready var radius_slider: HSlider = $MarginContainer/VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/RadiusBox/RadiusSlider
@onready var strength_slider: HSlider = $MarginContainer/VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/StrengthBox/StrengthSlider

func _ready() -> void:
	# Populate the dropdown menu
	tool_selector.add_item("None")
	
	var spade_icon = load("res://spade_icon.svg")
	if spade_icon:
		tool_selector.add_icon_item(spade_icon, "Spade Tool")
	else:
		tool_selector.add_item("Spade Tool")
		
	var flathead_icon = load("res://flathead_icon.svg")
	if flathead_icon:
		tool_selector.add_icon_item(flathead_icon, "Smooth Tool")
	else:
		tool_selector.add_item("Smooth Tool")
	
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
		
	# Initialize state to "None"
	_on_tool_selected(0)

func _on_tool_selected(index: int) -> void:
	if index == 0:
		# "None" tool
		settings_panel.hide()
		if terrain: 
			terrain.active_tool_mode = 0 # NONE
	elif index == 1:
		# Spade Tool
		settings_panel.show()
		if terrain: 
			terrain.active_tool_mode = 1 # DIG_RAISE
	elif index == 2:
		# Smooth Tool
		settings_panel.show()
		if terrain:
			terrain.active_tool_mode = 2 # SMOOTH

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
