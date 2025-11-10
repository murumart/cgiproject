extends Node3D

## Local rendering device
var rd: RenderingDevice

## Shader storage buffer
var buffer: RID
var input_bytes: PackedByteArray
var output_bytes: PackedByteArray

# Compute Shader
var pipeline: RID 
var uniform_set: RID

class CA:
	var state_a: PackedFloat32Array
	var state_b: PackedFloat32Array
	var kernel: PackedFloat32Array
	
	enum WriteState { A, B }
	var write_state: WriteState
	
	func _init(a: PackedFloat32Array, b: PackedFloat32Array, kernels: PackedFloat32Array, state: WriteState) -> void:
		state_a = a
		state_b = b
		kernel = kernels
		write_state = state

func _ready() -> void:
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://shaders/cell_shader_v1.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)
	
	# Prepare our data. We use floats in the shader, so we need 32 bit.
	var a = PackedFloat32Array([
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0
	])
	var kernel = PackedFloat32Array([
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0
	])
	var cells: CA = CA.new(a, a.duplicate(), kernel, CA.WriteState.A)


func _process(delta: float) -> void:
	pass


func create_compute_list():
	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()
