extends Control

const ComputeSim = preload("res://scenes/simulators/CS_cellular_automata.gd")

@export var kernel_editor: PanelContainer

@export var open_button: Button

@export var layer_label: Label

@export var read_switch: OptionButton
@export var write_switch: OptionButton

@export var simulator: ComputeSim
@export var buttons: Array[Button]

@export var kernel_edit_field: TextEdit

@export var apply_button: Button

@export var export_button: Button
@export var dialog: FileDialog
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

func get_kernel_slice_at(write_type: int, read_type: int, layer: int):
	var start = write_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) * type_count + read_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) + 1 + layer * kernel_size.x * kernel_size.y
	var end = start + kernel_size.x * kernel_size.y
	var slice = kernels.slice(start, end)
	#print(slice)
	return slice

func kernel_to_string(kernel: PackedFloat32Array) -> String:
	var string = ""
	var i = 0
	var read_type_ix = 0
	var write_type_ix = 0
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
						print("!!!!!!!!!!!!!!1")
				string += "\n"
			string += "\n"
	return string

func print_kernels() -> void:
	print(kernel_to_string(kernels))

func update_editor():
	kernels = simulator.get_kernel()
	kernel_size = simulator.get_kernel_size()
	type_count = simulator.get_typecount()
	#print_kernels()
	kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
	_change_kernel_edit_field_value(kernel_slice)

func _open_editor() -> void:
	if kernel_editor.is_visible():
		kernel_editor.hide()
	else:
		kernel_editor.show()
		update_editor()

func _on_new_kernel_selected(_index: int) -> void:
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
	var string = ""
	for i in range(slice.size()):
		string += str(snapped(slice[i], 0.00001)) + " "
		if (i + 1) % kernel_size.x == 0:
			string += "\n"
	kernel_edit_field.text = string

func _on_slice_text_edit() -> void:
	_save_kernel_slice(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)

func _save_kernel_slice(write_type: int, read_type: int, layer: int) -> void:
	# print("save_slice to kernels")
	var start = write_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) * type_count + read_type * (kernel_size.x * kernel_size.y * kernel_size.z + 1) + 1 + layer * kernel_size.x * kernel_size.y
	#var end = start + 5 * 5

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
