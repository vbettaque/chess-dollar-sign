class_name ChessBoard
extends Node3D

const CHESS_TILE = preload("uid://bre0otua4gpui")

# Assign individual scenes in the Godot Inspector or preload directly
@export var pawn_scene: PackedScene
@export var knight_scene: PackedScene
@export var bishop_scene: PackedScene
@export var rook_scene: PackedScene
@export var queen_scene: PackedScene
@export var king_scene: PackedScene

# Materials for team colors
@export var white_material: Material
@export var black_material: Material

var piece_scenes: Dictionary[ChessPiece.PieceType, PackedScene] = {}
var grid: Dictionary[Vector2i, ChessTile] = {}


func _ready() -> void:
	_setup_piece_dictionary()
	_init_board()
	_spawn_custom_pawns()


func _setup_piece_dictionary() -> void:
	piece_scenes = {
		ChessPiece.PieceType.PAWN: pawn_scene,
		ChessPiece.PieceType.KNIGHT: knight_scene,
		ChessPiece.PieceType.BISHOP: bishop_scene,
		ChessPiece.PieceType.ROOK: rook_scene,
		ChessPiece.PieceType.QUEEN: queen_scene,
		ChessPiece.PieceType.KING: king_scene
	}


func _init_board() -> void:
	for i in range(8):
		for j in range(8):
			var tile: ChessTile = CHESS_TILE.instantiate()
			var x := (i - 3.5) * tile.size.x
			var z := (3.5 - j) * tile.size.z
			tile.position = Vector3(x, 0, z)
			
			if (i + j) % 2 == 0:
				tile.type = ChessTile.TileType.WHITE
			else:
				tile.type = ChessTile.TileType.BLACK
			
			tile.board_position = Vector2i(i, j)
			add_child(tile)
			grid[Vector2i(i, j)] = tile


func _spawn_all_pieces() -> void:
	#var back_rank_types: Array[ChessPiece.PieceType] = [
		#ChessPiece.PieceType.ROOK,
		#ChessPiece.PieceType.KNIGHT,
		#ChessPiece.PieceType.BISHOP,
		#ChessPiece.PieceType.QUEEN,
		#ChessPiece.PieceType.KING,
		#ChessPiece.PieceType.BISHOP,
		#ChessPiece.PieceType.KNIGHT,
		#ChessPiece.PieceType.ROOK
	#]

	for i in range(8):
		# White pieces (j = 0, 1)
		_spawn_piece(i, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)

		# Black pieces (j = 6, 7)
		_spawn_piece(i, 6, ChessPiece.PieceType.PAWN, ChessPiece.Team.BLACK)



func _spawn_piece(i: int, j: int, type: ChessPiece.PieceType, team: ChessPiece.Team) -> void:
	var tile_key := Vector2i(i, j)
	var scene: PackedScene = piece_scenes.get(type)
	
	if not scene or not grid.has(tile_key):
		return

	var target_tile: ChessTile = grid[tile_key]
	var piece: ChessPiece = scene.instantiate() as ChessPiece
	add_child(piece)

	piece.piece_type = type
	piece.team = team

	# Apply white or black team material to mesh children inside the piece
	_apply_team_material(piece, team)

	# Link piece to tile position
	piece.move_to_tile(target_tile, tile_key)

func _spawn_custom_pawns() -> void:
	if not pawn_scene:
		push_error("pawn_scene is null! Re-assign pawn.tscn in the ChessBoard Inspector slot.")
		return

	# Columns c, d, e (indices 2, 3, 4) across rows 1 and 2 (indices 0 and 1)
	for i in [2, 3, 4]:
		for j in [0, 1]:
			_spawn_pawn(i, j, ChessPiece.Team.WHITE)


func _spawn_pawn(i: int, j: int, team: ChessPiece.Team) -> void:
	var tile_key := Vector2i(i, j)
	if not grid.has(tile_key):
		return

	var target_tile: ChessTile = grid[tile_key]
	var pawn: ChessPiece = pawn_scene.instantiate() as ChessPiece
	
	if not pawn:
		push_error("Failed to instantiate pawn_scene as ChessPiece. Ensure ChessPiece.gd is attached to pawn.tscn root node!")
		return

	add_child(pawn)
	pawn.piece_type = ChessPiece.PieceType.PAWN
	pawn.team = team

	# Register references
	target_tile.occupying_piece = pawn
	pawn.move_to_tile(target_tile, tile_key)

func _apply_team_material(piece_node: Node, team: ChessPiece.Team) -> void:
	var target_mat = white_material if team == ChessPiece.Team.WHITE else black_material
	if not target_mat:
		return

	for child in piece_node.get_children():
		if child is MeshInstance3D:
			child.set_surface_override_material(0, target_mat)
		elif child.get_child_count() > 0:
			_apply_team_material(child, team)


func get_tile(i: int, j: int) -> ChessTile:
	return grid.get(Vector2i(i, j), null)
