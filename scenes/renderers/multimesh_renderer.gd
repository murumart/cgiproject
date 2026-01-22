extends Renderer

@export var instance_parent: Node3D
@export var core_mesh_instance: MultiMeshInstance3D
@export var leaf_mesh_instance: MultiMeshInstance3D
@export var bark_mesh_instance: MultiMeshInstance3D

var instances: Array[MultiMeshInstance3D]

var simulator: Simulator

var _cells: PackedByteArray
var old_cells: PackedByteArray


func _ready() -> void:
	super()
	instances = [null, core_mesh_instance, leaf_mesh_instance, bark_mesh_instance]


func _data_get(d: PackedByteArray) -> void:
	if disabled: return
	_cells = d
	_draw_life()


func _sim_updated() -> void:
	simulator.get_draw_data_async(_data_get)


func change_render_setting(_by: int) -> void: pass


func set_disabled(to: bool) -> void:
	disabled = to
	set_process(not to)
	if instance_parent:
		instance_parent.visible = not disabled


func set_simulator(sim: Simulator) -> void:
	if simulator:
		simulator.simulation_updated.disconnect(_sim_updated)
	simulator = sim
	var gs := sim.get_grid_size()
	var volume := gs * gs * gs
	_cells.resize(volume)
	old_cells.resize(volume)
	old_cells.fill(0)
	instance_parent.scale = Vector3.ONE * 100.0 / gs
	var tf := Transform3D.IDENTITY
	tf.basis = Basis.from_scale(Vector3.ZERO)
	var offsetVector := Vector3.ONE * 0.5
	for i in range(1, instances.size()):
		instances[i].multimesh.instance_count = volume
		var ix := 0
		for z in gs: for y in gs: for x in gs:
			tf.origin = Vector3(x, y, z) + offsetVector
			instances[i].multimesh.set_instance_transform(ix, tf)
			ix += 1
	simulator.simulation_updated.connect(_sim_updated)


func _draw_life() -> void:
	for i in range(1, instances.size()):
		instances[i].hide()
	var gs := simulator.get_grid_size()
	var volume := gs * gs * gs
	if (old_cells.size() != volume):
		old_cells.resize(volume)
		old_cells.fill(0)
	var zero := Basis.from_scale(Vector3.ZERO)
	var one := Basis.from_scale(Vector3.ONE)
	var offsetVector := Vector3.ONE * 0.5
	var tf := Transform3D.IDENTITY
	var ix := 0
	for z in gs: for y in gs: for x in gs:
		if _cells[ix] == old_cells[ix]:
			ix += 1
			continue
		var cell := _cells[ix]
		tf.origin = Vector3(x, y, z) + offsetVector
		# old_cells[ix] = cell
		if cell != 0:
			if cell < 0 or cell > 3: # something fucked is occurring
				simulator.get_draw_data_async(_data_get)
				return
			var instance := instances[cell]
			# tf = instance.multimesh.get_instance_transform(ix)
			tf.basis = one
			instance.multimesh.set_instance_transform(ix, tf)
		else:
			# tf = instances[1].multimesh.get_instance_transform(ix)
			tf.basis = zero
			for i in range(1, instances.size()):
				instances[i].multimesh.set_instance_transform(ix, tf)
		ix += 1
	for i in range(1, instances.size()):
		instances[i].show()
	old_cells = _cells.duplicate()
