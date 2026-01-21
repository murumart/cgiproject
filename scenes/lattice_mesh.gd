class_name LatticeMeshInstance extends MeshInstance3D

const ComputeShaderSim = preload("res://scenes/simulators/CS_cellular_automata.gd")

static var PLANE_VERTICES: Array[PackedVector3Array] = [
	# +x
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	# +y
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	# +z
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	# -x
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	# -y
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	# -z
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]

static var PLANE_UVS: Array[PackedVector2Array] = [
	# +x
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	# +y
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	# +z
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	# -x
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	# -y
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	# -z
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
]

static var PLANES: PackedVector3Array = [
	Vector3.RIGHT,
	Vector3.UP,
	Vector3.BACK,
	Vector3.LEFT,
	Vector3.DOWN,
	Vector3.FORWARD,
]

static var PLANE_INDICES: PackedInt32Array = [0, 1, 2, 2, 3, 0]

var texture: RID
var cells: PackedByteArray
var grid_size: int

var mat: ShaderMaterial:
	get: return (get_active_material(0) as ShaderMaterial)
var rd := RenderingServer.get_rendering_device()


func _process(delta: float) -> void:
	mat.set_shader_parameter("grid_size", grid_size)
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SEMICOLON and event.is_pressed():
		print("lm ö")
		var d := rd.texture_get_data(texture, 0)
		#var img := Image.create_from_data(brick_grid_size.x, brick_grid_size.y * brick_grid_size.z, false, Image.FORMAT_R8, d)
		var img := Image.create_from_data(grid_size, grid_size * grid_size, false, Image.FORMAT_R8, d)
		img.save_png("res://coolimage.2.png")


func generate(gs: int) -> void:
	grid_size = gs
	texture = ComputeShaderSim.create_texture(rd, gs)
	cells.resize(grid_size * grid_size * grid_size)
	update_texture(cells)
	var arrays := generate_mesh_arrays(grid_size)

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh = m


@warning_ignore("shadowed_variable")
static func generate_mesh_arrays(grid_size: int) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var colors: PackedColorArray = []

	var outof := 1.0 / grid_size

	var index_count := 0

	#for i in [0, 1, 2, 3, 4, 5]:
		#var plane := PLANES[i]
		#var plane_vtx := PLANE_VERTICES[i]
		#var plane_uv := PLANE_UVS[i]
		#var back := plane.abs() != plane
		#for j in grid_size + 1:
			#var out := Vector3()
			#if back:
				## so that the back planes are put in correct positions
				#out = -plane * grid_size
			#for pvi in 4:
				#var vtx := out + plane_vtx[pvi] * grid_size + plane * j
				#vertices.append(vtx)
				#uvs.append(plane_uv[pvi])
				#normals.append(plane)
				#colors.append(Color.RED * outof * j)
#
			#for index in PLANE_INDICES:
				#indices.append(index + index_count)
#
			#index_count += 4

	for i in range(grid_size + 1 - 1, -1, -1):
		for p in 3:
			var normal := PLANES[p]
			var vtcis := PLANE_VERTICES[p]
			var uv := PLANE_UVS[p]
			for pvi in 4:
				var vtx := vtcis[pvi] * grid_size + normal * i
				vertices.append(vtx)
				uvs.append(uv[pvi])
				normals.append(normal)
				colors.append(Color.RED * outof * i)
			for index in PLANE_INDICES:
				indices.append(index + index_count)
			index_count += 4

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors

	if grid_size < 5:
		for i in Mesh.ARRAY_MAX:
			if arrays[i] == null: continue
			printt(i, arrays[i])

	return arrays


var _dtex := Texture3DRD.new()
func update_texture(data: PackedByteArray) -> void:
	cells = data
	rd.texture_update.call_deferred(texture, 0, data)

	_dtex.texture_rd_rid = texture
	mat.set_shader_parameter("simulation_data", _dtex)
	mat.set_shader_parameter("grid_size", grid_size)
	assert(mat.get_shader_parameter("simulation_data") == _dtex)
