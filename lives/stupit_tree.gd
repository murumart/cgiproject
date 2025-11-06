class_name StupitTreeLife extends Life

enum {
	CELL_FLESH,
	CELL_LEAF,
	CELL_BARK,
}

const ENERGY_DIMS: PackedByteArray = [
	5,
	10,
	1,
]

const FLESH_ENERGY_TRANSFER = 15


static func init_bytes(b: PackedByteArray, size: int) -> void:
	if b.size() != size * size * size:
		b.resize(size * size * size)
		b.clear()


func init(cells: PackedByteArray, size: int) -> void:
	var layer_length := size * size * size

	var celltypes: PackedByteArray = []; celltypes.resize(layer_length)
	var energy: PackedByteArray = []; energy.resize(layer_length)
	var water: PackedByteArray = []; water.resize(layer_length)
	var hp: PackedByteArray = []; hp.resize(layer_length)

	@warning_ignore("integer_division")
	var centre := size / 2
	for y in 10:
		for x in size:
			for z in size:
				var xc := x-centre
				var zc := z-centre
				if xc * xc + zc * zc <= 8 * 8:
					celltypes[ix3d(x, y, z, size)] = CELL_FLESH
					energy[ix3d(x, y, z, size)] = 128

	cells.resize(layer_length * 4)
	for i in range(0, layer_length):
		cells[i] = celltypes[i]
	for i in range(layer_length, layer_length * 2):
		cells[i] = energy[i - layer_length * 2]


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

		size,
	)

	return cells + energy + water + hp


func getc(b: PackedByteArray, x: int, y: int, z: int, size: int) -> int:
	return b[ix3d(x, y, z, size)]


func real_generation(
	oldcells: PackedByteArray,
	oldenergy: PackedByteArray,
	oldwater: PackedByteArray,
	oldhp: PackedByteArray,

	newcells: PackedByteArray,
	newenergy: PackedByteArray,
	newwater: PackedByteArray,
	newhp: PackedByteArray,

	size: int
) -> void:

	for y in size:
		for z in size:
			for x in size:

				var ix := ix3d(x, y, z, size)
				_sim_energy(x, y, z, size, oldcells[ix], oldenergy, oldcells, newenergy)


func _sim_energy(
	x: int,
	y: int,
	z: int,
	size: int,
	cell: int,
	oldenergy: PackedByteArray,
	oldcells: PackedByteArray,
	newenergy: PackedByteArray,
) -> void:
	var ix := ix3d(x, y, z, size)

	var energy_level := oldenergy[ix] - ENERGY_DIMS[cell]

	if cell == CELL_FLESH:
		# distribute energy
		for n in NEIGHBORS:

			@warning_ignore("narrowing_conversion")
			var i := ix3d(x + n.x, y + n.y, z + n.z, size)
			if oldcells[i] == 0:
				continue
			if oldenergy[i] < energy_level:
				newenergy[i] = byte_add(newenergy[i], FLESH_ENERGY_TRANSFER)
				energy_level = byte_add(energy_level, -FLESH_ENERGY_TRANSFER)

	newenergy[ix] = byte_add(newenergy[ix], energy_level)
