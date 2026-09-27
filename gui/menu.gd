extends Control

const MAIN = preload("uid://visasat58mgs")

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
