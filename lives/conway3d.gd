class_name Conway3DLife extends Life

static var NEIGHBORS: PackedVector3Array = [
	Vector3(-1, -1, -1),
	Vector3( 0, -1, -1),
	Vector3( 1, -1, -1),

	Vector3(-1,  0, -1),
	Vector3( 0,  0, -1),
	Vector3( 1,  0, -1),

	Vector3(-1,  1, -1),
	Vector3( 0,  1, -1),
	Vector3( 1,  1, -1),

	Vector3(-1, -1,  0),
	Vector3( 0, -1,  0),
	Vector3( 1, -1,  0),

	Vector3(-1,  0,  0),
	#Vector3( 0,  0,  0), # position of current cell
	Vector3( 1,  0,  0),

	Vector3(-1,  1,  0),
	Vector3( 0,  1,  0),
	Vector3( 1,  1,  0),

	Vector3(-1, -1,  1),
	Vector3( 0, -1,  1),
	Vector3( 1, -1,  1),

	Vector3(-1,  0,  1),
	Vector3( 0,  0,  1),
	Vector3( 1,  0,  1),

	Vector3(-1,  1,  1),
	Vector3( 0,  1,  1),
	Vector3( 1,  1,  1),
]

@export_range(0, 26) var stable_start: int
@export_range(0, 26) var stable_end: int
@export_range(0, 26) var birth_start: int
@export_range(0, 26) var birth_end: int


func get_neighbor_count(
		x: int,
		y: int,
		z: int,
		cells: PackedByteArray,
		size: int,
		type := 1
) -> int:
	var count := 0
	for n in NEIGHBORS:
		var nx := x + int(n.x)
		var ny := y + int(n.y)
		var nz := z + int(n.z)
		var cell := cells[ix3d(nx, ny, nz, size)]
		if cell == type: count += 1
	return count


func generation(old: PackedByteArray, size: int) -> PackedByteArray:
	var new: PackedByteArray
	new.resize(size * size * size)
	new.fill(0)

	for y in size:
		for z in size:
			for x in size:
				var ix := ix3d(x, y, z, size)
				var neibs := get_neighbor_count(x, y, z, old, size)
				var cell := old[ix]
				if cell == 0:
					if neibs >= birth_start and neibs <= birth_end:
						new[ix] = 1
				elif neibs < stable_start or neibs > stable_end:
					new[ix] = 0
				else:
					new[ix] = cell

	return new
