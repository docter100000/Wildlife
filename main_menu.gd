extends Control

@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var load_game_btn: Button = $VBoxContainer/LoadGameBtn
@onready var options_btn: Button = $VBoxContainer/OptionsBtn

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)
	
	# Only enable load game if a save exists
	if not SaveManager.has_save():
		load_game_btn.disabled = true

func _on_new_game() -> void:
	SaveManager.should_load_on_start = false
	get_tree().change_scene_to_file("res://main.tscn")

func _on_load_game() -> void:
	SaveManager.should_load_on_start = true
	get_tree().change_scene_to_file("res://main.tscn")

func _on_options() -> void:
	print("Options menu not yet implemented.")
