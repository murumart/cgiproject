extends Control

const CameraScript := preload("res://addons/freelookcamera/free_look_camera.gd")
const ButtonScript := preload("res://scenes/ui/ui_button.gd")

@export var renderers: Array[Renderer]
var current_renderer: Renderer

@export var simulators: Array[Simulator]
var current_simulator: Simulator

@export var renderer_switch: OptionButton
@export var renderer_description: RichTextLabel

@export var simulator_switch: OptionButton
@export var simulator_description: RichTextLabel
@export var grid_size: int

@export var editor: TextureEditor
@export var camera: CameraScript
@export var fps_label: Label
@export var pause_button: ButtonScript


func _ready() -> void:
	pause_button.selected.connect(func() -> void:
		if current_simulator.is_sim_running():
			current_simulator.sim_set_running(false)
			pause_button.text = "Play Simulation"
		else:
			current_simulator.sim_set_running(true)
			pause_button.text = "Pause Simulation"
	)

	renderer_switch.clear()
	var i := 0
	for r in renderers:
		renderer_switch.add_item(r.name)
		if not r.disabled:
			_renderer_selected(i)
		i += 1
	renderer_switch.item_selected.connect(_renderer_selected)
	simulator_switch.clear()
	i = 0
	for s in simulators:
		simulator_switch.add_item(s.name)
		if s.is_sim_running():
			assert(current_simulator == null, "Only enable one simulator at a time")
			_simulator_selected(i)
		i += 1
	simulator_switch.item_selected.connect(_simulator_selected)


func _process(_delta: float) -> void:
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


func _renderer_selected(which: int) -> void:
	var r := renderers[which]
	if r == current_renderer:
		return

	print("switching render to ", r)
	if current_renderer:
		current_renderer.set_disabled(true)
	r.set_disabled(false)
	current_renderer = r
	renderer_description.text = r.editor_description
	camera.renderer = r


func _simulator_selected(which: int) -> void:
	var s := simulators[which]
	if s == current_simulator:
		return

	print("switching sim to ", s)
	if current_simulator:
		current_simulator.sim_set_running(false)
	s.set_grid_size(grid_size)
	s.reset()
	s.sim_set_running(true)
	for r in renderers:
		r.set_simulator(s)
	current_simulator = s
	simulator_description.text = s.editor_description
	editor.simulator = s
