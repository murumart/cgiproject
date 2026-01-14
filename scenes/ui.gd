extends Control

const CameraScript := preload("res://addons/freelookcamera/free_look_camera.gd")

@export var renderers: Array[Renderer]
var current_renderer: Renderer
@export var camera: CameraScript

@export var fps_label: Label
@export var renderer_switch: OptionButton
@export var renderer_description: RichTextLabel


func _ready() -> void:
	renderer_switch.clear()
	var i := 0
	for r in renderers:
		renderer_switch.add_item(r.name)
		if not r.disabled:
			_renderer_selected(i)
		i += 1
	renderer_switch.item_selected.connect(_renderer_selected)


func _process(_delta: float) -> void:
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


func _renderer_selected(which: int) -> void:
	var r := renderers[which]
	if r == current_renderer:
		return

	print("switching to ", r)
	if current_renderer:
		current_renderer.set_disabled(true)
	r.set_disabled(false)
	current_renderer = r
	renderer_description.text = r.editor_description
	camera.renderer = r
