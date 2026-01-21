extends PanelContainer

const CS3DAutomata = preload("res://scenes/simulators/CS_cellular_automata.gd")
const CS1DAutomata = preload("res://scenes/simulators/1D_Kernel_Automata.gd")

@export var kernel_switch: OptionButton
@export var file_button: Button

@export var dialog: FileDialog
@export var sim: Simulator

var kernel_type := 0
var _dopen := false

const KFILES := [
	[
		{"name": "Mart's sequoia", "path": "res://scenes/simulators/martsequoia.txt", "size": 5},
		{"name": "Test", "path": "res://scenes/simulators/test.txt", "size": 3},
		{"name": "Bush", "path": "res://scenes/simulators/poosas1.txt", "size": 5},
		{"name": "falling leaves", "path": "res://scenes/simulators/falling_leaves.txt", "size": 5},
		{"name": "Cone", "path": "res://scenes/simulators/rasmus_kernels.txt", "size": 5},
		{"name": "Meh", "path": "res://scenes/simulators/wide_kernel.txt", "size": 5},
	],
	[
		{"name": "1D Test", "path": "res://scenes/simulators/1D_test.txt", "size": 5},
	]
]

func _ready() -> void:
	for l in KFILES[kernel_type]:
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
	if which >= KFILES[kernel_type].size() or which < 0:
		return
	var kernel_size = KFILES[kernel_type][which].size
	_custom_get(KFILES[kernel_type][which].path, false, Vector3i(kernel_size,kernel_size,kernel_size))

func _load_custom() -> void:
	if _dopen:
		return
	_dopen = true
	print("kernel_selection.gd::_load_custom : opened")
	dialog.popup_centered()


func _dial_closed() -> void:
	_dopen = false
	print("kernel_selection.gd::_dial_closed : closed")


func _custom_get(filepath: String, custom := true, kernel_size: Vector3i = Vector3i(5,5,5)) -> void:
	print("kernel_selection.gd::_custom_get : got filepath ", filepath)
	if _dopen:
		_dial_closed()
	if sim.load_kernels_from_file(filepath, kernel_size):
		if custom:
			kernel_switch.selected = kernel_switch.item_count - 1
		sim.kernel_file_path = filepath

func set_simulator(s: Simulator) -> void:
	sim = s
	if (s is not CS1DAutomata and s is not CS3DAutomata):
		set_enabled(false)
		return
	var old = kernel_type
	kernel_type = 1 if (s is CS1DAutomata) else 0
	if old == kernel_type:
		return
	kernel_switch.clear()
	for l in KFILES[kernel_type]:
		kernel_switch.add_item(l.name)
	kernel_switch.add_item("Custom")
	kernel_switch.set_item_disabled(kernel_switch.item_count - 1, true)
	_kernel_selected(0)
	kernel_switch.selected = 0
	set_enabled(true)

func set_enabled(to: bool) -> void:
	self.visible = to
	# kernel_switch.disabled = not to
	# file_button.disabled = not to
	if to:
		kernel_switch.clear()
		for l in KFILES[kernel_type]:
			kernel_switch.add_item(l.name)
		kernel_switch.add_item("Custom")
		kernel_switch.set_item_disabled(kernel_switch.item_count - 1, true)
		_kernel_selected(0)
		kernel_switch.selected = 0
