extends Renderer

const ComputeSimulator = preload("res://scenes/simulators/compute_simulator.gd")

var rd := RenderingServer.get_rendering_device()

var brick_map_texture_rid: RID
var brick_shader_rid: RID
var brick_pipeline_rid: RID

@export var simulator: Simulator

@export var mesh_instance: MeshInstance3D

@export var brick_size: int = 16 # 16x16x16 voxels per brick
var brick_grid_size: Vector3i # Calculated as grid_size / brick_size

var data_texture: RID


@export var render_setting: int = 0:
	set(value):
		render_setting = value
		if mesh_instance:
			var mat := mesh_instance.get_active_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("render_setting", render_setting)


func _ready() -> void:
	brick_grid_size = Vector3i.ONE * int(ceil(float(simulator.get_grid_size()) / float(brick_size)))

	var s := simulator
	simulator = null
	set_simulator(s)


func _data_got(data: PackedByteArray) -> void:
	rd.texture_update(data_texture, 0, data)
	build_brick_map()
	bind_texture_to_material()


func _sim_updated() -> void:
	simulator.get_draw_data_async(_data_got)


func _sim_updated_tex(tex: RID) -> void:
	data_texture = tex
	build_brick_map()
	bind_texture_to_material()


func set_simulator(sim: Simulator) -> void:
	if simulator:
		if simulator is ComputeSimulator:
			(simulator as ComputeSimulator).simulation_updated_texture.disconnect(_sim_updated_tex)
		else:
			simulator.simulation_updated.disconnect(_sim_updated)
	simulator = sim
	if simulator is ComputeSimulator:
		(simulator as ComputeSimulator).simulation_updated_texture.connect(_sim_updated_tex)
	else:
		simulator.simulation_updated.connect(_sim_updated)

	data_texture = ComputeSimulator.create_texture(rd, simulator.get_grid_size())

	setup_brick_pipeline()
	create_brick_map_texture()
	build_brick_map()
	bind_texture_to_material()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SEMICOLON and event.is_pressed():
		print("ö")
		var d := rd.texture_get_data(data_texture, 0)
		#var img := Image.create_from_data(brick_grid_size.x, brick_grid_size.y * brick_grid_size.z, false, Image.FORMAT_R8, d)
		var img := Image.create_from_data(simulator.get_grid_size(), simulator.get_grid_size() * simulator.get_grid_size(), false, Image.FORMAT_R8, d)
		img.save_png("res://coolimage.png")


func set_disabled(to: bool) -> void:
	disabled = to
	if mesh_instance:
		mesh_instance.visible = not disabled


func change_render_setting(by: int) -> void:
	render_setting = wrapi(render_setting + by, 0, 7)
	print("Render setting: ", render_setting)


func setup_brick_pipeline() -> void:
	var shader_file: RDShaderFile = load("res://shaders/brick_map_builder.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	brick_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	brick_pipeline_rid = rd.compute_pipeline_create(brick_shader_rid)


func create_brick_map_texture() -> void:
	var fmt := RDTextureFormat.new()
	fmt.width = brick_grid_size.x
	fmt.height = brick_grid_size.y
	fmt.depth = brick_grid_size.z
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D

	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)

	brick_map_texture_rid = rd.texture_create(fmt, RDTextureView.new())
	#print("Brick map texture created: ", brick_grid_size, " = ", brick_grid_size.x * brick_grid_size.y * brick_grid_size.z, " bricks")


func build_brick_map() -> void:
	assert(data_texture.is_valid() and brick_map_texture_rid.is_valid())

	# Create uniforms for brick map builder
	var voxel_uniform := RDUniform.new()
	voxel_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	voxel_uniform.binding = 0
	voxel_uniform.add_id(data_texture)

	var brick_uniform := RDUniform.new()
	brick_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	brick_uniform.binding = 1
	brick_uniform.add_id(brick_map_texture_rid)

	var uniform_set := rd.uniform_set_create([voxel_uniform, brick_uniform], brick_shader_rid, 0)

	rd.draw_command_begin_label("BRICKMAP_PIPELINE", Color.MAGENTA)
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, brick_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Push constant for brick size
	var push_constant := PackedByteArray()
	push_constant.resize(16) # Padding to 16 bytes to match shader alignment
	push_constant.encode_u32(0, brick_size)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

	# Each workgroup handles one brick, so we dispatch exactly brick_grid_size workgroups
	rd.compute_list_dispatch(compute_list,
		brick_grid_size.x,
		brick_grid_size.y,
		brick_grid_size.z
	)

	rd.compute_list_end()
	rd.draw_command_end_label()
	#print("Brick map built")


var _data_texture_rd := Texture3DRD.new() # Create texture wrapper
var _brick_texture_rd := Texture3DRD.new() # Create brick map texture wrapper

func bind_texture_to_material() -> void:
	# Create texture wrappers
	assert(data_texture.is_valid, "Need valid data texture")
	_data_texture_rd.texture_rd_rid = data_texture # Set texture ID

	assert(brick_map_texture_rid.is_valid())
	_brick_texture_rd.texture_rd_rid = brick_map_texture_rid # Set brick map texture ID
	assert(mesh_instance, "Need a mesh instance")
	var mat := mesh_instance.mesh.surface_get_material(0) as ShaderMaterial # Get active material
	assert(mat, "need active material on mesh instance")
	mat.set_shader_parameter("simulation_data", _data_texture_rd) # Set simulation data
	mat.set_shader_parameter("brick_map", _brick_texture_rd) # Set brick map
	mat.set_shader_parameter("brick_size", brick_size) # Set brick size
	mat.set_shader_parameter("render_setting", render_setting) # Set render setting
	#mat.set_shader_parameter("seed", sim_seed) # Set seed
