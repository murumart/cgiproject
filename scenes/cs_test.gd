class_name CS_Test extends Node

# Cell automata CS
var rd: RenderingDevice
# var shader_rid: RID
var pipeline_rid: RID
var cell_uniform_set: RID
var read_state_rid: RID
var write_state_rid: RID
var kernel_rid: RID

# Aggregation CS (get state value)
var cell_type_texture_rid: RID
# var aggregate_shader_rid: RID
var aggregate_pipeline_rid: RID
var aggregate_uniform: RID

# Brick map optimization
var brick_map_texture_rid: RID
var texture_rid: RID
# var brick_shader_rid: RID
var brick_pipeline_rid: RID
var brick_uniform: RID

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

@export var typecount: int = 4 # Number of cell states
@export var kernel_size: Vector3i = Vector3i(3, 3, 3) # Kernel dimensions

@export var initial_state: PackedInt32Array
@export var kernels: PackedFloat32Array
# var i = 0


func _process(_delta):
	if mesh_instance == null:
		return
	if simulte:
		run_simulation_once()
		# print("Simulation step: ", i)
		# i += 1
		# if sim_seed >= int(PI * 1000):
		# 	sim_seed = 0
		# else:
		# 	sim_seed += 1
	bind_texture_to_material()


func _ready():
	rd = RenderingServer.get_rendering_device()
	if not rd: return

	# Calculate brick grid dimensions
	var brick_grid_size1 = int(ceil(float(grid_size) / float(brick_size)))
	brick_grid_size = Vector3i(brick_grid_size1, brick_grid_size1, brick_grid_size1)

	#print("Brick grid size: ", brick_grid_size)

	# Init variables


	# Setup
	setup_cell_pipeline()
	setup_aggregation_pipeline()
	setup_brick_pipeline()

	# Run Simulation
	# This queues the commands on the GPU but doesn't execute them instantly.
	#run_simulation_once()


func run_simulation_once():
	if not texture_rid.is_valid():
		return

	# var uniform_set = rd.uniform_set_create([], shader_rid, 0)
	var compute_list = rd.compute_list_begin() # Begin compute list
	# rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set

	dispatch_cell_automata(compute_list)
	dispatch_cell_aggregation(compute_list)

	# Build Brick Map
	# Analyze voxel data and create brick occupancy map
	dispatch_brick_map_generation(compute_list)

	rd.compute_list_end() # End compute list
	# rd.submit() # Submit compute list to GPU

	# Swap read and write buffers for next iteration
	swap_read_write()


func bind_texture_to_material():
	# Create texture wrappers
	var texture_rd = Texture3DRD.new() # Create texture wrapper
	if texture_rid.is_valid():
		texture_rd.texture_rd_rid = texture_rid # Set texture ID
	else:
		printerr("Cannot bind texture: Invalid RID")
		return

	var brick_map_rd = Texture3DRD.new() # Create brick map texture wrapper
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
		push_error("ERROR: No ShaderMaterial found on CS_Test")

func swap_read_write():
	var temp = read_state_rid
	read_state_rid = write_state_rid
	write_state_rid = temp

func dispatch_cell_automata(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid) # Bind compute pipeline
	rd.compute_list_bind_uniform_set(compute_list, cell_uniform_set, 0) # Bind uniform set

	# Push constants for cell automata
	var push_constant := PackedByteArray()
	push_constant.resize(16)
	push_constant.encode_u32(0, grid_size)
	push_constant.encode_u32(4, kernel_size.x)
	push_constant.encode_u32(8, typecount)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

	# Dispatch automata shader
	rd.compute_list_dispatch(compute_list,
		int(ceil(grid_size / 8.0)), # grid_size / workgroup size
		int(ceil(grid_size / 8.0)),
		int(ceil(grid_size / 8.0))
	)

func dispatch_cell_aggregation(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, aggregate_pipeline_rid) # Bind compute pipeline
	# rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set

	rd.compute_list_bind_uniform_set(compute_list, aggregate_uniform, 0) # Bind uniform set


	# Push constants for aggregation
	var pc := PackedByteArray()
	pc.resize(16)
	pc.encode_u32(0, grid_size)
	pc.encode_u32(4, typecount)
	rd.compute_list_set_push_constant(compute_list, pc, pc.size())

	# Dispatch aggregation shader
	rd.compute_list_dispatch(compute_list,
		grid_size,
		grid_size,
		grid_size
	)

func dispatch_brick_map_generation(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, brick_pipeline_rid) # Bind compute pipeline
	rd.compute_list_bind_uniform_set(compute_list, brick_uniform, 0) # Bind uniform set

	# Push constants for brick map generation
	var push_constant := PackedByteArray()
	push_constant.resize(16) # Padding to 16 bytes to match shader alignment
	push_constant.encode_u32(0, brick_size)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

	# Dispatch brick map shader
	rd.compute_list_dispatch(compute_list,
		brick_grid_size.x,
		brick_grid_size.y,
		brick_grid_size.z
	)

func setup_cell_pipeline():
	var shader_file: RDShaderFile = load("res://shaders/cell_shader_v2.glsl")
	if shader_file == null:
		push_error("Failed to load shader file")
		return
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Shader SPIR-V is null (compile error)")
		return
	var shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")
	pipeline_rid = rd.compute_pipeline_create(shader_rid)


	if (initial_state):
		# rd.storage_buffer_update(read_state_rid, 0, initial_state)
		var size = grid_size * grid_size * grid_size
		assert(initial_state.size() == size, "initial state size %s != %s" % [initial_state.size(), size])
		read_state_rid = rd.storage_buffer_create(size* 4, initial_state.to_byte_array())
	else:
		read_state_rid = rd.storage_buffer_create(grid_size * grid_size * grid_size * 4)


	if (kernels):
		var size = typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z
		assert(kernels.size() == size, "kernels size %s != %s" % [kernels.size(), size])
		# rd.storage_buffer_update(kernel_rid, 0, kernels)
		kernel_rid = rd.storage_buffer_create(size * 4, kernels.to_byte_array())
	else:
		kernel_rid = rd.storage_buffer_create(typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z * 4)


	read_state_rid = rd.storage_buffer_create(grid_size * grid_size * grid_size * 4)
	write_state_rid = rd.storage_buffer_create(grid_size * grid_size * grid_size * 4)

	if (not read_state_rid.is_valid() or not write_state_rid.is_valid() or not kernel_rid.is_valid()):
		printerr("CRITICAL ERROR: Failed to create storage buffers! Grid size ", grid_size, " might be too large for VRAM.")
		return

	# Create uniforms for cell automata
	var read_u := RDUniform.new()
	read_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_u.binding = 0
	read_u.add_id(read_state_rid)

	var write_u := RDUniform.new()
	write_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_u.binding = 1
	write_u.add_id(write_state_rid)

	var kernel_u := RDUniform.new()
	kernel_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kernel_u.binding = 2
	kernel_u.add_id(kernel_rid)

	cell_uniform_set = rd.uniform_set_create(
		[read_u, write_u, kernel_u],
		shader_rid,
		0
	)

func setup_aggregation_pipeline():
	var shader_file: RDShaderFile = load("res://shaders/state_argmax.glsl")
	if shader_file == null:
		push_error("Failed to load shader file")
		return
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Shader SPIR-V is null (compile error)")
		return
	var aggregate_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if aggregate_shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")
	aggregate_pipeline_rid = rd.compute_pipeline_create(aggregate_shader_rid)

	cell_type_texture_rid = create_texture(Vector3i(grid_size, grid_size, grid_size))

	# Bind SSBO with latest read_state
	var read_uniform = RDUniform.new()
	read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_uniform.binding = 0
	read_uniform.add_id(read_state_rid)

	# Bind image3D to write cell type indices
	var cell_uniform = RDUniform.new()
	cell_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cell_uniform.binding = 1
	cell_uniform.add_id(cell_type_texture_rid)

	aggregate_uniform = rd.uniform_set_create([read_uniform, cell_uniform], aggregate_shader_rid, 0)

func setup_brick_pipeline():
	var shader_file: RDShaderFile = load("res://shaders/brick_map_builder.glsl")
	if shader_file == null:
		push_error("Failed to load shader file")
		return
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Failed to load shader file")
		return
	var brick_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if brick_shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")
	brick_pipeline_rid = rd.compute_pipeline_create(brick_shader_rid)

	# create_brick_map_texture()
	brick_map_texture_rid = create_texture(brick_grid_size)
	texture_rid = create_texture(Vector3i(grid_size, grid_size, grid_size))

	# Bind type image as input
	var cell_uniform = RDUniform.new()
	cell_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cell_uniform.binding = 0
	cell_uniform.add_id(cell_type_texture_rid)

	# Bind output buffer / image for bricks
	var brick_u = RDUniform.new()
	brick_u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	brick_u.binding = 1
	brick_u.add_id(brick_map_texture_rid)

	brick_uniform = rd.uniform_set_create([cell_uniform, brick_u], brick_shader_rid, 0)

func create_texture(size: Vector3i = Vector3i(-1, -1, -1)) -> RID:
	var fmt = RDTextureFormat.new()
	fmt.width = size.x # No packing - each voxel gets its own texel
	fmt.height = size.y
	fmt.depth = size.z
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D

	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits =\
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var rid = rd.texture_create(fmt, RDTextureView.new())
	if not rid.is_valid():
		printerr("CRITICAL ERROR: Failed to create voxel texture! Grid size ", size, " might be too large for VRAM.")
		return RID()
	return rid
