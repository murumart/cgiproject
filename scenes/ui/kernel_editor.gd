extends Control

const ComputeSim = preload("res://scenes/simulators/CS_cellular_automata.gd")
const D1_Kernel_Sim = preload("res://scenes/simulators/1D_Kernel_Automata.gd")


@export var kernel_editor: PanelContainer

@export var open_button: Button

@export var layer_label: Label

@export var read_switch: OptionButton
@export var write_switch: OptionButton

@export var simulator: Simulator


@export var buttons: Array[Button]

@export var kernel_edit_field: TextEdit

@export var apply_button: Button

@export var export_button: Button
@export var dialog: FileDialog

@export var no_editor_labe: Label
var _dopen := false

var path = "C:/Users/kauri/Desktop/ylikool/HetkeTunnid/Graphics/test_kernel/kernel.txt"


const cell_types = ["Air", "Core", "Leaf", "Bark"]
const layer_label_texts = ["Layer ->|<-||||", "Layer |->|<-|||", "Layer ||->|<-||", "Layer |||->|<-|", "Layer ||||->|<-"]
var current_layer := 0

# Kernel data array
var kernels: PackedFloat32Array
var kernel_slice: PackedFloat32Array

var kernel_size: Vector3i
var type_count: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	kernels = simulator.get_kernel()
	
	kernel_size = simulator.get_kernel_size()
	type_count = simulator.get_typecount()
	
	open_button.pressed.connect(_open_editor)
	
	
	for type in cell_types:
		read_switch.add_item(type)
		write_switch.add_item(type)
	
	read_switch.item_selected.connect(_on_option_button_selected)
	write_switch.item_selected.connect(_on_option_button_selected)
	
	var i = 0
	for b in buttons:
		b.pressed.connect(_on_layer_button_pressed.bind(i))
		i += 1
	
	apply_button.pressed.connect(_apply_kernel)
	export_button.pressed.connect(_export_kernel)

	dialog.canceled.connect(_dial_closed)
	dialog.confirmed.connect(_dial_closed)
	dialog.file_selected.connect(_export_get)
	
	kernel_edit_field.text_changed.connect(_on_slice_text_edit)
	

	#print_kernels()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

func get_kernel_slice_at(write_type: int, read_type: int, layer: int) -> PackedFloat32Array:
	if simulator is ComputeSim:
		var start = write_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) * type_count + read_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) + 1 + layer * kernel_size.x * kernel_size.y
		var end = start + kernel_size.x * kernel_size.y
		var slice = kernels.slice(start, end)
		#print(slice)
		return slice
	elif simulator is D1_Kernel_Sim:
		#var start = (write_type * type_count + read_type) * kernel_size.x
		var start = (write_type * type_count + read_type) * 3 * kernel_size.x
		var end = start + kernel_size.x * 3
		var slice = kernels.slice(start, end)
		#print("slice: " + str(slice))
		return slice
	else:
		return []

func kernel_to_string(kernel: PackedFloat32Array) -> String:
	var string := ""
	var i := 0
	var read_type_ix := 0
	var write_type_ix := 0
	if simulator is ComputeSim:
		while kernel.size() > i:
			
			string += "# " + str(kernel[i]) + "\n"
			i += 1
			string += "# Wrinting " + cell_types[write_type_ix] + "\n"
			string += "# Reading " + cell_types[read_type_ix % type_count] + "\n"
			if ((read_type_ix + 1) % type_count == 0):
				write_type_ix += 1
				
			read_type_ix += 1
			for um in range(kernel_size.z): #
				#string += cell_types[um%4] + "\n"
				#string += "reading " + cell_types[um%4] + "\n"
				for j in range(kernel_size.y): # layer
					for k in range(kernel_size.x): # char
						string += str(kernel[i]) + " "
						i += 1
						if (i >= kernel.size()):
							print(kernel_size)
							print("kernel_size error at 123 !!!!!!!!!!!!!!1")
					string += "\n"
				string += "\n"
		return string
	elif simulator is D1_Kernel_Sim:
		string += "# 1D Kernel\n"
		for write_type in range(type_count):
			for read_type in range(type_count):
				string += "# Writing " + cell_types[write_type] + "\n"
				string += "# Reading " + cell_types[read_type] + "\n"
				for j in range(3):
					for k in range(kernel_size.x):
						string += str(kernel[i]) + " "
						i += 1
					string += "\n"
					
				string += "\n\n"
		#string += str(kernel)
		return string
	else:
		return "no kernel editor for this simulator"

func print_kernels() -> void:
	print(kernel_to_string(kernels))

func update_editor():
	if simulator is ComputeSim or simulator is D1_Kernel_Sim:
		kernels = simulator.get_kernel()
		#print("kernels" + str(kernels))
		kernel_size = simulator.get_kernel_size()
		type_count = simulator.get_typecount()
		#print_kernels()
		kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
		_change_kernel_edit_field_value(kernel_slice)

func _open_editor() -> void:
	if kernel_editor.is_visible() or no_editor_labe.is_visible():
		kernel_editor.hide()
		no_editor_labe.hide()
	else:
		if (simulator is D1_Kernel_Sim or simulator is ComputeSim):
			kernel_editor.show()
		else:
			no_editor_labe.show()
		update_editor()

func _on_new_kernel_selected(_index: int) -> void:
	kernel_editor.hide()
	no_editor_labe.hide()
	update_editor()

func _on_layer_button_pressed(which: int) -> void:
	current_layer = which
	layer_label.text = layer_label_texts[which]
	#print("!!!!!!!!!!!")
	kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
	_change_kernel_edit_field_value(kernel_slice)

func _on_option_button_selected(_index: int) -> void:
	# print("!!!!!!!!!!!!!!!ssss")
	kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
	_change_kernel_edit_field_value(kernel_slice)

func _change_kernel_edit_field_value(slice: PackedFloat32Array) -> void:
	if simulator is ComputeSim or simulator is D1_Kernel_Sim:
		var string = ""
		for i in range(slice.size()):
			string += str(snapped(slice[i], 0.000001)) + " "
			if (i + 1) % kernel_size.x == 0:
				string += "\n"
		kernel_edit_field.text = string
	else:
		kernel_edit_field.text = "no edit for this"

func _on_slice_text_edit() -> void:
	_save_kernel_slice(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)

func _save_kernel_slice(write_type: int, read_type: int, layer: int) -> void:
	var start: int
	if simulator is ComputeSim:
		# print("save_slice to kernels")
		start = write_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) * type_count + read_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) + 1 + layer * kernel_size.x * kernel_size.y
		#var end = start + 5 * 5
	elif simulator is D1_Kernel_Sim:
		start = (write_type * type_count + read_type) * 3 * kernel_size.x

	var string = kernel_edit_field.text
	var lines = string.split("\n")
	var slice = PackedFloat32Array()
	for line in lines:
		var values = line.split(" ")
		for value in values:
			if value != "":
				slice.append(float(value))
	for i in range(slice.size()):
		kernels[start + i] = slice[i]

		

func _apply_kernel() -> void:
	simulator.set_kernel(kernels)


func _export_kernel() -> void:
	print("export_kernel")
	if _dopen:
		return
	_dopen = true
	print("kernel_selection.gd::_export_kernel : opened")
	dialog.popup_centered()

func _dial_closed() -> void:
	_dopen = false
	print("kernel_selection.gd::_dial_closed : closed")

func _export_get(filepath: String) -> void:
	print("kernel_selection.gd::_export_get : got filepath ", filepath)
	if _dopen:
		_dial_closed()
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	file.store_string(kernel_to_string(kernels))
	file.close()

func set_simulator(sim: Simulator) -> void:
	kernel_editor.hide()
	no_editor_labe.hide()
	simulator = sim
	update_editor()
