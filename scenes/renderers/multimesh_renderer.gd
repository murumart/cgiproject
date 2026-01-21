extends Renderer

@export var instance_parent: Node3D
@export var core_mesh_instance: MultiMeshInstance3D
@export var leaf_mesh_instance: MultiMeshInstance3D
@export var bark_mesh_instance: MultiMeshInstance3D

var instances: Array[MultiMeshInstance3D]

var simulator: Simulator

var _cells: PackedByteArray


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
	if instance_parent:
		instance_parent.visible = not disabled


func set_simulator(sim: Simulator) -> void:
	if simulator:
		simulator.simulation_updated.disconnect(_sim_updated)
	simulator = sim
	var gs := sim.get_grid_size()
	_cells.resize(gs * gs * gs)
	instance_parent.scale = Vector3.ONE * 100.0 / gs
	for inst: MultiMeshInstance3D in instances.slice(1):
		inst.multimesh.instance_count = gs * gs * gs
		var ix := 0
		for z in gs: for y in gs: for x in gs:
			var tf := Transform3D.IDENTITY
			tf.origin = Vector3(x, y, z) + Vector3.ONE * 0.5
			inst.multimesh.set_instance_transform(ix, tf)
			ix += 1
	simulator.simulation_updated.connect(_sim_updated)


func _draw_life() -> void:
	var gs := simulator.get_grid_size()
	var ix := 0
	for z in gs: for y in gs: for x in gs:
		var cell := _cells[ix]
		if cell != 0:
			if cell < 0 or cell > 3: # something fucked is occurring
				simulator.get_draw_data_async(_data_get)
				return
			var instance := instances[cell]
			var tf := instance.multimesh.get_instance_transform(ix)
			tf.basis = Basis.from_scale(Vector3.ONE)
			instance.multimesh.set_instance_transform(ix, tf)
		else:
			for instance: MultiMeshInstance3D in instances.slice(1):
				var tf := instance.multimesh.get_instance_transform(ix)
				tf.basis = Basis.from_scale(Vector3.ZERO)
				instance.multimesh.set_instance_transform(ix, tf)
		ix += 1
