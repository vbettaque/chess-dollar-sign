extends Node

const default_cursor: Texture2D = preload("uid://br5bimdhric2a")
const click_cursor: Texture2D = preload("uid://d00wj8l4ysxor")
const hover_cursor: Texture2D = preload("uid://bgi7srvy7l83t")


func _ready() -> void:
	Input.set_custom_mouse_cursor(default_cursor)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.set_custom_mouse_cursor(click_cursor)
		else:
			Input.set_custom_mouse_cursor(default_cursor)
