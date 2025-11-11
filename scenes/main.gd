extends Node3D

@export var life: Life
@export_range(8, 64) var board_size: int = 32
@export var draw_parent: Node3D
@export var cell_materials: Array[Material]
@export var auto_process := false

var _cells: PackedByteArray

var thread := Thread.new()
var mutex := Mutex.new()
var semaphore := Semaphore.new()



func _ready() -> void:
	_cells = PackedByteArray()
	life.init(_cells, board_size)

	_draw_life()

	thread.start(_simulate_thread)
	_simulated = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		semaphore.post()
		thread.wait_to_finish()


func _process(_delta: float) -> void:
	if auto_process:
		#_simulate()
		#_draw_life()
		#set_process(false)
		#var tw := create_tween()
		#tw.tween_interval(0.15)
		#tw.tween_callback(set_process.bind(true))
		if _simulated:
			print("aaa")
			semaphore.post()
			_draw_life()
			_simulated = false
	else:
		if Input.is_action_just_pressed(&"ui_accept"):
			print(":=")
			_simulate()
			_draw_life()


func _simulate() -> void:
	var newc := life.generation(PackedByteArray(_cells), board_size)
	_cells = newc
	_simulated = true


var _simulated := false
func _simulate_thread() -> void:
	while true:
		semaphore.wait()
		_simulate()



var _boxes: Dictionary[int, MeshInstance3D]
func _draw_life() -> void:
	if _boxes.is_empty():
		draw_parent.get_children().map(func(n: Node) -> void: n.queue_free())

	var ix := 0
	for x in board_size:
		for y in board_size:
			for z in board_size:
				if not ix in _boxes:
					var cube := MeshInstance3D.new()
					#cube.mesh.size = Vector3.ONE * 0.5
					cube.position = Vector3(x - board_size * 0.5, y, z - board_size * 0.5)
					draw_parent.add_child(cube)
					cube.mesh = BoxMesh.new()
					_boxes[ix] = cube
				var cell = _cells[ix]
				if cell - 1 < cell_materials.size():
					_boxes[ix].material_override = cell_materials[cell - 1]
				else:
					_boxes[ix].material_override = null
				_boxes[ix].visible = cell != 0
				ix += 1
