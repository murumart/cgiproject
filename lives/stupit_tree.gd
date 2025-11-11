class_name StupitTreeLife extends Life

enum {
	CELL_NONE,
	CELL_FLESH,
	CELL_LEAF,
	CELL_BARK,
	CELL_MAX
}

const NAMES: PackedStringArray = ["NONE", "FLESH", "LEAF", "BARK", "MAX"]

class TreeCell:

	static var NULL := new(0, 0, 0, 0)

	var type: int
	var energy: int # aka CELL_FLESH
	var water: int # aka CELL_LEAF
	var hp: int # aka CELL_BARK :)


	func get_k_value(ix: int) -> int:
		match ix:
			CELL_FLESH: return energy
			CELL_LEAF: return water
			CELL_BARK: return hp
			_: assert(false, "invalid cell typ asdadsadadadsadsdsdad"); return -1


	func set_k_value(ix: int, to: int) -> void:
		match ix:
			CELL_FLESH: energy = to
			CELL_LEAF: water = to
			CELL_BARK: hp = to
			_: assert(false, "invalid cell typ asdadsadadadsadsdsdad")


	func get_highest_k_value() -> int:
		if energy == water and water == hp and hp == 0:
			return CELL_NONE
		if energy > water:
			if energy > hp: return CELL_FLESH
			else: return CELL_BARK
		else:
			if water > hp: return CELL_LEAF
			else: return CELL_BARK

	func clamp(v_min: int, v_max: int):
		energy = clampi(energy, v_min, v_max)
		water = clampi(water, v_min, v_max)
		hp = clampi(hp, v_min, v_max)


	func _init(type_: int, energy_: int, water_: int, hp_: int) -> void:
		type = type_
		energy = energy_
		water = water_
		hp = hp_


	static func from_bytes(
		oldcells: PackedByteArray,
		oldenergy: PackedByteArray,
		oldwater: PackedByteArray,
		oldhp: PackedByteArray,
		size: int,
	) -> Array:
		var tc: Array = []
		tc.resize(size * size * size)
		for i in size * size * size:
			if oldcells[i] == 0:
				tc[i] = NULL
			else:
				tc[i] = TreeCell.new(oldcells[i], oldenergy[i], oldwater[i], oldhp[i])
		return tc

	# returns a value of the current cell based on the surrounding cells
	static func get_kernel(tyyp: int, ct: int) -> PackedVector4Array:
		if tyyp == CELL_FLESH:
			if ct == CELL_FLESH: return [
				Vector4(0, 0, 0, 1.0),
				Vector4(0, -1, 0, 0.05),
				Vector4(0, -2, 0, 0.02),
				Vector4(0, -3, 0, 0.01),
				#Vector4(  0,  0,  1, 0.08),
				#Vector4(  0,  0, -1, 0.08),
				#Vector4(  1,  0,  0, 0.08),
				#Vector4( -1,  0,  0, 0.08),
			]
			elif ct == CELL_BARK: return [
				Vector4(0, 0, 0, 0.05)
			]
			elif ct == CELL_LEAF: return [
				Vector4(0, 0, 0, 0.1),
			]
		elif tyyp == CELL_BARK:
			if ct == CELL_FLESH: return [
				Vector4( 0,  0,  0, -9),
				Vector4( 1,  0,  0, 0.55),
				Vector4(-1,  0,  0, 0.55),
				Vector4( 0,  0,  1, 0.55),
				Vector4( 0,  0, -1, 0.55),
			]
			elif ct == CELL_BARK: return []
			elif ct == CELL_LEAF: return []
		elif tyyp == CELL_LEAF:
			if ct == CELL_FLESH: return [
				Vector4( 0,  0,  0,  -12),
				Vector4( 0, -1,  0, 0.3),
				Vector4( 1, -1,  0, 0.3),
				Vector4(-1, -1,  0, 0.3),
				Vector4( 0, -1,  1, 0.3),
				Vector4( 0, -1, -1, 0.3),
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
			]
			elif ct == CELL_BARK: return [
				Vector4( 0,  0,  0,  -7),
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
			elif ct == CELL_LEAF: return [
				Vector4( 1, 0,  0, 0.25),
				Vector4(-1, 0,  0, 0.25),
				Vector4( 0, 0,  1, 0.25),
				Vector4( 0, 0, -1, 0.25),
				Vector4( 2, 0,  0, 0.05),
				Vector4(-2, 0,  0, 0.05),
				Vector4( 0, 0,  2, 0.05),
				Vector4( 0, 0, -2, 0.05),
				Vector4(0, 1, 0, 0),
				Vector4(0, 2, 0, -4 + 1),
				Vector4(0, 3, 0, -3 + 1),
				Vector4(0, 4, 0, -2 + 1),
				Vector4(0, 5, 0, -1 + 1),
			]
		assert(false, "What type is this +?? ?? ?? ?? ? ?? ? ? ? ? ? ???? ?? ? ?? ? ??")
		return []


	func _to_string() -> String:
		return "T:" + NAMES[type].lpad(6, " ") +" F:" + str(energy).lpad(4, " ")+" L:" +str(water).lpad(4, " ") +" B:"+str(hp).lpad(4, " ")


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
				if xc * xc + zc * zc <= 2 * 2:
					celltypes[ix3d(x, y, z, size)] = CELL_FLESH
					energy[ix3d(x, y, z, size)] = 255

	cells.resize(layer_length * 4)
	for i in range(0, layer_length):
		cells[i] = celltypes[i]
	for i in range(layer_length, layer_length * 2):
		cells[i] = energy[i - layer_length * 2]


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

	real_generation(
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

	var treecells := TreeCell.from_bytes(oldcells, oldenergy, oldwater, oldhp, size)
	#for t in treecells.values():
		#prints("input:", t)
	var newgen := _real_cool_object_jeneration_optimised_0999999_type_algorithm_yes(treecells, size)

	# var t: TreeCell
	# var coords = Vector3i(0,0,0)
	var ix = 0;
	
	for t in newgen:
		newcells[ix] = t.type
		newenergy[ix] = t.energy
		newwater[ix] = t.water
		newhp[ix] = t.hp
		ix += 1


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


func _real_cool_object_jeneration_optimised_0999999_type_algorithm_yes(cells: Array, size: int) -> Array:
	var layer_length := cells.size()
	var ngen: Array = []
	ngen.resize(layer_length)
	for i in range(layer_length):
		ngen[i] = TreeCell.new(0, 0, 0, 0)

	var sum: float = 0.0;
	#print("KERNELS:")
	for ct in range(CELL_FLESH, CELL_MAX):
		#print(NAMES[ct])
		for ct2 in range(CELL_FLESH, CELL_MAX):
			#print("  ", NAMES[ct2])
			var kernel := TreeCell.get_kernel(ct, ct2)
			#print("  kernel: ", kernel)
			if kernel.is_empty(): continue # :) optimisising

			var ix = 0
			for x in size:
				for y in size:
					for z in size:
						#prints(NAMES[ct][0], NAMES[ct2][0], "AT", coord)
						sum = ngen[ix].get_k_value(ct)
						for k_add in kernel:
							var kx := int(k_add.x) + x
							var ky := int(k_add.y) + y
							var kz := int(k_add.z) + z
							if kx < 0 or ky < 0 or kz < 0 or kx >= size or ky >= size or kz >= size:
								continue
							var kcoord: int = ix3d(kx, ky, kz, size)
							var c: TreeCell = cells[kcoord]
							# var add := (c.get_k_value(ct2) * k_add.w) / 255.0
							# sum += add
							sum += c.get_k_value(ct2) * k_add.w
							# prints(NAMES[ct][0], NAMES[ct2][0], "      ", c.get_k_value(ct2), k_add.w, c.get_k_value(ct2) * k_add.w, kcoord)
						# var prev := ngen[coord].get_k_value(ct)
						# sum = prev / 255.0 + sum
						ngen[ix].set_k_value(ct, int(sum))
						#prints(NAMES[ct][0], NAMES[ct2][0], "og   ", cells[coord].get_k_value(ct))
						#prints(NAMES[ct][0], NAMES[ct2][0], "prevn", prev)
						# prints(NAMES[ct][0], NAMES[ct2][0], "sum", sum, "kval", ngen[ix].get_k_value(ct), "\n")
						ix += 1

	#print("NEW GEN:")
	for t in ngen:
		t.type = t.get_highest_k_value()
		t.clamp(0, 255)
		# print("   this cell at ", i, " is ", t)

	return ngen
