extends Life

enum {
	CELL_FLESH,
	CELL_LEAF,
	CELL_BARK,
}


static func init_bytes(b: PackedByteArray, size: int) -> void:
	if b.size() != size * size * size:
		b.resize(size * size * size)
		b.clear()



func generation(old: PackedByteArray, size: int) -> PackedByteArray:
	var layer_length := size * size * size

	var cells: PackedByteArray = []; cells.resize(layer_length * 4)
	var energy: PackedByteArray = []; energy.resize(layer_length * 4)
	var water: PackedByteArray = []; water.resize(layer_length * 4)
	var hp: PackedByteArray = []; hp.resize(layer_length * 4)

	real_generation(
		old.slice(0, layer_length),
		old.slice(layer_length, layer_length * 2),
		old.slice(layer_length * 2, layer_length * 3),
		old.slice(layer_length * 3, layer_length * 4),

		cells,
		energy,
		water,
		hp,
	)

	return cells + energy + water + hp


func real_generation(
	oldcells: PackedByteArray,
	oldenergy: PackedByteArray,
	oldwater: PackedByteArray,
	oldhp: PackedByteArray,

	newcells: PackedByteArray,
	newenergy: PackedByteArray,
	newwater: PackedByteArray,
	newhp: PackedByteArray,
) -> void:
	pass
