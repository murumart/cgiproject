extends Simulator

signal simulation_updated_texture(data: RID)

var rd := RenderingServer.get_rendering_device()
var allocated_RIDs: Array[RID] = []

# Compute pipeline
var local_size := 8
var uniform_flip: bool = false
var compute_shader_rid: RID
var pipeline_rid: RID
var compute_read_state_rid: RID
var compute_write_state_rid: RID
var kernels_rid: RID
var compute_pipeline_uniform_set_1: RID
var compute_pipeline_uniform_set_2: RID

# Aggregation shader
var data_texture_rid: RID
var aggregation_shader_rid: RID
var aggregation_pipeline_rid: RID
var aggregation_uniform_set_1: RID
var aggregation_uniform_set_2: RID

@export var simulate: bool = false

var _buffer_elements: int
@export var grid_size := 512
@export var kernel_size: Vector3i = Vector3i(5, 5, 5) # Kernel dimensions
@export var typecount: int = 4

@export var compute_shader_file: RDShaderFile
@export var aggregator_shader_file: RDShaderFile
@export_file("*.txt") var kernel_file_path: String


func _ready() -> void:
	super()
	assert(rd, "Couldnt' get rendering device")

	# Setup
	data_texture_rid = create_texture(rd, grid_size)
	setup_compute_pipeline()
	setup_aggregation_pipeline()
	_buffer_elements = grid_size * grid_size * grid_size * typecount


func _process(_delta) -> void:
	if not simulate:
		return
	run_simulation_once()


func run_simulation_once() -> void:
	assert(data_texture_rid.is_valid(), "invalid texture")
	uniform_flip = not uniform_flip

	# Begin compute list
	var compute_list = rd.compute_list_begin()

	rd.compute_list_add_barrier(compute_list)

	# Simulate cell automata
	dispatch_compute_pipeline(compute_list)


	rd.compute_list_add_barrier(compute_list)

	# Aggregate automata result into cells
	dispatch_aggregation_pipeline(compute_list)

	rd.compute_list_add_barrier(compute_list)

	rd.compute_list_end() # End compute list
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)


func dispatch_compute_pipeline(compute_list: int):
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid) # Bind compute pipeline
	var uniform_set = compute_pipeline_uniform_set_1 if uniform_flip else compute_pipeline_uniform_set_2
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0) # Bind uniform set

	# Push constants for cell automata
	# var push_constant := PackedByteArray()
	# push_constant.resize(48)
	var push: PackedInt32Array = [
		grid_size,
		grid_size,
		grid_size,
		0,
		grid_size,
		grid_size * grid_size,
		grid_size * grid_size * grid_size,
		0,
		kernel_size.x,
		kernel_size.y,
		kernel_size.z,
		typecount]
	# # grid size
	# push_constant.encode_u32(0, grid_size)
	# push_constant.encode_u32(4, grid_size)
	# push_constant.encode_u32(8, grid_size)
	# # strides
	# push_constant.encode_u32(16, grid_size)
	# push_constant.encode_u32(20, grid_size * grid_size)
	# push_constant.encode_u32(24, grid_size * grid_size * grid_size)
	# # kernel size
	# push_constant.encode_u32(32, kernel_size.x)
	# push_constant.encode_u32(36, kernel_size.y)
	# push_constant.encode_u32(40, kernel_size.z)
	# # typecount
	# push_constant.encode_u32(44, typecount)
	
	rd.compute_list_set_push_constant(compute_list, push.to_byte_array(), 48)

	# Dispatch automata shader
	rd.compute_list_dispatch(compute_list,
		(grid_size + local_size - 1) / local_size, # grid_size / workgroup size
		(grid_size + local_size - 1) / local_size,
		(grid_size * typecount + local_size - 1) / local_size
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


func setup_compute_pipeline() -> void:
	# free_RID_if_valid(compute_shader_rid)
	# free_RID_if_valid(pipeline_rid)
	# free_RID_if_valid(compute_read_state_rid)
	# free_RID_if_valid(compute_write_state_rid)
	# free_RID_if_valid(kernels_rid)

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

	# allocated_RIDs.append(compute_shader_rid)

	pipeline_rid = rd.compute_pipeline_create(compute_shader_rid)

	# allocated_RIDs.append(pipeline_rid)
	var size = grid_size * grid_size * grid_size
	var air: PackedInt32Array = []
	air.resize(size * typecount)
	# var cell_type = 0
	for j in range(size):
			# air[j + size * cell_type] = 10
			air[j] = 250

	size = grid_size * grid_size * grid_size * typecount * 4

	compute_read_state_rid = rd.storage_buffer_create(size, air.to_byte_array())
	# compute_read_state_rid = rd.storage_buffer_create(size)
	compute_write_state_rid = rd.storage_buffer_create(size)
	load_kernels_from_file(kernel_file_path)
	# kernels_rid = rd.storage_buffer_create(4 * typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z)

	if (not compute_read_state_rid.is_valid() or not compute_write_state_rid.is_valid() or not kernels_rid.is_valid()):
		printerr("CRITICAL ERROR: Failed to create storage buffers!")
		return

	# allocated_RIDs.append(compute_read_state_rid)
	# allocated_RIDs.append(compute_write_state_rid)
	# allocated_RIDs.append(kernels_rid)

	# create_compute_pipeline_uniforms()


func setup_aggregation_pipeline() -> void:
	# free_RID_if_valid(aggregation_shader_rid)
	# free_RID_if_valid(aggregation_pipeline_rid)

	### Aggregation pipeline
	if aggregator_shader_file == null:
		push_error("Failed to load aggregation shader file")
		return
	var shader_spirv := aggregator_shader_file.get_spirv()
	if shader_spirv == null:
		push_error("Shader SPIR-V is null (compile error)")
		return

	aggregation_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if aggregation_shader_rid == null:
		push_error("Shader is null(SPIR-V shader failed)")

	aggregation_pipeline_rid = rd.compute_pipeline_create(aggregation_shader_rid)

	create_aggregation_pipeline_uniforms()


func reset() -> void:
	# for rid: RID in allocated_RIDs:
	# 	if rid.is_valid():
	# 		rd.free_rid(rid)
	# allocated_RIDs.clear()

	load_kernels_from_file(kernel_file_path)
	data_texture_rid = create_texture(rd, grid_size)
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)
	setup_compute_pipeline()
	setup_aggregation_pipeline()
	_buffer_elements = grid_size * grid_size * grid_size * typecount


func get_draw_data_async(callback: Callable) -> void:
	rd.texture_get_data_async(data_texture_rid, 0, callback)


func get_grid_size() -> int:
	return grid_size


func set_grid_size(to: int) -> void:
	if (to * to * to * typecount > _buffer_elements):
		set_grid_size_FORCE_BUFFER_RESIZE(to)
		return
	set_grid_size_FORCE_BUFFER_RESIZE(to)


func set_grid_size_FORCE_BUFFER_RESIZE(to: int) -> void:
	data_texture_rid = create_texture(rd, to)
	_buffer_elements = to * to * to * typecount
	var buffer_size = _buffer_elements * 4
	var new_size = to * to * to
	var old_size = grid_size * grid_size * grid_size
	grid_size = to

	var air: PackedInt32Array = []
	air.resize(new_size * typecount)
	# var cell_type = 0
	for j in range(new_size):
			air[j] = 250
	
	old_size *= 4
	new_size *= 4

	var min_size = min(new_size, old_size)
	var tmp = rd.storage_buffer_create(buffer_size, air.to_byte_array())

	if (not uniform_flip):
		for i in typecount:
			rd.buffer_copy(compute_write_state_rid, tmp, old_size*i, new_size*i, min_size)

		await RenderingServer.frame_post_draw
		# free_RID_if_valid(compute_read_state_rid)
		# free_RID_if_valid(compute_write_state_rid)

		compute_write_state_rid = tmp
		compute_read_state_rid = rd.storage_buffer_create(buffer_size)
	else:
		for i in typecount:
			rd.buffer_copy(compute_read_state_rid, tmp, old_size*i, new_size*i, min_size)

		await RenderingServer.frame_post_draw
		# free_RID_if_valid(compute_read_state_rid)
		# free_RID_if_valid(compute_write_state_rid)

		compute_read_state_rid = tmp
		compute_write_state_rid = rd.storage_buffer_create(buffer_size)



	if (not compute_read_state_rid.is_valid() or not compute_write_state_rid.is_valid() or not kernels_rid.is_valid()):
		printerr("CRITICAL ERROR: Failed to create storage buffers!")
		return

	create_compute_pipeline_uniforms()
	create_aggregation_pipeline_uniforms()


func update_data(data: PackedByteArray) -> void:
	var cell_grid_size := grid_size * grid_size * grid_size
	assert(data.size() == cell_grid_size, "Update data size(%s) doesn't match grid size(%s)" % [data.size(), cell_grid_size])

	rd.texture_update(data_texture_rid, 0, data)

	# Could create a shader to update read_buffer from data_tetxture

	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)

	# var cell_values := data.to_int32_array()
	var tmp_buffer: PackedInt32Array = []
	tmp_buffer.resize(cell_grid_size * typecount)
	for cell_idx in range(cell_grid_size):
		# if (data[cell_idx] > 0):
			# if (cell_values[cell_idx] >= typecount): continue
		tmp_buffer[cell_idx + clamp(data[cell_idx], 0, typecount)*cell_grid_size] = 200

	var read_buffer = compute_write_state_rid if uniform_flip else compute_read_state_rid
	rd.buffer_update(read_buffer, 0, tmp_buffer.size() * 4, tmp_buffer.to_byte_array())


func is_sim_running() -> bool:
	return simulate


func sim_set_running(to: bool) -> void:
	simulate = to


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

	# allocated_RIDs.append(s_data_texture_rid)
	return s_data_texture_rid


func create_compute_pipeline_uniforms() -> void:
	# free_RID_if_valid(compute_pipeline_uniform_set_1)
	# free_RID_if_valid(compute_pipeline_uniform_set_2)

	# Create uniforms for cell automata
	var read_u := RDUniform.new()
	read_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_u.binding = 0
	read_u.add_id(compute_read_state_rid)

	var read_u2 := RDUniform.new()
	read_u2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_u2.binding = 0
	read_u2.add_id(compute_write_state_rid)

	var write_u := RDUniform.new()
	write_u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_u.binding = 1
	write_u.add_id(compute_write_state_rid)

	var write_u2 := RDUniform.new()
	write_u2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_u2.binding = 1
	write_u2.add_id(compute_read_state_rid)

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

	# allocated_RIDs.append(compute_pipeline_uniform_set_1)
	# allocated_RIDs.append(compute_pipeline_uniform_set_2)


func create_aggregation_pipeline_uniforms():
	# free_RID_if_valid(aggregation_uniform_set_1)
	# free_RID_if_valid(aggregation_uniform_set_2)

	# Bind SSBO with latest read_state
	var read_uniform := RDUniform.new()
	read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	read_uniform.binding = 0
	read_uniform.add_id(compute_read_state_rid)

	var write_uniform := RDUniform.new()
	write_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	write_uniform.binding = 0
	write_uniform.add_id(compute_write_state_rid)

	# Bind image3D to write cell type indices
	var cell_type_texture_uniform := RDUniform.new()
	cell_type_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cell_type_texture_uniform.binding = 1
	cell_type_texture_uniform.add_id(data_texture_rid)

	aggregation_uniform_set_1 = rd.uniform_set_create([write_uniform, cell_type_texture_uniform], aggregation_shader_rid, 0)
	aggregation_uniform_set_2 = rd.uniform_set_create([read_uniform, cell_type_texture_uniform], aggregation_shader_rid, 0)

	# allocated_RIDs.append(aggregation_uniform_set_1)
	# allocated_RIDs.append(aggregation_uniform_set_2)


func load_kernels(kernels: PackedFloat32Array, _typecount: int = 4, _kernel_size: Vector3i = Vector3i(5,5,5)) -> bool:
	kernel_size = _kernel_size
	typecount = _typecount
	return load_kernels_from_packed_byte_array(kernels.to_byte_array())


func load_kernels_from_packed_byte_array(kernels: PackedByteArray) -> bool:
	var size = typecount * typecount * kernel_size.x * kernel_size.y * kernel_size.z * 4
	assert(kernels.size() == size, "Kernels size(%s) doesn't match grid size(%s)" % [kernels.size(), size])

	# free_RID_if_valid(kernels_rid)

	kernels_rid = rd.storage_buffer_create(size, kernels)

	# allocated_RIDs.append(kernels_rid)

	create_compute_pipeline_uniforms()

	return true


func _parse_error(fpath: String, line: int, msg: String) -> void:
	OS.alert("%s:%s: %s" % [fpath, line, msg], "Error parsing kernel file")


func load_kernels_from_file(path: String, _typecount: int = 4, _kernel_size: Vector3i = Vector3i(5,5,5)) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		OS.alert("Couldn't open kernel file (%s)" % error_string(err), "Error opening kernel file!")
		return false

	var values: PackedFloat32Array = []

	var i := 0
	while not file.eof_reached():
		i += 1
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var floats := line.split_floats(" ")
		if floats.size() > kernel_size.x:
			_parse_error(path, i, "Too many values in kernel line (need %s, got %s)" % [kernel_size.x, floats.size()])
			return false
		if floats.size() < kernel_size.x:
			_parse_error(path, i, "Too few values in kernel line (need %s, got %s)" % [kernel_size.x, floats.size()])
			return false

		for factor in floats:
			values.append(factor)

	file.close()

	var expected := (
		_typecount * _typecount *
		_kernel_size.x * _kernel_size.y * _kernel_size.z
	)

	if values.size() < expected:
		_parse_error(path, i, "Too few kernel values (need %s) (missing %s)" % [expected, expected - values.size()])
		return false

	if values.size() < expected:
		_parse_error(path, i, "Too many kernel values (need %s) (%s would be ignored)" % [expected, values.size() - expected])
		return false

	assert(
		values.size() == expected,
		"Kernel count mismatch: got %d expected %d"
		% [values.size(), expected]
	)

	typecount = _typecount
	kernel_size = _kernel_size
	return load_kernels_from_packed_byte_array(values.to_byte_array())


func free_RID_if_valid(rid: RID) -> bool:
	if rid.is_valid():
		var idx := allocated_RIDs.find(rid)
		if idx != -1:
			allocated_RIDs.remove_at(idx)
		rd.free_rid(rid)
		return true
	return false
