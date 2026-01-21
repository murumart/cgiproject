extends Renderer

const ComputeSimulator = preload("res://scenes/simulators/compute_simulator.gd")
const ComputeAutomataSimulator = preload("res://scenes/simulators/CS_cellular_automata.gd")

@export var instance_parent: Node3D
@export var cells_mesh_instance: MultiMeshInstance3D
var mat: ShaderMaterial

var rd := RenderingServer.get_rendering_device()

var simulator: Simulator

var data_texture: RID


func _ready() -> void:
	super()

	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/renderers/instance_texture.gdshader")
	cells_mesh_instance.material_override = mat


func _data_get(data: PackedByteArray) -> void:
	rd.texture_update(data_texture, 0, data)


func _sim_updated() -> void:
	if disabled: return
	simulator.get_draw_data_async(_data_get)
	bind_texture_to_material()

func _sim_updated_tex(tex: RID) -> void:
	if disabled: return
	data_texture = tex
	bind_texture_to_material()


func change_render_setting(_by: int) -> void: pass


func set_disabled(to: bool) -> void:
	disabled = to
	set_process(not to)
	if instance_parent:
		instance_parent.visible = not disabled
	if (not disabled and simulator):
		if simulator is ComputeSimulator or simulator is ComputeAutomataSimulator:
			_sim_updated_tex(simulator.get_texture_rid())
		else:
			_sim_updated()


func set_simulator(sim: Simulator) -> void:
	if simulator:
		if simulator is ComputeSimulator or simulator is ComputeAutomataSimulator:
			simulator.simulation_updated_texture.disconnect(_sim_updated_tex)
		else:
			simulator.simulation_updated.disconnect(_sim_updated)
	simulator = sim
	var gs := sim.get_grid_size()
	if simulator is ComputeSimulator or simulator is ComputeAutomataSimulator:
		simulator.simulation_updated_texture.connect(_sim_updated_tex)
	else:
		data_texture = ComputeAutomataSimulator.create_texture(rd, gs)
		simulator.simulation_updated.connect(_sim_updated)
	
	var volume := gs * gs * gs
	instance_parent.scale = Vector3.ONE * 100.0 / gs
	var tf := Transform3D.IDENTITY
	var offsetVector := Vector3.ONE * 0.5
	if (cells_mesh_instance.multimesh.instance_count != volume):
		cells_mesh_instance.multimesh.instance_count = volume
		var ix := 0
		for z in gs: for y in gs: for x in gs:
			tf.origin = Vector3(x, y, z) + offsetVector
			cells_mesh_instance.multimesh.set_instance_transform(ix, tf)
			cells_mesh_instance.multimesh.set_instance_custom_data(ix, Color(gs, 0, 0, 0))
			ix += 1


var _data_texture_rd := Texture3DRD.new() # Create texture wrapper
func bind_texture_to_material() -> void:
	# Create texture wrappers
	assert(data_texture.is_valid, "Need valid data texture")
	_data_texture_rd.texture_rd_rid = data_texture # Set texture ID

	assert(mat, "need active material on mesh instance")
	mat.set_shader_parameter("cell_tex", _data_texture_rd) # Set simulation data
