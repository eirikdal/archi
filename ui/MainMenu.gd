extends Control

@onready var start_button: Button = $CanvasLayer/CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CanvasLayer/CenterContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $CanvasLayer/CenterContainer/VBoxContainer/QuitButton
@onready var options_panel: Panel = $CanvasLayer/CenterContainer/VBoxContainer/OptionsPanel
@onready var fullscreen_check: CheckBox = $CanvasLayer/CenterContainer/VBoxContainer/OptionsPanel/VBoxContainer/FullscreenCheck
@onready var master_volume: HSlider = $CanvasLayer/CenterContainer/VBoxContainer/OptionsPanel/VBoxContainer/MasterVolume
@onready var back_button: Button = $CanvasLayer/CenterContainer/VBoxContainer/OptionsPanel/VBoxContainer/BackButon

const GAME_SCENE_PATH := "res://scenes/Game.tscn" # uses your existing game scene

func _ready() -> void:
	# wire up signals
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	master_volume.value_changed.connect(_on_master_volume_changed)

	# init UI state
	fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	# read current master bus dB
	var master_idx := AudioServer.get_bus_index("Master")
	master_volume.value = AudioServer.get_bus_volume_db(master_idx)

	# keyboard shortcuts
	set_process_input(true)
	start_button.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_options_pressed() -> void:
	options_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	options_panel.visible = false
	start_button.grab_focus()

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if (pressed) else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_volume_changed(db_value: float) -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, db_value)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and !options_panel.visible:
		_on_start_pressed()
	if event.is_action_pressed("ui_cancel") and options_panel.visible:
		_on_back_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
