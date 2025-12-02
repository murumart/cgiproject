extends Node

var rd: RenderingDevice
var texture_rid: RID
var shader_rid: RID
var pipeline_rid: RID

# Brick map optimization
var brick_map_texture_rid: RID
var brick_shader_rid: RID
var brick_pipeline_rid: RID

@export var render_setting: int = 0:
	set(value):
		render_setting = value
		if mesh_instance:
			var mat = mesh_instance.get_active_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("render_setting", render_setting)

@export var brick_size: int = 8 # 8x8x8 voxels per brick
var brick_grid_size: Vector3i # Calculated as grid_size / brick_size
@export var grid_size := 512 # 512^3 = 134,217,728 voxels
@export var mesh_instance: MeshInstance3D
@export var material: ShaderMaterial


func _ready():
	rd = RenderingServer.get_rendering_device()
	if not rd: return

	# Calculate brick grid dimensions
	brick_grid_size = Vector3i(
		int(grid_size / brick_size),
		int(grid_size / brick_size),
		int(grid_size / brick_size)
	)
	print("Brick grid size: ", brick_grid_size)

	# 1. Setup
	setup_compute_pipeline()
	setup_brick_pipeline()
	create_texture()
	create_brick_map_texture()
	
	# 2. Run Simulation
	# This queues the commands on the GPU but doesn't execute them instantly.
	run_simulation_once()
	
	# 3. Build Brick Map
	# Analyze voxel data and create brick occupancy map
	build_brick_map()
	
	# 4. Bind to Material
	# We bind immediately. The GPU barrier is now handled automatically by the engine.
	bind_texture_to_material()


func setup_compute_pipeline():
	var shader_file = load("res://shaders/dummy_simulation.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

func setup_brick_pipeline():
	var shader_file = load("res://shaders/brick_map_builder.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	brick_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	brick_pipeline_rid = rd.compute_pipeline_create(brick_shader_rid)

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

func create_brick_map_texture():
	var fmt = RDTextureFormat.new()
	fmt.width = brick_grid_size.x
	fmt.height = brick_grid_size.y
	fmt.depth = brick_grid_size.z
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	brick_map_texture_rid = rd.texture_create(fmt, RDTextureView.new())
	print("Brick map texture created: ", brick_grid_size, " = ", brick_grid_size.x * brick_grid_size.y * brick_grid_size.z, " bricks")

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

func build_brick_map():
	# Create uniforms for brick map builder
	var voxel_uniform = RDUniform.new()
	voxel_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	voxel_uniform.binding = 0
	voxel_uniform.add_id(texture_rid)
	
	var brick_uniform = RDUniform.new()
	brick_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	brick_uniform.binding = 1
	brick_uniform.add_id(brick_map_texture_rid)
	
	var uniform_set = rd.uniform_set_create([voxel_uniform, brick_uniform], brick_shader_rid, 0)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, brick_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	# Push constant for brick size
	var push_constant := PackedByteArray()
	push_constant.resize(16) # Padding to 16 bytes to match shader alignment
	push_constant.encode_u32(0, brick_size)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	
	# Dispatch with workgroup size 8x8x8 (from shader)
	# Each workgroup handles one brick, so we dispatch exactly brick_grid_size workgroups
	rd.compute_list_dispatch(compute_list,
		brick_grid_size.x,
		brick_grid_size.y,
		brick_grid_size.z
	)
	
	rd.compute_list_end()
	print("Brick map built")

func bind_texture_to_material():
	# Create texture wrappers
	var texture_rd = Texture3DRD.new()
	texture_rd.texture_rd_rid = texture_rid
	
	var brick_map_rd = Texture3DRD.new()
	brick_map_rd.texture_rd_rid = brick_map_texture_rid
	if mesh_instance:
		var mat = mesh_instance.get_active_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("simulation_data", texture_rd)
			mat.set_shader_parameter("brick_map", brick_map_rd)
			mat.set_shader_parameter("brick_size", brick_size)
			mat.set_shader_parameter("render_setting", render_setting)
		print("Textures bound to material")
	else:
		printerr("ERROR: No ShaderMaterial found on MeshInstance3D")
	if material:
		material.set_shader_parameter("simulation_data", texture_rd)
	else:
		printerr("ERROR: No ShaderMaterial found on VolumetricController")
