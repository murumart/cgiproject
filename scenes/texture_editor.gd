class_name TextureEditor extends Node

const HB := preload("res://scenes/ui/ui_button.gd")
const BreakParticle := preload("res://scenes/decor/break_particles.tscn")
const AddParticle := preload("res://scenes/decor/add_particles.tscn")

## Fly around the world and build bricks

@export var camera: Camera3D
@export var simulator: Simulator
@export var volume: MeshInstance3D
@export var highlight: MeshInstance3D
@export var block_select_buttons: Array[HB]
@export var clear_board_button: HB

var _tdata: PackedByteArray
var _data_queueing := false

var _debug_parent: Node3D

var _selected_block := 0


func _ready() -> void:
	assert(is_instance_valid(camera), "Need ojbect set")
	assert(is_instance_valid(simulator), "Need simulator set")
	_debug_parent = Node3D.new()
	add_child(_debug_parent)
	var t := create_tween().set_loops()
	t.tween_interval(1)
	t.tween_callback(_draw_data_b)
	_data_queueing = true
	simulator.get_draw_data_async(_queue_cb)
	for n in block_select_buttons:
		if n.selected_output == null:
			continue
		n.selected.connect(func(r: Variant) -> void: _selected_block = int(r))
	get_tree().get_first_node_in_group("hotbar_buttons").press()
	clear_board_button.selected.connect(func() -> void:
		#_tdata.clear()
		#_tdata.resize(int(pow(simulator.get_grid_size(), 3)))
		#_tdata.fill(255)
		#simulator.update_data(_tdata)
		simulator.reset()
	)


func _queue_cb(d: PackedByteArray) -> void:
	_data_queueing = false
	_tdata = d


func _physics_process(_delta: float) -> void:
	if _data_queueing:
		return

	var gs := simulator.get_grid_size()
	var mpos := get_viewport().get_mouse_position()
	var in_vol_pos := (
		camera.project_ray_origin(mpos)
		- volume.position
		+ Vector3.ONE * 100 * 0.5
	)
	in_vol_pos /= 100.0 / simulator.get_grid_size()
	if _tdata.size() != int(pow(simulator.get_grid_size(), 3)):
		_data_queueing = true
		simulator.get_draw_data_async(_queue_cb)
		return
	var raycast := BlockRaycast.cast_ray_fast_vh(
		in_vol_pos,
		camera.project_ray_normal(mpos),
		512,
		_tdata,
		gs,
	)
	if raycast.failure:
		highlight.hide()
		return

	var bpos := raycast.get_collision_point()
	var normal := Vector3.ZERO

	normal[raycast.xyz_axis] = -raycast.axis_direction
	var action_position := ((bpos + normal * 0.5) * 100.0 / gs
		+ volume.position - Vector3.ONE * 100 * 0.5
		+ Vector3.ONE * 100 / gs * 0.5)
	if Input.is_action_pressed("mouse_left") and not simulator.is_sim_running():
		var addpos := bpos + normal
		if _selected_block == 0:
			addpos = bpos
			if (addpos.x < gs and addpos.x >= 0
				and addpos.y < gs and addpos.y >= 0
				and addpos.z < gs and addpos.z >= 0
			):
				var oldblock := _tdata[addpos.x + addpos.y * gs + addpos.z * gs * gs]
				_tdata[addpos.x + addpos.y * gs + addpos.z * gs * gs] = _selected_block
				simulator.update_data(_tdata)
				if oldblock > 0:
					_particle(BreakParticle, action_position)
		elif (addpos.x < gs and addpos.x >= 0
			and addpos.y < gs and addpos.y >= 0
			and addpos.z < gs and addpos.z >= 0
		):
			_tdata[addpos.x + addpos.y * gs + addpos.z * gs * gs] = _selected_block
			simulator.update_data(_tdata)
			_particle(AddParticle, action_position)

	_data_queueing = true
	simulator.get_draw_data_async(_queue_cb)

	highlight.show()
	highlight.scale = Vector3.ONE * 100 / gs
	highlight.scale[raycast.xyz_axis] = 0.01
	highlight.position = action_position


func _draw_data_b() -> void:
	return
	if _tdata.is_empty():
		print("empty")
		return
	var gs := simulator.get_grid_size()
	var mats: Array[StandardMaterial3D] = [
		null,
		StandardMaterial3D.new(),
		StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	]
	mats[1].albedo_color = Color.RED
	mats[2].albedo_color = Color.GREEN
	mats[3].albedo_color = Color.BLUE
	_debug_parent.get_children().map(func(a: Node) -> void: a.queue_free())
	_debug_parent.scale = Vector3.ONE * 100.0 / simulator.get_grid_size()
	_debug_parent.global_position = volume.global_position - Vector3.ONE * 50
	var m := BoxMesh.new()
	for x in gs: for y in gs:
		for z in gs:
			var b := _tdata[x + y * gs + z * gs * gs]
			if b == 0:
				continue
			var n := MeshInstance3D.new()
			n.mesh = m
			n.material_override = mats[b]
			n.position = Vector3(x, y, z) + Vector3.ONE * 0.5
			_debug_parent.add_child(n)


func _particle(type: PackedScene, pos: Vector3) -> void:
	var p := type.instantiate()
	add_child(p)
	p.global_position = pos
