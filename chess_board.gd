class_name ChessBoard
extends Node3D

const CHESS_TILE = preload("uid://bre0otua4gpui")

@export_group("Piece Scenes")
@export var pawn_scene: PackedScene
@export var knight_scene: PackedScene
@export var bishop_scene: PackedScene
@export var rook_scene: PackedScene
@export var queen_scene: PackedScene
@export var king_scene: PackedScene
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 0.45

var is_advancing: bool = false
var tiles: Array[ChessTile]
var pieces: Array[ChessPiece]
var piece_scenes: Dictionary[ChessPiece.PieceType, PackedScene] = {}


func _ready() -> void:
	tiles.resize(64)
	pieces.resize(64)
	_setup_piece_dictionary()
	_init_board()
	_spawn_initial_pieces()


# --- Grid Index Helper Methods ---

func set_tile(x: int, y: int, tile: ChessTile) -> void:
	tiles[y * 8 + x] = tile


func get_tile(x: int, y: int) -> ChessTile:
	return tiles[y * 8 + x]


func set_piece(x: int, y: int, piece: ChessPiece) -> void:
	pieces[y * 8 + x] = piece


func get_piece(x: int, y: int) -> ChessPiece:
	return pieces[y * 8 + x]


# --- Initialization ---

func _setup_piece_dictionary() -> void:
	if not pawn_scene and ResourceLoader.exists("res://pawn.tscn"):
		pawn_scene = load("res://pawn.tscn")

	piece_scenes = {
		ChessPiece.PieceType.PAWN: pawn_scene,
		ChessPiece.PieceType.KNIGHT: knight_scene,
		ChessPiece.PieceType.BISHOP: bishop_scene,
		ChessPiece.PieceType.ROOK: rook_scene,
		ChessPiece.PieceType.QUEEN: queen_scene,
		ChessPiece.PieceType.KING: king_scene
	}

#--Set up board

func _init_board() -> void:
	for i in range(8):
		for j in range(8):
			var tile: ChessTile = CHESS_TILE.instantiate()
			var x := (i - 3.5) * tile.size.x
			var z := (3.5 - j) * tile.size.z
			set_tile(i, j, tile)
			add_child(tile)
			tile.position = Vector3(x, 10, z)
			
			if (i + j) % 2 == 0:
				tile.type = ChessTile.TileType.WHITE
			else:
				tile.type = ChessTile.TileType.BLACK    
			tile.process_mode = Node.PROCESS_MODE_DISABLED
			
			var tile_tween = get_tree().create_tween()
			tile_tween \
				.tween_property(tile, "position:y", 0, 0.5) \
				.set_delay((i+j)*0.05)
			tile_tween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)

# --- Set up starting pieces ---
func _spawn_initial_pieces() -> void:
	# 1. Spawn player pawns along the bottom row (y = 1)
	for x in range(8):
		_spawn_piece_at(x, 0, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)

	# 2. Spawn initial random enemy pieces along top two rows (y = 6 and y = 7)
	for y in range(6, 8):
		_spawn_random_enemy_row(y, ChessPiece.Team.BLACK)



func _spawn_random_enemy_row(y: int, team: ChessPiece.Team) -> void:
	var enemy_types: Array[ChessPiece.PieceType] = [
		ChessPiece.PieceType.PAWN,
		#ChessPiece.PieceType.KNIGHT,
		#ChessPiece.PieceType.BISHOP,
		#ChessPiece.PieceType.ROOK,
		#ChessPiece.PieceType.QUEEN
	]

	for x in range(8):
		if randf() < enemy_spawn_chance:
			var random_type: ChessPiece.PieceType = enemy_types.pick_random()
			_spawn_piece_at(x, y, random_type, team)


# --- Piece Spawner ---

func _spawn_piece_at(x: int, y: int, type: ChessPiece.PieceType, team: ChessPiece.Team) -> ChessPiece:
	var tile := get_tile(x, y)
	if not tile:
		push_error("Tile at (%d, %d) does not exist!" % [x, y])
		return null

	var scene : PackedScene = piece_scenes.get(type)
	if not scene:
		push_error("No PackedScene configured for piece type: %s" % ChessPiece.PieceType.keys()[type])
		return null

	var piece := scene.instantiate() as ChessPiece
	if not piece:
		push_error("Failed to instantiate scene as ChessPiece.")
		return null

	add_child(piece)

	# Configure piece parameters
	piece.piece_type = type
	piece.apply_team_color(team)
	piece.board_position = Vector2i(x, y)
	piece.current_tile = tile

	# Link tile and array reference
	tile.occupying_piece = piece
	set_piece(x, y, piece)

	# Calculate X and Z from tile, but force Y to the board surface (y = 0 + half tile height)
	var target_y: float = (tile.size.y / 2.0)
	piece.global_position = Vector3(tile.global_position.x, target_y, tile.global_position.z)

	return piece


# --- Board Advance Mechanics ---

func advance_rows(rows: int) -> void:
	is_advancing = true
	var tween = get_tree().create_tween().set_parallel(true)
	var removed_tiles: Array[ChessTile]
	var removed_pieces: Array[ChessPiece]
	
	removed_tiles.resize(8 * rows)
	removed_pieces.resize(8 * rows)

	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)

			if y < rows:
				removed_tiles[8 * y + x] = tile
				removed_pieces[8 * y + x] = piece

				var subtween = get_tree().create_tween().set_parallel(true)
				subtween.tween_property(tile, "process_mode", PROCESS_MODE_DISABLED, 0)
				subtween.tween_property(tile, "position:y", -10, 0.1).set_delay(x * 0.1)
				
				# Animate and remove piece falling with row
				if piece:
					subtween.tween_property(piece, "position:y", -10, 0.1).set_delay(x * 0.1)
					subtween.chain().tween_callback(piece.queue_free)

				subtween.chain().tween_property(tile, "visible", false, 0)
				subtween.tween_property(tile, "position:y", 10, 0)
				subtween.tween_property(tile, "position:z", tile.position.z - 8 * tile.size.z, 0)
				subtween.tween_property(tile, "visible", true, 0)
				subtween.tween_property(tile, "position:y", 0, 0.5).set_delay(x * 0.01)
				tween.tween_subtween(subtween)
			else:
				set_tile(x, y - rows, tile)
				set_piece(x, y - rows, piece)

	# Shift bottom rows
	for x in range(8):
		for y in range(rows):
			set_tile(x, 7 - y, removed_tiles[8 * y + x])
			set_piece(x, 7 - y, null)

	await tween.finished

	# Animate board shift on Z axis
	tween = get_tree().create_tween().set_parallel(true)
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)

			tween.tween_property(tile, "position:z", tile.position.z + rows * tile.size.z, 1)
			tween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)

			if piece:
				tween.tween_property(piece, "position:z", piece.position.z + rows * tile.size.z, 1)
	tween.chain().tween_property(self, "is_advancing", false, 0)
	# Populate newly spawned top rows with fresh enemy pieces
	for y in range(8 - rows, 8):
		_spawn_random_enemy_row(y, ChessPiece.Team.BLACK)
