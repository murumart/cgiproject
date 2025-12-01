class_name LatticeMeshInstance extends MeshInstance3D

static var PLANE_VERTICES: Array[PackedVector3Array] = [
	# +x
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	# -x
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	# +y
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	# -y
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	# +z
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	# -z
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]

static var PLANE_UVS: Array[PackedVector2Array] = [
	# +x
	[Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)],
	# -x
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	# +y
	[Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)],
	# -y
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	# +z
	[Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)],
	# -z
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
]

static var PLANES: PackedVector3Array = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
static var PLANE_COLORS: PackedColorArray = [Color.RED, Color.RED, Color.GREEN, Color.GREEN, Color.BLUE, Color.BLUE]

static var PLANE_INDICES: PackedInt32Array = [0, 1, 2, 2, 3, 0]

@export var grid_size: int


func generate() -> void:
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

	var ix := 0

	for i in [0, 1, 2, 3, 4, 5]:
		var plane := PLANES[i]
		var plane_vtx := PLANE_VERTICES[i]
		var plane_uv := PLANE_UVS[i]
		var plane_col := PLANE_COLORS[i]

		for j in grid_size + 1:
			# make sure to draw in an order such that outer planes are in front of inner ones
			var back := plane.abs() != plane
			var out := Vector3()
			if back:
				out = - plane * grid_size
			for pvi in 4:
				vertices.append(out + plane_vtx[pvi] * grid_size + plane * j + plane * 0.5)
				uvs.append(plane_uv[pvi])
				normals.append(plane)
				colors.append(Color.RED * outof * j)
			
			for index in PLANE_INDICES:
				indices.append(index + ix)

			ix += 4

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
