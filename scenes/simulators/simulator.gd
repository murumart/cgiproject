@abstract class_name Simulator extends Node

const UIB = preload("res://scenes/ui/ui_button.gd")

signal simulation_updated

@export var pause_button: UIB

@abstract func get_grid_size() -> int
@abstract func is_sim_running() -> bool
@abstract func sim_set_running(to: bool) -> void

@abstract func get_draw_data_async(callback: Callable) -> void
@abstract func update_data(data: PackedByteArray) -> void


func _ready() -> void:
	pause_button.selected.connect(func() -> void:
		if is_sim_running():
			sim_set_running(false)
			pause_button.text = "Play Simulation"
		else:
			sim_set_running(true)
			pause_button.text = "Pause Simulation"
	)
