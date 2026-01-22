extends Control

@export var kernel_editor: PanelContainer
@export var layer_label: Label

@export var read_switch: OptionButton
@export var write_switch: OptionButton

@export var simulator: Simulator
@export var buttons: Array[Button]

@export var kernel_edit_field: TextEdit

@export var save_button: Button
@export var apply_button: Button


const cell_types = ["Air", "Core", "Leaf", "Bark"]
const layer_label_texts = ["Layer ->|<-||||", "Layer |->|<-|||", "Layer ||->|<-||", "Layer |||->|<-|", "Layer ||||->|<-"]
var current_layer := 0
var current_write_to_cell := 0

# Kernel data array
var kernels: PackedFloat32Array
var kernel_slice: PackedFloat32Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	kernels = simulator.get_kernel()
	
	for type in cell_types:
		read_switch.add_item(type)
		write_switch.add_item(type)
	
	read_switch.item_selected.connect(_on_option_button_selected)
	write_switch.item_selected.connect(_on_option_button_selected)
	
	var i = 0
	for b in buttons:
		b.pressed.connect(_on_layer_button_pressed.bind(i))
		i += 1
	
	save_button.pressed.connect(_on_save_button_pressed)
	apply_button.pressed.connect(_apply_kernel)
	
	#print_kernels()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

func get_kernel_slice_at(write_type: int, read_type: int, layer: int):
	var start = write_type * 5 * 5 * 5 * 4 + write_type * 4 + read_type * 125 + read_type + 1 + layer * 5 * 5
	var end = start + 5 * 5
	var slice = kernels.slice(start, end)
	#print(slice)
	return slice

func print_kernels() -> void:
	var string = ""
	var i = 0
	#var j = 0
	#var row_i = 0
	#var kernel_i = 0
	while kernels.size() > i:
		string += str(kernels[i]) + "\n"
		i += 1
		for um in range(5):
			for j in range(5):
				for k in range(5):
					string += str(kernels[i]) + " "
					i += 1
				string += "\n"
			string += "\n"
	#print("!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print(string)
	

func _on_button_pressed() -> void:
	if kernel_editor.is_visible():
		kernel_editor.hide()
	else:
		kernel_editor.show()
		kernels = simulator.get_kernel()
		kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
		_change_kernel_edit_field_value(kernel_slice)

func _on_layer_button_pressed(which: int) -> void:
	current_layer = which
	layer_label.text = layer_label_texts[which]
	#print("!!!!!!!!!!!")
	kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
	_change_kernel_edit_field_value(kernel_slice)

func _on_option_button_selected(_index: int) -> void:
	print("!!!!!!!!!!!!!!!ssss")
	kernel_slice = get_kernel_slice_at(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)
	_change_kernel_edit_field_value(kernel_slice)

func _change_kernel_edit_field_value(slice: PackedFloat32Array) -> void:
	var string = ""
	for i in range(slice.size()):
		string += str(snapped(slice[i], 0.00001)) + " "
		if (i + 1) % 5 == 0:
			string += "\n"
	kernel_edit_field.text = string

func _on_save_button_pressed() -> void:
	_save_kernel_slice(write_switch.get_selected_id(), read_switch.get_selected_id(), current_layer)

func _save_kernel_slice(write_type: int, read_type: int, layer: int) -> void:
	print("save_slice to kernels")
	var start = write_type * 5 * 5 * 5 * 4 + write_type * 4 + read_type * 125 + read_type + 1 + layer * 5 * 5
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
	print("apply_kernel")
	simulator.set_kernel(kernels)
