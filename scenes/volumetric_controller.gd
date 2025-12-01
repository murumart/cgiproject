extends Node

var rd: RenderingDevice
var texture_rid: RID
var shader_rid: RID
var pipeline_rid: RID

@export var grid_size := 512 # 512^3 = 134,217,728 voxels
@export var mesh_instance: MeshInstance3D
@export var material: ShaderMaterial


func _ready():
	rd = RenderingServer.get_rendering_device()
	if not rd: return

	# 1. Setup
	setup_compute_pipeline()
	create_texture()
	
	# 2. Run Simulation
	# This queues the commands on the GPU but doesn't execute them instantly.
	run_simulation_once()
	
	# 3. Bind to Material
	# We bind immediately. The GPU barrier is now handled automatically by the engine.
	bind_texture_to_material()


func setup_compute_pipeline():
	var shader_file = load("res://shaders/dummy_simulation.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)


func create_texture():
	var fmt = RDTextureFormat.new()
	fmt.width = grid_size
	fmt.height = grid_size
	fmt.depth = grid_size
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	texture_rid = rd.texture_create(fmt, RDTextureView.new())


func run_simulation_once():
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rid)
	
	var uniform_set = rd.uniform_set_create([uniform], shader_rid, 0)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	rd.compute_list_dispatch(compute_list,
		int(grid_size / 8.0),
		int(grid_size / 8.0),
		int(grid_size / 8.0)
	)
	
	rd.compute_list_end()


func bind_texture_to_material():
	var texture_rd = Texture3DRD.new()
	texture_rd.texture_rd_rid = texture_rid
	
	if material:
		material.set_shader_parameter("simulation_data", texture_rd)
	else:
		printerr("ERROR: No ShaderMaterial found on MeshInstance3D")
