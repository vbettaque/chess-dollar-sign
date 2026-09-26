class_name ChessPiece
extends Node3D

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Team { WHITE, BLACK }

@export var piece_type: PieceType = PieceType.PAWN
@export var team: Team = Team.WHITE

# Reference to the tile this piece currently occupies
var current_tile: ChessTile = null

# Board coordinates (e.g., Vector2i(0, 0) for A1)
var board_position: Vector2i = Vector2i.ZERO

#recommed by gemini for animation purposes
func move_to_tile(target_tile: ChessTile, new_board_pos: Vector2i) -> void:
	current_tile = target_tile
	board_position = new_board_pos
	
	# Smooth visual movement with a Tween
	var target_global_pos = target_tile.global_position + Vector3(0, target_tile.size.y / 2.0, 0)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.25).set_trans(Tween.TRANS_QUAD)
