extends Simulator

signal simulation_updated_texture(data: RID)
const ComputeAutomataSimulator = preload("res://scenes/simulators/CS_cellular_automata.gd")

var rd := RenderingServer.get_rendering_device()
var data_texture_rid: RID
var compute_shader_rid: RID
var pipeline_rid: RID

@export var compute_shader_file: RDShaderFile

@export var grid_size := 512

@export var sim_seed: int = int(PI * 250)
@export var simulte: bool = false


func _ready() -> void:
	super()
	assert(rd, "Couldnt' get rendering device")

	# Setup
	reset()


func reset() -> void:
	data_texture_rid = ComputeAutomataSimulator.create_texture(rd, grid_size)
	setup_compute_pipeline()


func _process(_delta) -> void:
	if not simulte:
		return
	run_simulation_once()
	if sim_seed >= int(PI * 1000):
		sim_seed = 0
	else:
		sim_seed += 1


func get_draw_data_async(callback: Callable) -> void:
	rd.texture_get_data_async(data_texture_rid, 0, callback)

func get_texture_rid() -> RID:
	return data_texture_rid

func get_grid_size() -> int: return grid_size
func set_grid_size(to: int) -> void:
	grid_size = to
	data_texture_rid = ComputeAutomataSimulator.create_texture(rd, grid_size)


func update_data(data: PackedByteArray) -> void:
	rd.texture_update(data_texture_rid, 0, data)
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)

@warning_ignore("unused_parameter")
func update_data_at(value: int, x: int, y: int, z:int):
	pass


func is_sim_running() -> bool:
	return simulte


func sim_set_running(to: bool) -> void:
	simulte = to


func setup_compute_pipeline() -> void:
	var shader_file := compute_shader_file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	compute_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(compute_shader_rid)


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

	var uniform := RDUniform.new() # Create uniform for texture
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE # Set uniform type to image
	uniform.binding = 0 # Set binding to 0
	uniform.add_id(data_texture_rid) # Add texture ID

	var uniform_set := rd.uniform_set_create([uniform], compute_shader_rid, 0) # Create uniform set

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
	simulation_updated.emit.call_deferred()
	simulation_updated_texture.emit(data_texture_rid)
