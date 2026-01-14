class_name VolumetricController extends Simulator

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

@export var brick_size: int = 16 # 16x16x16 voxels per brick
var brick_grid_size: Vector3i # Calculated as grid_size / brick_size
@export var grid_size := 512 # 512^3 = 134,217,728 voxels
@export var mesh_instance: MeshInstance3D
@export var material: ShaderMaterial
@export var sim_seed: int = int(PI * 250)
@export var simulte: bool = false


func _process(_delta):
	if simulte:
		run_simulation_once()
		if sim_seed >= int(PI * 1000):
			sim_seed = 0
		else:
			sim_seed += 1
		build_brick_map()
		bind_texture_to_material()

func _ready():
	rd = RenderingServer.get_rendering_device()
	assert(rd, "Couldnt' get rendering device")

	# Calculate brick grid dimensions
	var brick_grid_size1 := int(ceil(float(grid_size) / float(brick_size)))
	brick_grid_size = Vector3i(brick_grid_size1, brick_grid_size1, brick_grid_size1)

	#print("Brick grid size: ", brick_grid_size)

	# Setup
	setup_compute_pipeline()
	setup_brick_pipeline()
	create_texture()
	create_brick_map_texture()

	# Run Simulation
	# This queues the commands on the GPU but doesn't execute them instantly.
	#run_simulation_once()

	# Build Brick Map
	# Analyze voxel data and create brick occupancy map
	build_brick_map()

	# Bind to Material
	# We bind immediately. The GPU barrier is now handled automatically by the engine.
	bind_texture_to_material()


func setup_compute_pipeline():
	var shader_file := load("res://shaders/dummy_simulation.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)


func setup_brick_pipeline():
	var shader_file: RDShaderFile = load("res://shaders/brick_map_builder.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	brick_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	brick_pipeline_rid = rd.compute_pipeline_create(brick_shader_rid)


func create_texture():
	var fmt := RDTextureFormat.new()
	fmt.width = grid_size # No packing - each voxel gets its own texel
	fmt.height = grid_size
	fmt.depth = grid_size
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D

	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		#| RenderingDevice.TEXTURE_USAGE_CPU_READ_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	texture_rid = rd.texture_create(fmt, RDTextureView.new())
	if not texture_rid.is_valid():
		printerr("CRITICAL ERROR: Failed to create voxel texture! Grid size ", grid_size, " might be too large for VRAM.")
		return


func create_brick_map_texture():
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


func run_simulation_once():
	if not texture_rid.is_valid():
		return

	var uniform := RDUniform.new() # Create uniform for texture
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE # Set uniform type to image
	uniform.binding = 0 # Set binding to 0
	uniform.add_id(texture_rid) # Add texture ID

	var uniform_set := rd.uniform_set_create([uniform], shader_rid, 0) # Create uniform set

	var compute_list := rd.compute_list_begin() # Begin compute list
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid) # Bind compute pipeline
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set

	# Push constant for seed
	var push_constant := PackedByteArray()
	push_constant.resize(16) # Padding to 16 bytes to match shader alignment
	push_constant.encode_u32(0, sim_seed)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

	rd.compute_list_dispatch(compute_list, # Dispatch compute list
		int(ceil(grid_size / 8.0)), # grid_size / workgroup size
		int(ceil(grid_size / 8.0)),
		int(ceil(grid_size / 8.0))
	)

	rd.compute_list_end() # End compute list


func build_brick_map():
	if not texture_rid.is_valid() or not brick_map_texture_rid.is_valid():
		return

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
	#print("Brick map built")


func bind_texture_to_material():
	# Create texture wrappers
	var texture_rd := Texture3DRD.new() # Create texture wrapper
	if texture_rid.is_valid():
		texture_rd.texture_rd_rid = texture_rid # Set texture ID
	else:
		printerr("Cannot bind texture: Invalid RID")
		return

	var brick_map_rd := Texture3DRD.new() # Create brick map texture wrapper
	if brick_map_texture_rid.is_valid():
		brick_map_rd.texture_rd_rid = brick_map_texture_rid # Set brick map texture ID
	else:
		return
	if mesh_instance:
		var mat := mesh_instance.get_active_material(0) as ShaderMaterial # Get active material
		if mat:
			mat.set_shader_parameter("simulation_data", texture_rd) # Set simulation data
			mat.set_shader_parameter("brick_map", brick_map_rd) # Set brick map
			mat.set_shader_parameter("brick_size", brick_size) # Set brick size
			mat.set_shader_parameter("render_setting", render_setting) # Set render setting
			#mat.set_shader_parameter("seed", sim_seed) # Set seed
		#print("Textures bound to material")
	elif material:
		material.set_shader_parameter("simulation_data", texture_rd)
		#material.set_shader_parameter("seed", sim_seed)
	else:
		printerr("ERROR: No ShaderMaterial found on VolumetricController")


func get_draw_data_async(callback: Callable) -> void:
	rd.texture_get_data_async(texture_rid, 0, callback)


func get_grid_size() -> int:
	return grid_size


func update_data(data: PackedByteArray) -> void:
	rd.texture_update(texture_rid, 0, data)
	build_brick_map()
