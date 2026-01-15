@abstract class_name Simulator extends Node

const UIB = preload("res://scenes/ui/ui_button.gd")

signal simulation_updated

@abstract func get_grid_size() -> int
@abstract func set_grid_size(to: int) -> void
@abstract func is_sim_running() -> bool
@abstract func sim_set_running(to: bool) -> void

@abstract func get_draw_data_async(callback: Callable) -> void
@abstract func update_data(data: PackedByteArray) -> void

@abstract func reset() -> void

func _ready() -> void: pass
