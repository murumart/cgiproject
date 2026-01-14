extends PanelContainer

const UB := preload("res://scenes/ui/ui_button.gd")

signal selected(what: Variant)

@export var key: Key
@export var icon: Texture2D
@export var text: String
@export var selected_output: Variant

@onready var selected_panel: Panel = %Selected
@onready var label: Label = %Label
@onready var button: Button = %Button
@onready var texture: TextureRect = %Texture
@onready var flash: ColorRect = %Flash


func _ready() -> void:
	texture.texture = icon
	if text:
		button.text = text
	label.text = OS.get_keycode_string(key)
	button.pressed.connect(press)
	selected_panel.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	var kev := event as InputEventKey
	if kev.keycode == key:
		if kev.pressed:
			press()
			_is_pressed = true
		else:
			_is_pressed = false


var _is_pressed := false
func press() -> void:
	if _is_pressed:
		return
	if selected_output == null: selected.emit()
	else: selected.emit(selected_output)
	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "color", Color.WHITE, 0.1)
	tw.tween_property(flash, "color", Color.TRANSPARENT, 0.2)
	get_tree().get_nodes_in_group("hotbar_buttons").map(
		func(a: UB) -> void:
			a.selected_panel.hide()
	)
	selected_panel.show()
