extends Control

@export var kernel_editor: PanelContainer
@export var layer_label: Label

@export var read_switch: OptionButton
@export var write_switch: OptionButton

@export var simulator: Simulator

const cell_types = ["Air", "Core", "Leaf", "Bark"]

var current_layer := 0
var current_write_to_cell := 0

# Kernel data array
var kernels: PackedFloat32Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for type in cell_types:
		read_switch.add_item(type)
		write_switch.add_item(type)
	
	kernels = simulator.get_kernel()
	var string = ""
	for i in range(kernels.size()):
		string += str(kernels[i]) + " "
		if ((i + 1) % 5 == 0):
			string += "\n"
	print(string)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass


func _on_button_pressed() -> void:
	if kernel_editor.is_visible():
		kernel_editor.hide()
	else:
		kernel_editor.show()


func _on_layer_1_button_pressed() -> void:
	current_layer = 0
	layer_label.text = "Layer ->|<-||||"


func _on_layer_2_button_pressed() -> void:
	current_layer = 1
	layer_label.text = "Layer |->|<-|||"


func _on_layer_3_button_pressed() -> void:
	current_layer = 2
	layer_label.text = "Layer ||->|<-||"


func _on_layer_4_button_pressed() -> void:
	current_layer = 3
	layer_label.text = "Layer |||->|<-|"


func _on_layer_5_button_pressed() -> void:
	current_layer = 4
	layer_label.text = "Layer ||||->|<-"
