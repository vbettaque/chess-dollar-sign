extends Node3D

@onready var chess_board: ChessBoard = $ChessBoard

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if not chess_board.is_advancing:
			chess_board.advance_rows(1)
