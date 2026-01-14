extends Simulator

signal simulation_updated_texture(data: RID)

var rd := RenderingServer.get_rendering_device()

# Compute pipeline
var uniform_flip: bool = false
var compute_shader_rid: RID
var pipeline_rid: RID
var compute_pipeline_uniform_set_1: RID
var compute_pipeline_uniform_set_2: RID

# Aggregation shader
var data_texture_rid: RID
var aggregation_pipeline_rid: RID
var aggregation_uniform_set_1: RID
var aggregation_uniform_set_2: RID

@export var simulate: bool = false

@export var grid_size := 512
@export var kernel_size: Vector3i = Vector3i(3, 3, 3) # Kernel dimensions
@export var typecount: int = 4

@export var compute_shader_file: RDShaderFile
@export var aggregator_shader_file: RDShaderFile


func _ready() -> void:
	super()
	assert(rd, "Couldnt' get rendering device")

	# Setup
	data_texture_rid = create_texture(rd, grid_size)
	setup_compute_pipeline()


func _process(_delta) -> void:
	if not simulate:
		return
	run_simulation_once()
	# if sim_seed >= int(PI * 1000):
	# 	sim_seed = 0
	# else:
	# 	sim_seed += 1


func get_draw_data_async(callback: Callable) -> void:
	rd.texture_get_data_async(data_texture_rid, 0, callback)


func get_grid_size() -> int:
	return grid_size


func update_data(data: PackedByteArray) -> void:
	rd.texture_update(data_texture_rid, 0, data)
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)


func is_sim_running() -> bool:
	return simulate


func sim_set_running(to: bool) -> void:
	simulate = to


func setup_compute_pipeline() -> void:
	if compute_shader_file == null:
		push_error("Failed to load compute shader file")
		return
	var shader_spirv: RDShaderSPIRV = compute_shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Shader SPIR-V is null (compile error)")
		return
	compute_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if compute_shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")
	pipeline_rid = rd.compute_pipeline_create(compute_shader_rid)

	'''
	if (initial_state):
		# rd.storage_buffer_update(read_state_rid, 0, initial_state)
		var size = grid_size * grid_size * grid_size * typecount
		assert(initial_state.size() == size, "initial state size %s != %s" % [initial_state.size(), size])
		read_state_rid = rd.storage_buffer_create(size * 4, initial_state.to_byte_array())
	else:
		var size = grid_size * grid_size * grid_size * typecount
		initial_state.resize(size)
		var fourth = int(initial_state.size()/4.0)
		for j in range(0, fourth, 5):
			initial_state[j + fourth * 3] = 10
		read_state_rid = rd.storage_buffer_create(size * 4, initial_state.to_byte_array())
		read_state_rid = rd.storage_buffer_create(grid_size * grid_size * grid_size * 4)
	'''

	'''
	if (kernels):
		var size = typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z
		assert(kernels.size() == size, "kernels size %s != %s" % [kernels.size(), size])
		# rd.storage_buffer_update(kernel_rid, 0, kernels)
		kernel_rid = rd.storage_buffer_create(size * 4, kernels.to_byte_array())
	else:
		kernel_rid = rd.storage_buffer_create(typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z * 4)
	'''
	var size = grid_size * grid_size * grid_size * typecount * 4
	var read_state_rid = rd.storage_buffer_create(size)
	var write_state_rid = rd.storage_buffer_create(size)
	var kernels_rid = rd.storage_buffer_create(typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z)

	if (not read_state_rid.is_valid() or not write_state_rid.is_valid() or not kernels_rid.is_valid()):
		printerr("CRITICAL ERROR: Failed to create storage buffers!")
		return

	# Create uniforms for cell automata
	var read_u := RDUniform.new()
	read_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_u.binding = 0
	read_u.add_id(read_state_rid)
	
	# Create uniforms for cell automata
	var read_u2 := RDUniform.new()
	read_u2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_u2.binding = 0
	read_u2.add_id(write_state_rid)

	var write_u := RDUniform.new()
	write_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_u.binding = 1
	write_u.add_id(write_state_rid)

	var write_u2 := RDUniform.new()
	write_u2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_u2.binding = 1
	write_u2.add_id(read_state_rid)

	var kernel_u := RDUniform.new()
	kernel_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kernel_u.binding = 2
	kernel_u.add_id(kernels_rid)

	compute_pipeline_uniform_set_1 = rd.uniform_set_create(
		[read_u, write_u, kernel_u],
		compute_shader_rid,
		0
	)
	compute_pipeline_uniform_set_2 = rd.uniform_set_create(
		[read_u2, write_u2, kernel_u],
		compute_shader_rid,
		0
	)


	### Aggregation pipeline
	if aggregator_shader_file == null:
		push_error("Failed to load aggregation shader file")
		return
	shader_spirv = aggregator_shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Shader SPIR-V is null (compile error)")
		return
	var aggregate_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if aggregate_shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")
	aggregation_pipeline_rid = rd.compute_pipeline_create(aggregate_shader_rid)

	# texture_rid = create_texture(Vector3i(grid_size, grid_size, grid_size))

	# Bind SSBO with latest read_state
	var read_uniform = RDUniform.new()
	read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_uniform.binding = 0
	read_uniform.add_id(read_state_rid)

	var write_uniform = RDUniform.new()
	write_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_uniform.binding = 0
	write_uniform.add_id(write_state_rid)

	# Bind image3D to write cell type indices
	var cell_type_texture_uniform = RDUniform.new()
	cell_type_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cell_type_texture_uniform.binding = 1
	cell_type_texture_uniform.add_id(data_texture_rid)

	aggregation_uniform_set_1 = rd.uniform_set_create([write_uniform, cell_type_texture_uniform], aggregate_shader_rid, 0)
	aggregation_uniform_set_2 = rd.uniform_set_create([read_uniform, cell_type_texture_uniform], aggregate_shader_rid, 0)


func dispatch_compute_pipeline(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid) # Bind compute pipeline
	var uniform_set = compute_pipeline_uniform_set_1 if uniform_flip else compute_pipeline_uniform_set_2
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set

	# Push constants for cell automata
	var push_constant := PackedByteArray()
	push_constant.resize(32)
	push_constant.encode_u32(0, grid_size)
	push_constant.encode_u32(4, grid_size)
	push_constant.encode_u32(8, grid_size)
	push_constant.encode_u32(16, kernel_size.x)
	push_constant.encode_u32(20, kernel_size.y)
	push_constant.encode_u32(24, kernel_size.z)
	push_constant.encode_u32(28, typecount)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

	# Dispatch automata shader
	rd.compute_list_dispatch(compute_list,
		int((grid_size + 7) / 8.0), # grid_size / workgroup size
		int((grid_size + 7) / 8.0),
		int((grid_size * typecount + 7) / 8.0)
	)


func dispatch_aggregation_pipeline(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, aggregation_pipeline_rid) # Bind compute pipeline
	var uniform_set = aggregation_uniform_set_1 if uniform_flip else aggregation_uniform_set_2
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set


	# Push constants for aggregation
	var pc := PackedByteArray()
	pc.resize(16)
	pc.encode_u32(0, grid_size)
	pc.encode_u32(4, grid_size)
	pc.encode_u32(8, grid_size)
	pc.encode_u32(12, typecount)
	rd.compute_list_set_push_constant(compute_list, pc, pc.size())

	# Dispatch aggregation shader
	rd.compute_list_dispatch(compute_list,
		int((grid_size + 7) / 8.0), # grid_size / workgroup size
		int((grid_size + 7) / 8.0),
		int((grid_size + 7) / 8.0)
	)


static func create_texture(rds: RenderingDevice, grid_sizes: int) -> RID:
	var fmt := RDTextureFormat.new()
	fmt.width = grid_sizes # No packing - each voxel gets its own texel
	fmt.height = grid_sizes
	fmt.depth = grid_sizes
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D

	# Usage bits: Storage (Compute Write) + Sampling (Shader Read)
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)

	var s_data_texture_rid := rds.texture_create(fmt, RDTextureView.new())
	if not s_data_texture_rid.is_valid():
		printerr("CRITICAL ERROR: Failed to create voxel texture! Grid size ", grid_sizes, " might be too large for VRAM.")
	return s_data_texture_rid


func run_simulation_once() -> void:
	assert(data_texture_rid.is_valid(), "invalid texture")
	uniform_flip = not uniform_flip

	# Begin compute list
	var compute_list = rd.compute_list_begin()

	# Simulate cell automata
	dispatch_compute_pipeline(compute_list)

	# Aggregate automata result into cells
	dispatch_aggregation_pipeline(compute_list)

	rd.compute_list_end() # End compute list
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)
