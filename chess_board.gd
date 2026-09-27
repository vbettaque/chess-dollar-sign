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
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 0.20

signal tile_right_clicked(tile: ChessTile)


enum TurnState { WHITE, BLACK }
var turn: TurnState = TurnState.WHITE
signal turn_changed(turn: TurnState)

var is_advancing: bool = false
var tiles: Array[ChessTile]
var pieces: Array[ChessPiece]
var piece_scenes: Dictionary[ChessPiece.PieceType, PackedScene] = {}
var selected_piece: ChessPiece = null
var valid_move_tiles: Array[Vector2i] = []

# Board State Tracking
signal board_cleared_state_changed(is_cleared: bool)

# --- Economy ---
signal coins_gained(coins: int)
var coins: int = 0

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
	
	if turn == TurnState.WHITE:
		_generate_coins_for_pawns()
		#TODO: REMOVE LATER
		print("current coins: ", coins)
	
	turn = TurnState.BLACK if turn == TurnState.WHITE else TurnState.WHITE
	turn_changed.emit(turn)

	if turn == TurnState.BLACK:
		process_enemy_turn()

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
	if not knight_scene and ResourceLoader.exists("res://knight.tscn"):
		knight_scene = load("res://knight.tscn")
	if not bishop_scene and ResourceLoader.exists("res://bishop.tscn"):
		bishop_scene = load("res://bishop.tscn")
	if not rook_scene and ResourceLoader.exists("res://rook.tscn"):
		rook_scene = load("res://rook.tscn")
	if not queen_scene and ResourceLoader.exists("res://queen.tscn"):
		queen_scene = load("res://queen.tscn")
	if not king_scene and ResourceLoader.exists("res://king.tscn"):
		king_scene = load("res://king.tscn")

	piece_scenes = {
		ChessPiece.PieceType.PAWN: pawn_scene,
		ChessPiece.PieceType.KNIGHT: knight_scene,
		ChessPiece.PieceType.BISHOP: bishop_scene,
		ChessPiece.PieceType.ROOK: rook_scene,
		ChessPiece.PieceType.QUEEN: queen_scene,
		ChessPiece.PieceType.KING: king_scene
	}

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
			tile.tile_right_clicked.connect(handle_tile_right_clicked)

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
	_spawn_piece_at(3, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	_spawn_piece_at(4, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	_spawn_piece_at(5, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	_spawn_piece_at(4, 0, ChessPiece.PieceType.KING, ChessPiece.Team.WHITE)

	# 2. Spawn initial random enemy pieces along top n rows rows (i.e. if n = 2 then y = 6 and y = 7)
	for y in range(6, 8):
		_spawn_random_enemy_row(y, ChessPiece.Team.BLACK)

func _spawn_random_enemy_row(y: int, team: ChessPiece.Team) -> void:
	var enemy_types: Array[ChessPiece.PieceType] = [
		ChessPiece.PieceType.PAWN,
		ChessPiece.PieceType.KNIGHT,
		ChessPiece.PieceType.BISHOP,
		ChessPiece.PieceType.ROOK,
		ChessPiece.PieceType.QUEEN
	]
	## Enemy row generator ensuring pieces are not placed on existing units
	for x in range(8):
		if get_piece(x, y) != null:
			continue
		if randf() < enemy_spawn_chance:
			var random_type: ChessPiece.PieceType = enemy_types.pick_random()
			_spawn_piece_at(x, y, random_type, team)

func _generate_coins_for_pawns() -> void:
	var pawn_count := 0
	for piece in pieces:
		if piece != null and piece.team == ChessPiece.Team.WHITE and piece.piece_type == ChessPiece.PieceType.PAWN:
			pawn_count += 1

	if pawn_count > 0:
		coins += pawn_count
		coins_gained.emit(pawn_count)

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

	#Drop-in animation when spawned
	piece.position.y += 5.0
	var drop_tween: Tween = get_tree().create_tween()
	drop_tween.tween_property(piece, "position:y", local_top_y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	return piece

# --- check if board is cleared ---
var is_board_cleared: bool = false:
	set(value):
		if is_board_cleared != value:
			is_board_cleared = value
			emit_signal("board_cleared_state_changed", is_board_cleared)
			if is_board_cleared:
				_on_board_cleared()

# Returns true if there are zero enemy (BLACK) pieces on the board
func check_is_board_cleared() -> bool:
	for piece in pieces:
		if piece != null and piece.team == ChessPiece.Team.BLACK:
			return false # Found a black piece, board is not clear
	return true

# Re-evaluates board state and updates the boolean variable
func update_board_cleared_state() -> void:
	is_board_cleared = check_is_board_cleared()

func _on_board_cleared() -> void:
	print("Board cleared! No black pieces remaining.")
	# 
	advance_rows(4)
# --- Board Advance Mechanics ---

func advance_rows(rows: int) -> void:
	deselect_piece()
	is_advancing = true
	var tween: Tween = get_tree().create_tween().set_parallel(true)

	var old_tiles_grid: Array[ChessTile] = tiles.duplicate()
	var old_pieces_grid: Array[ChessPiece] = pieces.duplicate()

	tiles.fill(null)
	pieces.fill(null)

	var removed_tiles: Array[ChessTile] = []

	for y in range(8):
		for x in range(8):
			var tile: ChessTile = old_tiles_grid[y * 8 + x]
			var piece: ChessPiece = old_pieces_grid[y * 8 + x]

			if y < rows:
				removed_tiles.append(tile)
				var subtween: Tween = get_tree().create_tween().set_parallel(true)
				if is_board_cleared and piece and piece.team == ChessPiece.Team.WHITE:
					# Detach immediately so the piece isn't dragged through the
					# recycled tile's fall/teleport animation. It gets re-parented
					# to its real tile once the shift settles.
					piece.reparent(self, true)
					set_piece(x, y, piece)
				elif piece:
					subtween.chain().tween_callback(piece.queue_free)
				subtween.tween_property(tile, "process_mode", PROCESS_MODE_DISABLED, 0)
				subtween.tween_property(tile, "position:y", -10, 0.1).set_delay(x * 0.1)
				subtween.chain().tween_property(tile, "visible", false, 0)
				subtween.tween_property(tile, "position:y", 10, 0)
				subtween.tween_property(tile, "position:z", tile.position.z - 8 * tile.size.z, 0)
				subtween.tween_property(tile, "visible", true, 0)
				subtween.tween_property(tile, "position:y", 0, 0.5).set_delay(x * 0.01)
				tween.tween_subtween(subtween)
			else:
				var new_y := y - rows
				set_tile(x, new_y, tile)

				if is_board_cleared and piece and piece.team == ChessPiece.Team.WHITE:
					set_piece(x, y, piece)
				elif piece:
					set_piece(x, new_y, piece)

	var tile_index := 0
	for y in range(rows):
		var top_y := (8 - rows) + y
		for x in range(8):
			var recycled_tile: ChessTile = removed_tiles[tile_index]
			tile_index += 1
			recycled_tile.occupying_piece = null
			set_tile(x, top_y, recycled_tile)

	await tween.finished

	tween = get_tree().create_tween().set_parallel(true)
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)
			if tile:
				tile.occupying_piece = piece
				tween.tween_property(tile, "position:z", tile.position.z + rows * tile.size.z, 0.5)
				tween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)
			if piece:
				var tile_width: float = tile.size.x if tile else 1.0
				var tile_depth: float = tile.size.z if tile else 1.0
				var target_3d := Vector3((x - 3.5) * tile_width, 0.0, (3.5 - y) * tile_depth)
				tween.tween_property(piece, "global_position", target_3d, 0.5)

	await tween.finished

	# Re-attach every piece to whatever tile now actually sits at its grid cell,
	# so future logic (move_piece, current_tile, etc.) stays consistent.
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)
			if piece and tile and piece.get_parent() != tile:
				piece.reparent(tile, true)
				piece.current_tile = tile

	for y in range(8 - rows, 8):
		_spawn_random_enemy_row(y, ChessPiece.Team.BLACK)

	update_board_cleared_state()
	is_advancing = false
	
func handle_tile_clicked(tile: ChessTile) -> void:
	if is_advancing:
		return

	var clicked_pos := tile.board_position
	var clicked_piece := get_piece(clicked_pos.x, clicked_pos.y)

	# 1. Select player piece if it matches active turn team
	if clicked_piece:
		var current_team := ChessPiece.Team.WHITE if turn == TurnState.WHITE else ChessPiece.Team.BLACK
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
	
	
func handle_tile_right_clicked(tile: ChessTile) -> void:
	tile_right_clicked.emit(tile)
	

func select_piece(piece: ChessPiece) -> void:
	deselect_piece()
	selected_piece = piece
	selected_piece.set_selected_visual(true)
	
	# Calculate move options based on piece type
	match piece.piece_type:
		ChessPiece.PieceType.PAWN:
			valid_move_tiles = get_pawn_moves(piece)
		ChessPiece.PieceType.KING:
			valid_move_tiles = get_king_moves(piece)
		ChessPiece.PieceType.KNIGHT:
			valid_move_tiles = get_knight_moves(piece)
		ChessPiece.PieceType.ROOK:
			valid_move_tiles = get_sliding_moves(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
			])
		ChessPiece.PieceType.QUEEN:
			valid_move_tiles = get_sliding_moves(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
		ChessPiece.PieceType.BISHOP:
			valid_move_tiles = get_sliding_moves(piece, [
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
			

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
			
	if selected_piece and selected_piece.is_selected:
		selected_piece.set_selected_visual(false)
	selected_piece = null
	valid_move_tiles.clear()

# --- Movement Logic ---
## Calculates ray/sliding moves for Rook, Bishop, and Queen
func get_sliding_moves(piece: ChessPiece, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var start_pos: Vector2i = piece.board_position

	for dir in directions:
		var current_pos: Vector2i = start_pos + dir

		while is_valid_position(current_pos):
			var target_piece: ChessPiece = get_piece(current_pos.x, current_pos.y)

			if target_piece == null:
				# Empty tile: valid move, keep sliding along ray
				moves.append(current_pos)
			elif target_piece.team != piece.team:
				# Enemy piece: capture move, stop sliding ray
				moves.append(current_pos)
				break
			else:
				# Friendly piece: blocked, stop sliding ray
				break

			current_pos += dir

	return moves


## Calculates fixed L-shaped jump moves for Knight
func get_knight_moves(piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
	]

	for offset in offsets:
		var target_pos: Vector2i = piece.board_position + offset
		if is_valid_position(target_pos):
			var target_piece: ChessPiece = get_piece(target_pos.x, target_pos.y)
			if target_piece == null or target_piece.team != piece.team:
				moves.append(target_pos)

	return moves

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

const CAPTURE_COIN_VALUES: Dictionary[ChessPiece.PieceType, int] = {
	ChessPiece.PieceType.PAWN: 1,
	ChessPiece.PieceType.KNIGHT: 1,
	ChessPiece.PieceType.BISHOP: 1,
	ChessPiece.PieceType.ROOK: 1,
	ChessPiece.PieceType.QUEEN: 1,
	ChessPiece.PieceType.KING: 10
}

## Grid boundary check (assuming 8x8 grid)
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

# --- Piece Execution ---
func move_piece(piece: ChessPiece, target_pos: Vector2i) -> void:
	var old_pos := piece.board_position
	var target_tile := get_tile(target_pos.x, target_pos.y)
	var enemy_piece := get_piece(target_pos.x, target_pos.y)

	if enemy_piece:
		if piece.team == ChessPiece.Team.WHITE and enemy_piece.team == ChessPiece.Team.BLACK:
			_award_capture_coins(enemy_piece)
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
	
	# Check if capturing this piece cleared the board
	update_board_cleared_state()

	var local_top_y := target_tile.size.y / 2.0
	var move_tween := get_tree().create_tween()
	move_tween.tween_property(piece, "position", Vector3(0, local_top_y, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _award_capture_coins(captured_piece: ChessPiece) -> void:
	var value: int = CAPTURE_COIN_VALUES.get(captured_piece.piece_type, 0)
	if value > 0:
		coins += value
		coins_gained.emit(value)
	print("current coins: ", coins)

# -- valid moves ---
func get_valid_moves(piece: ChessPiece) -> Array[Vector2i]:
	var valid_moves: Array[Vector2i] = []
	if piece == null:
		return valid_moves

	match piece.piece_type:
		ChessPiece.PieceType.PAWN:
			return get_pawn_moves(piece)
		ChessPiece.PieceType.KNIGHT:
			return get_knight_moves(piece)
		ChessPiece.PieceType.ROOK:
			return get_sliding_moves(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
			])
		ChessPiece.PieceType.BISHOP:
			return get_sliding_moves(piece, [
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
		ChessPiece.PieceType.QUEEN:
			return get_sliding_moves(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
		ChessPiece.PieceType.KING:
			return get_king_moves(piece)

	return valid_moves

#--- enemy turn ---

# Inner class to evaluate and sort potential AI moves
class AIMove:
	var piece: ChessPiece
	var target_pos: Vector2i
	var score: float

	func _init(p_piece: ChessPiece, p_target: Vector2i, p_score: float) -> void:
		piece = p_piece
		target_pos = p_target
		score = p_score

#func get_sliding_moves(piece: ChessPiece, directions: Array[Vector2i]) -> Array[Vector2i]:
	#var moves: Array[Vector2i] = []
	#for dir in directions:
		#var step := 1
		#while true:
			#var target := piece.board_position + (dir * step)
			#if not is_in_bounds(target):
				#break
			#var occupant := get_piece(target.x, target.y)
			#if occupant == null:
				#moves.append(target)
			#elif occupant.team != piece.team:
				#moves.append(target)
				#break
			#else:
				#break
			#step += 1
	#return moves

func process_enemy_turn() -> void:
	# Brief delay so enemy move doesn't happen instantly
	await get_tree().create_timer(0.5).timeout

	var possible_moves: Array[AIMove] = []

	# Gather all black pieces currently on the board
	for x in range(8):
		for y in range(8):
			var piece := get_piece(x, y)
			if piece and piece.team == ChessPiece.Team.BLACK:
				var valid_tiles := get_valid_moves(piece)
				for target_pos in valid_tiles:
					var score := _evaluate_move(piece, target_pos)
					possible_moves.append(AIMove.new(piece, target_pos, score))

	if possible_moves.is_empty():
		end_turn()
		return

	# Sort moves by highest score
	possible_moves.sort_custom(func(a: AIMove, b: AIMove) -> bool: return a.score > b.score)

	var best_move: AIMove = possible_moves[0]
	move_piece(best_move.piece, best_move.target_pos)
	end_turn()

func _evaluate_move(piece: ChessPiece, target_pos: Vector2i) -> float:
	var score: float = 0.0
	var target_piece := get_piece(target_pos.x, target_pos.y)

	# High score priority for capturing white pieces
	if target_piece and target_piece.team == ChessPiece.Team.WHITE:
		match target_piece.piece_type:
			ChessPiece.PieceType.KING: score += 100.0
			ChessPiece.PieceType.QUEEN: score += 9.0
			ChessPiece.PieceType.ROOK: score += 5.0
			ChessPiece.PieceType.BISHOP: score += 3.0
			ChessPiece.PieceType.KNIGHT: score += 3.0
			ChessPiece.PieceType.PAWN: score += 1.0

	# Encourage forward movement (towards y = 0)
	score += (7 - target_pos.y) * 0.1

	# Add random noise to break ties
	score += randf() * 0.05
	return score


	
