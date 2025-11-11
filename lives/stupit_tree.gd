class_name StupitTreeLife extends Life

enum {
	CELL_NONE,
	CELL_FLESH,
	CELL_LEAF,
	CELL_BARK,
	CELL_MAX
}

static var FLESH_KERNELS: Dictionary[int, PackedVector4Array] = {
	CELL_FLESH: [
		Vector4(0, 0, 0, 1.0),
		Vector4(0, -1, 0, 0.05),
		Vector4(0, -2, 0, 0.02),
		Vector4(0, -3, 0, 0.01),
	],
	CELL_LEAF: [
		Vector4(0, 0, 0, 0.1),
	],
	CELL_BARK: [
		Vector4(0, 0, 0, 0.05)
	]
}
static var LEAF_KERNELS: Dictionary[int, PackedVector4Array] = {
	CELL_FLESH: [
		Vector4(0, 0, 0, -12),
		Vector4(0, -1, 0, 0.3),
		Vector4(1, -1, 0, 0.3),
		Vector4(-1, -1, 0, 0.3),
		Vector4(0, -1, 1, 0.3),
		Vector4(0, -1, -1, 0.3),
		Vector4(0, 1, 0, -7),
		Vector4(0, 2, 0, -6),
		Vector4(0, 3, 0, -5),
		Vector4(0, 4, 0, -4),
		Vector4(0, 5, 0, -3),
		Vector4(0, 6, 0, -2),
		Vector4(0, 7, 0, -1),
		Vector4(0, 8, 0, -1),
		Vector4(0, 9, 0, -1),
		Vector4(0, 10, 0, -1),
	],
	CELL_LEAF: [
		Vector4(1, 0, 0, 0.25),
		Vector4(-1, 0, 0, 0.25),
		Vector4(0, 0, 1, 0.25),
		Vector4(0, 0, -1, 0.25),
		Vector4(2, 0, 0, 0.05),
		Vector4(-2, 0, 0, 0.05),
		Vector4(0, 0, 2, 0.05),
		Vector4(0, 0, -2, 0.05),
		Vector4(0, 1, 0, 0),
		Vector4(0, 2, 0, -4 + 1),
		Vector4(0, 3, 0, -3 + 1),
		Vector4(0, 4, 0, -2 + 1),
		Vector4(0, 5, 0, -1 + 1),
	],
	CELL_BARK: [
		Vector4(0, 0, 0, -7),
		Vector4(0, 1, 0, -12),
		Vector4(0, 2, 0, -11),
		Vector4(0, 3, 0, -10),
		Vector4(0, 4, 0, -9),
		Vector4(0, 5, 0, -8),
		Vector4(0, 6, 0, -7),
		Vector4(0, 7, 0, -6),
		Vector4(0, 8, 0, -1),
		Vector4(0, 9, 0, -1),
		Vector4(0, 10, 0, -1),
	]
}
static var BARK_KERNELS: Dictionary[int, PackedVector4Array] = {
	CELL_FLESH: [
		Vector4(0, 0, 0, -9),
		Vector4(1, 0, 0, 0.55),
		Vector4(-1, 0, 0, 0.55),
		Vector4(0, 0, 1, 0.55),
		Vector4(0, 0, -1, 0.55),
	],
	CELL_LEAF: [],
	CELL_BARK: [],
}
static var KERNELS := [ {}, FLESH_KERNELS, LEAF_KERNELS, BARK_KERNELS]

const NAMES: PackedStringArray = ["NONE", "FLESH", "LEAF", "BARK", "MAX"]


class TreeCell:
	static var NULL := new(0, 0, 0, 0)

	var type: int
	var energy: int # vestigial ? might be removed
	var water: int # vestigial ? might be removed
	var hp: int # vestigial ? might be removed

	var k_vals: PackedByteArray = [0xb0, 0, 0, 0]


	func get_k_value(ix: int) -> int:
		return k_vals[ix]
		#match ix:
			#CELL_FLESH: return energy
			#CELL_LEAF: return water
			#CELL_BARK: return hp
			#_: assert(false, "invalid cell typ asdadsadadadsadsdsdad"); return -1


	func set_k_value(ix: int, to: int) -> void:
		k_vals[ix] = to
		#match ix:
			#CELL_FLESH: energy = to
			#CELL_LEAF: water = to
			#CELL_BARK: hp = to
			#_: assert(false, "invalid cell typ asdadsadadadsadsdsdad")


	func get_highest_k_value() -> int:
		if k_vals[1] == k_vals[2] and k_vals[2] == k_vals[3] and k_vals[3] == 0:
			return CELL_NONE
		if k_vals[1] > k_vals[2]:
			if k_vals[1] > k_vals[3]: return CELL_FLESH
			else: return CELL_BARK
		else:
			if k_vals[2] > k_vals[3]: return CELL_LEAF
			else: return CELL_BARK


	func _init(type_: int, energy_: int, water_: int, hp_: int) -> void:
		type = type_
		energy = energy_
		water = water_
		hp = hp_
		k_vals[1] = energy_
		k_vals[2] = water_
		k_vals[3] = hp_


	static func from_bytes(
		oldcells: PackedByteArray,
		oldenergy: PackedByteArray,
		oldwater: PackedByteArray,
		oldhp: PackedByteArray,
		size: int,
	) -> Dictionary[Vector3i, TreeCell]:
		var tc: Dictionary[Vector3i, TreeCell]
		var i = 0
		for x in size:
			for y in size:
				for z in size:
					# var i := Life.ix3d(x, y, z, size)
					if oldcells[i] == 0:
						tc[Vector3i(x, y, z)] = NULL
					else:
						tc[Vector3i(x, y, z)] = TreeCell.new(oldcells[i], oldenergy[i], oldwater[i], oldhp[i])
					i += 1
		return tc


	# a kernel is used to sum a "value" of the current cell based on the surrounding cells
	static func get_kernel(tyyp: int, ct: int) -> PackedVector4Array:
		return StupitTreeLife.KERNELS[tyyp][ct]


	func _to_string() -> String:
		return "T:" + NAMES[type].lpad(6, " ") + " F:" + str(energy).lpad(4, " ") + " L:" + str(water).lpad(4, " ") + " B:" + str(hp).lpad(4, " ")


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
				var xc := x - centre
				var zc := z - centre
				if xc * xc + zc * zc <= 2 * 2:
					celltypes[ix3d(x, y, z, size)] = CELL_FLESH
					energy[ix3d(x, y, z, size)] = 255

	cells.resize(layer_length * 4)
	for i in range(0, layer_length):
		cells[i] = celltypes[i]
	for i in range(layer_length, layer_length * 2):
		cells[i] = energy[i - layer_length * 2] # ??????????????? Shouldn't it be i - layer_length


func generation(old: PackedByteArray, size: int) -> PackedByteArray:
	var layer_length := size * size * size

	#print("SEED GENERATION: ", old.size(), old)

	var cells: PackedByteArray = []; cells.resize(layer_length)
	var energy: PackedByteArray = []; energy.resize(layer_length)
	var water: PackedByteArray = []; water.resize(layer_length)
	var hp: PackedByteArray = []; hp.resize(layer_length)

	var first_slice := old.slice(layer_length, layer_length * 2)
	var second_slice := old.slice(layer_length * 2, layer_length * 3)
	var third_slice := old.slice(layer_length * 3, layer_length * 4)

	_generation_with_arrays(
		old.slice(0, layer_length),
		first_slice,
		second_slice,
		third_slice,

		cells,
		energy,
		water,
		hp,

		size,
	)

	var allcells := PackedByteArray()
	allcells.append_array(cells)
	allcells.append_array(energy)
	allcells.append_array(water)
	allcells.append_array(hp)
	#print("ALL CELLS AFTER GENERATION: ", allcells)

	return allcells


func _generation_with_arrays(
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
	var treecells := TreeCell.from_bytes(oldcells, oldenergy, oldwater, oldhp, size)
	#for t in treecells.values():
		#prints("input:", t)
	var newgen := _generation_with_objects(treecells, size)

	var ix = 0;
	for t in newgen.values():
		newcells[ix] = t.type
		newenergy[ix] = t.k_vals[1]
		newwater[ix] = t.k_vals[2]
		newhp[ix] = t.k_vals[3]
		ix += 1


func _generation_with_objects(cells: Dictionary[Vector3i, TreeCell], size: int) -> Dictionary[Vector3i, TreeCell]:
	var ngen: Dictionary[Vector3i, TreeCell] = {}

	for k in cells:
		ngen[k] = TreeCell.new(0, 0, 0, 0)

	var coord := Vector3i(0, 0, 0)
	var sum: float = 0.0;
	#print("KERNELS:")
	for ct in range(CELL_FLESH, CELL_MAX):
		#print(NAMES[ct])
		for ct2 in range(CELL_FLESH, CELL_MAX):
			#print("  ", NAMES[ct2])
			var kernel := TreeCell.get_kernel(ct, ct2)
			#print("  kernel: ", kernel)
			if kernel.is_empty(): continue # :) optimisising

			for x in size:
				coord.x = x
				for y in size:
					coord.y = y
					for z in size:
						coord.z = z
						#prints(NAMES[ct][0], NAMES[ct2][0], "AT", coord)
						sum = ngen[coord].get_k_value(ct)
						for k_add in kernel:
							@warning_ignore("narrowing_conversion")
							var kcoord := Vector3i(k_add.x + x, k_add.y + y, k_add.z + z)
							var c: TreeCell = cells.get(kcoord, TreeCell.NULL)
							# var add := (c.get_k_value(ct2) * k_add.w) / 255.0
							# sum += add
							sum += c.get_k_value(ct2) * k_add.w
							#prints(NAMES[ct][0], NAMES[ct2][0], "      ", c.get_k_value(ct2), k_add.w, add, kcoord)
						# var prev := ngen[coord].get_k_value(ct)
						# sum = prev / 255.0 + sum
						sum = clampf(sum, 0, 255)
						ngen[coord].set_k_value(ct, int(sum))
						#prints(NAMES[ct][0], NAMES[ct2][0], "og   ", cells[coord].get_k_value(ct))
						#prints(NAMES[ct][0], NAMES[ct2][0], "prevn", prev)
						#prints(NAMES[ct][0], NAMES[ct2][0], "sum", sum, "kval", ngen[coord].get_k_value(ct), "\n")

	#print("NEW GEN:")
	for t in ngen.values():
		t.type = t.get_highest_k_value()
		#print("   this cell at ", k, " is ", ngen[k])

	return ngen
