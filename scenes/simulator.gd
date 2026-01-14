@abstract class_name Simulator extends Node


@abstract func get_grid_size() -> int

@abstract func get_draw_data_async(callback: Callable) -> void
@abstract func update_data(data: PackedByteArray) -> void
