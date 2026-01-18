extends Node3D

@export var life: Life
@export_range(8, 64) var board_size: int = 32
@export var draw_parent: Node3D
@export var cell_materials: Array[Material]
@export var auto_process := false
@export var lattice: LatticeMeshInstance




var mutex := Mutex.new()



func _ready() -> void:
	# _cells = PackedByteArray()
	#life.init(_cells, board_size)

	#_draw_life()

	#thread.start(_simulate_thread)
	#_simulated = true

	lattice.generate()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action(&"ui_end") and event.is_pressed():
		get_viewport().debug_draw = (get_viewport().debug_draw + 1) % 5


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("ö")
