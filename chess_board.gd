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
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 0.50

var turn = "WHITE"
enum turnState {PlayerTurn, EnemyTurn}
var is_advancing: bool = false
var tiles: Array[ChessTile]
var pieces: Array[ChessPiece]
var piece_scenes: Dictionary[ChessPiece.PieceType, PackedScene] = {}
var selected_piece: ChessPiece = null
var valid_move_tiles: Array[Vector2i] = []

func _ready() -> void:
	tiles.resize(64)
	pieces.resize(64)
	_setup_piece_dictionary()
	_init_board()
	await get_tree().process_frame
	_spawn_initial_pieces()
	
# --- Turn Handling ---
func end_turn() -> void:
	deselect_piece()
	turn = "BLACK" if turn == "WHITE" else "WHITE"

# --- Grid Index Helper Methods ---
func set_tile(x: int, y: int, tile: ChessTile) -> void:
	tiles[y * 8 + x] = tile
	if tile:
		tile.board_position = Vector2i(x, y)


func get_tile(x: int, y: int) -> ChessTile:
	return tiles[y * 8 + x]


func set_piece(x: int, y: int, piece: ChessPiece) -> void:
	pieces[y * 8 + x] = piece
	if piece:
		piece.board_position = Vector2i(x, y)


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

			# --- CONNECT TILE CLICK SIGNAL HERE ---
			tile.tile_clicked.connect(handle_tile_clicked)

			if (i + j) % 2 == 0:
				tile.type = ChessTile.TileType.WHITE
			else:
				tile.type = ChessTile.TileType.BLACK
			tile.process_mode = Node.PROCESS_MODE_DISABLED

			var tile_tween = get_tree().create_tween()
			tile_tween \
				.tween_property(tile, "position:y", 0, 0.5) \
				.set_delay((i + j) * 0.05)
			tile_tween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)

# --- Set up starting pieces ---
func _spawn_initial_pieces() -> void:
	# 1. Spawn player pawns along the bottom row (y = 1)
	#for x in range(8):
		#_spawn_piece_at(x, 0, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	_spawn_piece_at(4, 0, ChessPiece.PieceType.KING, ChessPiece.Team.WHITE)

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
	var tile: ChessTile = get_tile(x, y)
	if not tile:
		push_error("Tile at (%d, %d) does not exist!" % [x, y])
		return null

	var scene: PackedScene = piece_scenes.get(type)
	if not scene:
		push_error("No PackedScene configured for piece type: %s" % ChessPiece.PieceType.keys()[type])
		return null

	var piece: ChessPiece = scene.instantiate() as ChessPiece
	if not piece:
		push_error("Failed to instantiate scene as ChessPiece.")
		return null

	# Attach as child directly to the tile
	tile.add_child(piece)

	piece.piece_type = type
	piece.apply_team_color(team)
	piece.board_position = Vector2i(x, y)
	piece.current_tile = tile

	tile.occupying_piece = piece
	set_piece(x, y, piece)

	# Position relative to tile origin (centered on top surface)
	var local_top_y: float = tile.size.y / 2.0
	piece.position = Vector3(0, local_top_y, 0)

	# Optional: Drop-in animation when spawned
	piece.position.y += 5.0
	var drop_tween: Tween = get_tree().create_tween()
	drop_tween.tween_property(piece, "position:y", local_top_y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	return piece


# --- Board Advance Mechanics ---
func advance_rows(rows: int) -> void:
	is_advancing = true
	var tween: Tween = get_tree().create_tween().set_parallel(true)
	var removed_tiles: Array[ChessTile] = []
	removed_tiles.resize(8 * rows)

	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)

			if y < rows:
				removed_tiles[8 * y + x] = tile

				var subtween: Tween = get_tree().create_tween().set_parallel(true)
				subtween.tween_property(tile, "process_mode", PROCESS_MODE_DISABLED, 0)
				subtween.tween_property(tile, "position:y", -10, 0.1).set_delay(x * 0.1)

				if piece:
					subtween.chain().tween_callback(piece.queue_free)

				subtween.chain().tween_property(tile, "visible", false, 0)
				subtween.tween_property(tile, "position:y", 10, 0)
				subtween.tween_property(tile, "position:z", tile.position.z - 8 * tile.size.z, 0)
				subtween.tween_property(tile, "visible", true, 0)
				subtween.tween_property(tile, "position:y", 0, 0.5).set_delay(x * 0.01)
				tween.tween_subtween(subtween)
			else:
				var new_y := y - rows
				# set_tile and set_piece automatically update board_position on tile and piece
				set_tile(x, new_y, tile)
				set_piece(x, new_y, piece)

	for x in range(8):
		for y in range(rows):
			var top_y := 7 - y
			var recycled_tile: ChessTile = removed_tiles[8 * y + x]
			
			# Automatically updates recycled_tile.board_position to (x, top_y)
			set_tile(x, top_y, recycled_tile)
			set_piece(x, top_y, null)

	await tween.finished

	for y in range(8 - rows, 8):
		_spawn_random_enemy_row(y, ChessPiece.Team.BLACK)

	tween = get_tree().create_tween().set_parallel(true)
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			tween.tween_property(tile, "position:z", tile.position.z + rows * tile.size.z, 1)
			tween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)

	tween.chain().tween_property(self, "is_advancing", false, 0)
	
func handle_tile_clicked(tile: ChessTile) -> void:
	if is_advancing:
		return

	var clicked_pos := tile.board_position
	var clicked_piece := get_piece(clicked_pos.x, clicked_pos.y)

	# 1. Select player piece if it matches active turn team
	if clicked_piece:
		var current_team := ChessPiece.Team.WHITE if turn == "WHITE" else ChessPiece.Team.BLACK
		if clicked_piece.team == current_team:
			select_piece(clicked_piece)
			return

	# 2. Execute move if a piece is selected and tile is valid
	if selected_piece and clicked_pos in valid_move_tiles:
		move_piece(selected_piece, clicked_pos)
		end_turn()
		return

	# 3. Deselect if clicking empty space or invalid tile
	deselect_piece()

func select_piece(piece: ChessPiece) -> void:
	deselect_piece()
	selected_piece = piece
	
	# Calculate move options based on piece type
	match piece.piece_type:
		ChessPiece.PieceType.PAWN:
			valid_move_tiles = get_pawn_moves(piece)
		ChessPiece.PieceType.KING:
			valid_move_tiles = get_king_moves(piece)

	# Highlight valid tiles
	for pos in valid_move_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = true

func deselect_piece() -> void:
	for pos in valid_move_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = false
			
	selected_piece = null
	valid_move_tiles.clear()

# --- Movement Logic ---
func get_pawn_moves(pawn: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos := pawn.board_position
	var forward_dir := 1 if pawn.team == ChessPiece.Team.WHITE else -1

	var forward_pos := Vector2i(pos.x, pos.y + forward_dir)
	if is_in_bounds(forward_pos) and get_piece(forward_pos.x, forward_pos.y) == null:
		moves.append(forward_pos)

	var capture_offsets: Array[Vector2i] = [
		Vector2i(pos.x - 1, pos.y + forward_dir),
		Vector2i(pos.x + 1, pos.y + forward_dir)
	]

	for diag in capture_offsets:
		if is_in_bounds(diag):
			var target_piece := get_piece(diag.x, diag.y)
			if target_piece and target_piece.team != pawn.team:
				moves.append(diag)

	return moves

func get_king_moves(king: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos := king.board_position

	# 8-directional offsets
	var offsets: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	for offset in offsets:
		var target_pos := pos + offset
		if is_in_bounds(target_pos):
			var target_piece := get_piece(target_pos.x, target_pos.y)
			# Valid if empty or occupied by enemy
			if target_piece == null or target_piece.team != king.team:
				moves.append(target_pos)

	return moves

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

# --- Piece Execution ---
func move_piece(piece: ChessPiece, target_pos: Vector2i) -> void:
	var old_pos := piece.board_position
	var target_tile := get_tile(target_pos.x, target_pos.y)
	var enemy_piece := get_piece(target_pos.x, target_pos.y)

	if enemy_piece:
		enemy_piece.queue_free()

	set_piece(old_pos.x, old_pos.y, null)
	var old_tile := get_tile(old_pos.x, old_pos.y)
	if old_tile:
		old_tile.occupying_piece = null

	piece.reparent(target_tile)
	piece.board_position = target_pos
	piece.current_tile = target_tile
	target_tile.occupying_piece = piece
	set_piece(target_pos.x, target_pos.y, piece)

	var local_top_y := target_tile.size.y / 2.0
	var move_tween := get_tree().create_tween()
	move_tween.tween_property(piece, "position", Vector3(0, local_top_y, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
