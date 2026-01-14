@abstract class_name Renderer extends Node

@export var disabled := false

@abstract func change_render_setting(by: int) -> void
@abstract func set_disabled(to: bool) -> void


func _ready() -> void:
	set_disabled(disabled)
