extends Renderer

var _thread := Thread.new()
var _semaph := Semaphore.new()

var _data: PackedByteArray
var _data_wait: PackedByteArray
var _genning := false
var _should_mesh := false

@export var inst: MeshInstance3D
@export var sim: Simulator


func _ready() -> void:
	_thread.start(_threaded_meshing)
	sim.simulation_updated.connect(func() -> void:
		sim.get_draw_data_async(_data_get)
	)
	inst.scale = Vector3.ONE * 100.0 / sim.get_grid_size()
	#inst.position -= Vector3.ONE * 100.0 / sim.get_grid_size() * 0.5


func _process(_delta: float) -> void:
	if _should_mesh and not _genning:
		_should_mesh = false
		_data = _data_wait
		_semaph.post()


func _data_get(d: PackedByteArray) -> void:
	_should_mesh = true
	_data_wait = d


func change_render_setting(_by: int) -> void:
	pass


func _threaded_meshing() -> void:
	while true:
		_semaph.wait()
		_genning = true
		var m := ArrayMesh.new()
		_create_mesh(m)
		_genning = false
		(func() -> void:
			inst.mesh = m
			if m.get_surface_count() != 0:
				m.surface_set_material(0, preload("res://scenes/renderers/meshblocks.tres"))
		).call_deferred()


func _create_mesh(m: ArrayMesh) -> void:

	var mesh_array := _create_mesh_data_array()

	if mesh_array[Mesh.ARRAY_VERTEX].is_empty():
		return
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
	#mesh.surface_set_material(0, ChunkMesh.BLOCK_MATERIAL)
	#print("meshgen took ", Time.get_ticks_msec() - time)


func _create_mesh_data_array() -> Array:
	# store how many vertices have been appended in total
	var vertex_count := PackedInt32Array()
	vertex_count.append(0)

	var mesh_array := Array()
	mesh_array.resize(Mesh.ARRAY_MAX)

	mesh_array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	mesh_array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	mesh_array[Mesh.ARRAY_INDEX] = PackedInt32Array()
	mesh_array[Mesh.ARRAY_TEX_UV] = PackedVector2Array()

	if _data.is_empty():
		return mesh_array

	var gs := sim.get_grid_size()
	for x in gs: for y in gs:
		for z in gs:
			var bpos := Vector3(x, y, z)
			var type := _data[x + y * gs + z * gs * gs]
			_add_block_mesh(bpos, mesh_array, vertex_count, type)

	return mesh_array


func _add_block_mesh(
	block_position: Vector3,
	mesh_array: Array,
	vertex_count: PackedInt32Array,
	cell: int
) -> void:
	var verts: PackedVector3Array = mesh_array[Mesh.ARRAY_VERTEX]
	if cell == 0:
		return

	# NORTH (-Z)
	if _is_side_visible(block_position, Vector3.FORWARD):
		verts.append(Vector3(0, 0, 0) + block_position)
		verts.append(Vector3(1, 0, 0) + block_position)
		verts.append(Vector3(1, 1, 0) + block_position)
		verts.append(Vector3(0, 1, 0) + block_position)
		_add_face_data(Vector3.FORWARD, vertex_count, mesh_array, cell)

	# SOUTH (+Z)
	if _is_side_visible(block_position, Vector3.BACK):
		verts.append(Vector3(1, 0, 1) + block_position)
		verts.append(Vector3(0, 0, 1) + block_position)
		verts.append(Vector3(0, 1, 1) + block_position)
		verts.append(Vector3(1, 1, 1) + block_position)
		_add_face_data(Vector3.BACK, vertex_count, mesh_array, cell)

	# WEST (-X)
	if _is_side_visible(block_position, Vector3.LEFT):
		verts.append(Vector3(0, 0, 1) + block_position)
		verts.append(Vector3(0, 0, 0) + block_position)
		verts.append(Vector3(0, 1, 0) + block_position)
		verts.append(Vector3(0, 1, 1) + block_position)
		_add_face_data(Vector3.LEFT, vertex_count, mesh_array, cell)

	# EAST (+X)
	if _is_side_visible(block_position, Vector3.RIGHT):
		verts.append(Vector3(1, 0, 0) + block_position)
		verts.append(Vector3(1, 0, 1) + block_position)
		verts.append(Vector3(1, 1, 1) + block_position)
		verts.append(Vector3(1, 1, 0) + block_position)
		_add_face_data(Vector3.RIGHT, vertex_count, mesh_array, cell)

	# BOTTOM (-Y)
	if _is_side_visible(block_position, Vector3.DOWN):
		verts.append(Vector3(1, 0, 0) + block_position)
		verts.append(Vector3(0, 0, 0) + block_position)
		verts.append(Vector3(0, 0, 1) + block_position)
		verts.append(Vector3(1, 0, 1) + block_position)
		_add_face_data(Vector3.DOWN, vertex_count, mesh_array, cell)

	# TOP (+Y)
	if _is_side_visible(block_position, Vector3.UP):
		verts.append(Vector3(0, 1, 0) + block_position)
		verts.append(Vector3(1, 1, 0) + block_position)
		verts.append(Vector3(1, 1, 1) + block_position)
		verts.append(Vector3(0, 1, 1) + block_position)
		_add_face_data(Vector3.UP, vertex_count, mesh_array, cell)


func _is_side_visible(
	block_position: Vector3,
	side: Vector3,
) -> bool:
	var gs := sim.get_grid_size()
	var check_position := block_position + side
	if (check_position.x >= gs or check_position.x < 0
		or check_position.y >= gs or check_position.y < 0
		or check_position.z >= gs or check_position.z < 0
	):
		return true
	var check_cell := _data[check_position.x + check_position.y * gs + check_position.z * gs * gs]
	if check_cell == 0:
		return true
	return false


const INDEX_APPENDAGE: PackedByteArray = [0, 1, 2, 2, 3, 0]
const BLOCK_TEXTURE_UV_SIZE = 1 / 4.0

func _add_face_data(
		normal_direction: Vector3,
		vertex_count: PackedInt32Array,
		mesh_array: Array,
		cell: int,
) -> void:
	var normals: PackedVector3Array = mesh_array[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = mesh_array[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = mesh_array[Mesh.ARRAY_INDEX]
	var cvs := vertex_count[0]
	for ix in INDEX_APPENDAGE:
		indices.append(ix + cvs)
	normals.append(normal_direction)
	normals.append(normal_direction)
	normals.append(normal_direction)
	normals.append(normal_direction)
	var block_atlas_coord := Vector2.ZERO
	block_atlas_coord.x = cell - 1
	block_atlas_coord *= BLOCK_TEXTURE_UV_SIZE
	uvs.append(Vector2(
			BLOCK_TEXTURE_UV_SIZE + block_atlas_coord.x,
			BLOCK_TEXTURE_UV_SIZE + block_atlas_coord.y))
	uvs.append(Vector2(
			block_atlas_coord.x,
			BLOCK_TEXTURE_UV_SIZE + block_atlas_coord.y))
	uvs.append(block_atlas_coord)
	uvs.append(Vector2(
			BLOCK_TEXTURE_UV_SIZE + block_atlas_coord.x,
			block_atlas_coord.y))
	#uvs.append(Vector2(BLOCK_TEXTURE_UV_SIZE, BLOCK_TEXTURE_UV_SIZE))
	#uvs.append(Vector2(0.0, BLOCK_TEXTURE_UV_SIZE))
	#uvs.append(Vector2(0.0, 0.0))
	#uvs.append(Vector2(BLOCK_TEXTURE_UV_SIZE, 0.0))
	vertex_count[0] += 4
