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

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func create_compute_list():
	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()
