extends Renderer

@export var instance_parent: Node3D
@export var cells_mesh_instance: MultiMeshInstance3D

# var instance: MultiMeshInstance3D

var simulator: Simulator

var _cells: PackedByteArray


func _ready() -> void:
	super()
	cells_mesh_instance.multimesh.use_colors = true
	cells_mesh_instance.multimesh.use_custom_data = true
	# var mesh = cells_mesh_instance.multimesh.mesh

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/multiMeshInstance.gdshader")

	# mesh.surface_set_material(0, mat)
	cells_mesh_instance.material_override = mat


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
	_cells.resize(gs * gs * gs)
	instance_parent.scale = Vector3.ONE * 100.0 / gs
	var tf := Transform3D.IDENTITY
	var offsetVector := Vector3.ONE * 0.5
	var volume := gs * gs * gs
	if (cells_mesh_instance.multimesh.instance_count != volume):
		cells_mesh_instance.multimesh.instance_count = gs * gs * gs
		var ix := 0
		for z in gs: for y in gs: for x in gs:
			tf.origin = Vector3(x, y, z) + offsetVector
			cells_mesh_instance.multimesh.set_instance_transform(ix, tf)
			ix += 1
	simulator.simulation_updated.connect(_sim_updated)


func _draw_life() -> void:
	var gs := simulator.get_grid_size()
	# var zero := Basis.from_scale(Vector3.ZERO)
	# var one := Basis.from_scale(Vector3.ONE)
	# var tf := Transform3D.IDENTITY
	# var ix := 0
	for i in gs*gs*gs:
		cells_mesh_instance.multimesh.set_instance_custom_data(i, Color(_cells[i],0,0,0))
	# for z in gs: for y in gs: for x in gs:
	# 	var cell := _cells[ix]
	# 	if cell != 0:
	# 		if cell < 0 or cell > 3: # something fucked is occurring
	# 			simulator.get_draw_data_async(_data_get)
	# 			return
	# 		var instance := instances[cell]
	# 		tf = instance.multimesh.get_instance_transform(ix)
	# 		tf.basis = one
	# 		instance.multimesh.set_instance_transform(ix, tf)
	# 	else:
	# 		tf = instances[1].multimesh.get_instance_transform(ix)
	# 		tf.basis = zero
	# 		for instance: MultiMeshInstance3D in instances.slice(1):
	# 			instance.multimesh.set_instance_transform(ix, tf)
	# 	ix += 1
