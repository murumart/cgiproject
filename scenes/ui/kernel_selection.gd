extends PanelContainer

const CSAutomata = preload("res://scenes/simulators/CS_cellular_automata.gd")

@export var kernel_switch: OptionButton
@export var file_button: Button

@export var dialog: FileDialog
@export var sim: Simulator

var _dopen := false

const KFILES := [
	{"name": "Mart's sequoia", "path": "res://scenes/simulators/martsequoia.txt", "size": 5},
	{"name": "Bush", "path": "res://scenes/simulators/poosas1.txt", "size": 5},
	{"name": "falling leaves", "path": "res://scenes/simulators/falling_leaves.txt", "size": 5},
	{"name": "Cone", "path": "res://scenes/simulators/rasmus_kernels.txt", "size": 5},
	{"name": "Meh", "path": "res://scenes/simulators/wide_kernel.txt", "size": 5},
	{"name": "Test", "path": "res://scenes/simulators/test.txt", "size": 3},
]

func _ready() -> void:
	for l in KFILES:
		kernel_switch.add_item(l.name)
	kernel_switch.add_item("Custom")
	kernel_switch.set_item_disabled(kernel_switch.item_count - 1, true)
	kernel_switch.item_selected.connect(_kernel_selected)
	file_button.pressed.connect(_load_custom)
	dialog.canceled.connect(_dial_closed)
	dialog.confirmed.connect(_dial_closed)
	dialog.file_selected.connect(_custom_get)
	_kernel_selected(0)
	kernel_switch.selected = 0


func _kernel_selected(which: int) -> void:
	if which >= KFILES.size() or which < 0:
		return
	var size = KFILES[which].size
	_custom_get(KFILES[which].path, false, Vector3i(size,size,size))


func _load_custom() -> void:
	if _dopen:
		return
	_dopen = true
	print("kernel_selection.gd::_load_custom : opened")
	dialog.popup_centered()


func _dial_closed() -> void:
	_dopen = false
	print("kernel_selection.gd::_dial_closed : closed")


func _custom_get(filepath: String, custom := true, size: Vector3i = Vector3i(5,5,5)) -> void:
	print("kernel_selection.gd::_custom_get : got filepath ", filepath)
	if _dopen:
		_dial_closed()
	if (sim as CSAutomata).load_kernels_from_file(filepath, size):
		if custom:
			kernel_switch.selected = kernel_switch.item_count - 1
		sim.kernel_file_path = filepath
