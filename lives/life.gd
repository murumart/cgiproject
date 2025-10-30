@abstract class_name Life extends Resource

@abstract func generation(old: PackedByteArray, size: int) -> PackedByteArray


static func ix3d(x: int, y: int, z: int, size: int) -> int:
	#return (x) + (y * size) + (z * size * size)
	return (x % size) + (y % size) * size + (z % size) * size * size
