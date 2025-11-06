@abstract class_name Life extends Resource

const NEIGHBORS: PackedVector3Array = [
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

@abstract func generation(old: PackedByteArray, size: int) -> PackedByteArray

@abstract func init(cells: PackedByteArray, size: int) -> void


static func byte_add(a: int, b: int) -> int:
	return clampi(a + b, 0, 255)


static func ix3d(x: int, y: int, z: int, size: int) -> int:
	#return (x) + (y * size) + (z * size * size)
	return (x % size) + (y % size) * size + (z % size) * size * size
