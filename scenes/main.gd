extends Node3D

@export var life: Life
@export_range(8, 64) var board_size: int = 32
@export var draw_parent: Node3D
@export var cell_materials: Array[Material]
@export var auto_process := false
@export var lattice: LatticeMeshInstance

var _cells: PackedByteArray

var thread := Thread.new()
var mutex := Mutex.new()
var semaphore := Semaphore.new()


func _ready() -> void:
	RenderingServer.set_debug_generate_wireframes(true)

	_cells = PackedByteArray()
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
		_stop_thread = true
		semaphore.post()
		thread.wait_to_finish()


func _process(_delta: float) -> void:
	if auto_process:
		if _simulated:
			_simulated = false
			semaphore.post()
			_draw_life()
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
var _stop_thread := false
func _simulate_thread() -> void:
	while true:
		if _stop_thread:
			break
		semaphore.wait()
		_simulate()


var _boxes: Dictionary[int, Dictionary] = {

}
func _draw_life() -> void:
	if _boxes.is_empty():
		draw_parent.get_children().map(func(n: Node) -> void: n.queue_free())

	for x in board_size:
		for y in board_size:
			for z in board_size:
				var ix := Life.ix3d(x, y, z, board_size)
				_draw_check_box(ix, x, y, z)
				_draw_update_cell(ix)


var _bmesh := BoxMesh.new()
var _cube: MeshInstance3D
func _draw_check_box(ix: int, x: int, y: int, z: int) -> void:
	if _cube == null:
		_cube = MeshInstance3D.new()
		_cube.mesh = _bmesh
	if _boxes.is_empty():
		for i in cell_materials.size():
			_boxes[i + 1] = {}
	if not ix in _boxes[1]:
		#cube.mesh.size = Vector3.ONE * 0.5
		for i in cell_materials.size():
			var matcube := _cube.duplicate()
			matcube.position = Vector3(x - board_size * 0.5, y, z - board_size * 0.5)
			draw_parent.add_child(matcube)
			matcube.material_override = cell_materials[i]
			_boxes[i + 1][ix] = matcube


func _draw_update_cell(ix: int) -> void:
	var cell = _cells[ix]
	#if cell - 1 < cell_materials.size():
		#_boxes[ix].material_override = cell_materials[cell - 1]
	#else:
		#_boxes[ix].material_override = null
	for b in _boxes:
		_boxes[b][ix].hide()
	if cell == 0: return
	_boxes[cell][ix].show()
