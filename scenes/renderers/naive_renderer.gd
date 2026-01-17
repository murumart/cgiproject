extends Renderer

@export var parent: Node3D
@export var sim: Simulator
@export var cell_materials: Array[BaseMaterial3D]

var _cells: PackedByteArray


func _ready() -> void:
	super()
	var s := sim
	sim = null
	set_simulator(s)


func set_simulator(s: Simulator) -> void:
	if sim:
		sim.simulation_updated.disconnect(_sim_updated)
	sim = s
	sim.simulation_updated.connect(_sim_updated)
	parent.scale = Vector3.ONE * 100.0 / sim.get_grid_size()


func _data_get(d: PackedByteArray) -> void:
	if disabled: return
	_cells = d
	_draw_life()


func _sim_updated() -> void:
	sim.get_draw_data_async(_data_get)


func change_render_setting(_by: int) -> void: pass


func set_disabled(to: bool) -> void:
	disabled = to
	set_process(not to)
	if parent:
		parent.visible = not disabled


var _boxes: Dictionary[int, Dictionary] = {

}
func _draw_life() -> void:
	if _boxes.is_empty():
		parent.get_children().map(func(n: Node) -> void: n.queue_free())

	var gs := sim.get_grid_size()
	var ix = 0
	for x in gs: for y in gs: for z in gs:
		# var ix := x + y * gs + z * gs * gs
		_draw_check_box(ix, x, y, z)
		_draw_update_cell(ix)
		ix += 1


var _bmesh: Array[BoxMesh]
var _cube: MeshInstance3D
func _draw_check_box(ix: int, x: int, y: int, z: int) -> void:
	if _cube == null:
		_cube = MeshInstance3D.new()
	if _bmesh.is_empty():
		for i in cell_materials.size():
			var m := BoxMesh.new()
			m.material = cell_materials[i]
			_bmesh.append(m)
	if _boxes.is_empty():
		for i in cell_materials.size():
			_boxes[i + 1] = {}
	if not ix in _boxes[1]:
		#cube.mesh.size = Vector3.ONE * 0.5
		for i in cell_materials.size():
			var matcube := _cube.duplicate()
			matcube.mesh = _bmesh[i]
			matcube.mesh.surface_set_material(0, cell_materials[i])
			matcube.position = Vector3(x, y, z) + Vector3.ONE * 0.5
			parent.add_child(matcube)
			_boxes[i + 1][ix] = matcube


func _draw_update_cell(ix: int) -> void:
	var cell := _cells[ix]
	#if cell - 1 < cell_materials.size():
		#_boxes[ix].material_override = cell_materials[cell - 1]
	#else:
		#_boxes[ix].material_override = null
	for b in _boxes:
		_boxes[b][ix].hide()
	if cell == 0: return
	_boxes[cell][ix].show()
