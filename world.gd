class_name World
extends Node3D

@onready var chess_board: ChessBoard = $ChessBoard

signal tile_right_clicked(tile: ChessTile)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	chess_board.tile_right_clicked.connect(_on_tile_right_clicked)


func _on_tile_right_clicked(tile: ChessTile):
	tile_right_clicked.emit(tile)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if not chess_board.is_advancing:
			chess_board.advance_rows(2)
