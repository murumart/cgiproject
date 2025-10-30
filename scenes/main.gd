extends Node3D

@export var life: Life
@export_range(0, 1) var living_initially_chance: float = 0.05
@export_range(16, 64) var board_size: int = 32
@export var draw_parent: Node3D

var _cells: PackedByteArray


func _ready() -> void:
	_cells = PackedByteArray()
	_cells.resize(board_size * board_size * board_size) # is in 3D
	for i in _cells.size():
		_cells[i] = 1 if randf() <= living_initially_chance else 0

	_draw_life()


func _process(_delta: float) -> void:
	_simulate()
	_draw_life()

	set_process(false)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(set_process.bind(true))



func _simulate() -> void:
	_cells = life.generation(PackedByteArray(_cells), board_size)


var _boxes: Dictionary[int, MeshInstance3D]
func _draw_life() -> void:
	if _boxes.is_empty():
		draw_parent.get_children().map(func(n: Node) -> void: n.queue_free())

	for x in board_size:
		for y in board_size:
			for z in board_size:
				var ix := Life.ix3d(x, y, z, board_size)
				if not ix in _boxes:
					var cube := MeshInstance3D.new()
					#cube.mesh.size = Vector3.ONE * 0.5
					cube.position = Vector3(x - board_size * 0.5, y, z - board_size * 0.5)
					draw_parent.add_child(cube)
					cube.mesh = BoxMesh.new()
					_boxes[ix] = cube
				_boxes[ix].visible = _cells[ix] == 1
