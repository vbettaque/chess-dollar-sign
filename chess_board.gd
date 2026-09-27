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

# --- Signals ---
signal tile_right_clicked(tile: ChessTile)
signal turn_changed(turn: TurnState)
signal board_cleared_state_changed(is_cleared: bool)
signal coins_gained(coins: int)
signal player_king_capture
# --- State & Enums ---
enum TurnState { WHITE, BLACK }
var turn: TurnState = TurnState.WHITE

var is_advancing: bool = false
var tiles: Array[ChessTile]
var pieces: Array[ChessPiece]
var piece_scenes: Dictionary[ChessPiece.PieceType, PackedScene] = {}
var selected_piece: ChessPiece = null
var valid_move_tiles: Array[Vector2i] = []

# --- Placement State ---
var is_placing_piece: bool = false
var placement_type: ChessPiece.PieceType = ChessPiece.PieceType.PAWN
var valid_placement_tiles: Array[Vector2i] = []

var coins: int = 0
const COIN_SCENE = preload("uid://biqs83ynwlj5q")
const CAPTURE_COIN_VALUES: Dictionary[ChessPiece.PieceType, int] = {
	ChessPiece.PieceType.PAWN: 1,
	ChessPiece.PieceType.KNIGHT: 1,
	ChessPiece.PieceType.BISHOP: 1,
	ChessPiece.PieceType.ROOK: 1,
	ChessPiece.PieceType.QUEEN: 1,
	ChessPiece.PieceType.KING: 10
}

var is_board_cleared: bool = false:
	set(value):
		if is_board_cleared != value:
			is_board_cleared = value
			board_cleared_state_changed.emit(is_board_cleared)
			if is_board_cleared:
				_on_board_cleared()

# --- Lifecycle ---
func _ready() -> void:
	tiles.resize(64)
	pieces.resize(64)
	_setup_piece_dictionary()
	_init_board()
	await get_tree().process_frame
	spawn_initial_pieces()

# --- Spawning Logic ---

## Enters placement mode for a new white pawn.
## Highlights all empty tiles on row 0 (y = 0). Left-clicking a highlighted tile spawns the pawn.
func spawn_new_pawn() -> void:
	deselect_piece()
	cancel_placement_mode()

	is_placing_piece = true
	placement_type = ChessPiece.PieceType.PAWN

	for x in range(8):
		if get_piece(x, 0) == null:
			valid_placement_tiles.append(Vector2i(x, 0))

	for pos in valid_placement_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = true

## Clears placement highlights and exits placement mode.
func cancel_placement_mode() -> void:
	for pos in valid_placement_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = false
	valid_placement_tiles.clear()
	is_placing_piece = false

## Spawns a piece of a given type and team at grid coordinates (x, y).
func spawn_piece_at(x: int, y: int, type: ChessPiece.PieceType, team: ChessPiece.Team) -> ChessPiece:
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

	tile.add_child(piece)

	piece.piece_type = type
	piece.apply_team_color(team)
	piece.board_position = Vector2i(x, y)
	piece.current_tile = tile

	tile.occupying_piece = piece
	set_piece(x, y, piece)

	var local_top_y: float = tile.size.y / 2.0
	piece.position = Vector3(0, local_top_y, 0)

	piece.position.y += 5.0
	var drop_tween: Tween = get_tree().create_tween()
	drop_tween.tween_property(piece, "position:y", local_top_y, 0.4)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

	return piece

func spawn_initial_pieces() -> void:
	spawn_piece_at(3, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	spawn_piece_at(4, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	spawn_piece_at(5, 1, ChessPiece.PieceType.PAWN, ChessPiece.Team.WHITE)
	spawn_piece_at(4, 0, ChessPiece.PieceType.KING, ChessPiece.Team.WHITE)

	for y in range(6, 8):
		spawn_random_enemy_row(y, ChessPiece.Team.BLACK)

func spawn_random_enemy_row(y: int, team: ChessPiece.Team) -> void:
	var enemy_types: Array[ChessPiece.PieceType] = [
		ChessPiece.PieceType.PAWN,
		ChessPiece.PieceType.KNIGHT,
		ChessPiece.PieceType.BISHOP,
		ChessPiece.PieceType.ROOK,
		ChessPiece.PieceType.QUEEN
	]

	for x in range(8):
		if get_piece(x, y) != null:
			continue
		if randf() < enemy_spawn_chance:
			var random_type: ChessPiece.PieceType = enemy_types.pick_random()
			spawn_piece_at(x, y, random_type, team)

# --- Turn Handling ---
func end_turn() -> void:
	deselect_piece()

	if turn == TurnState.WHITE:
		_generate_coins_for_pawns()

	turn = TurnState.BLACK if turn == TurnState.WHITE else TurnState.WHITE
	turn_changed.emit(turn)

	if turn == TurnState.BLACK:
		process_enemy_turn()

# --- Grid Helpers ---
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

func _init_board() -> void:
	for i in range(8):
		for j in range(8):
			var tile: ChessTile = CHESS_TILE.instantiate()
			var x := (i - 3.5) * tile.size.x
			var z := (3.5 - j) * tile.size.z
			set_tile(i, j, tile)
			add_child(tile)
			tile.position = Vector3(x, 10, z)

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

func _generate_coins_for_pawns() -> void:
	var pawn_count := 0
	for piece in pieces:
		if piece != null and piece.team == ChessPiece.Team.WHITE and piece.piece_type == ChessPiece.PieceType.PAWN:
			_spawn_coin_for_piece(piece)
			pawn_count += 1

	if pawn_count > 0:
		coins += pawn_count
		coins_gained.emit(pawn_count)
		
func _spawn_coin_for_piece(piece: ChessPiece) -> void:
	if piece == null:
		return
	var coin_instance = COIN_SCENE.instantiate()
	if not coin_instance is Node3D:
		push_error("COIN_SCENE root node must inherit from Node3D!")
		return

	var spawn_offset := Vector3(0.0, 1.0, -0.8)
	coin_instance.global_position = piece.global_position + spawn_offset
	add_child(coin_instance)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(coin_instance, "global_position:y", coin_instance.global_position.y + 0.5, 1.0)
	tween.tween_property(coin_instance, "scale", Vector3.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(coin_instance.queue_free)
	
# --- Board Cleared Check ---
func check_is_board_cleared() -> bool:
	for piece in pieces:
		if piece != null and piece.team == ChessPiece.Team.BLACK:
			return false
	return true

func update_board_cleared_state() -> void:
	is_board_cleared = check_is_board_cleared()

func _on_board_cleared() -> void:
	print("Board cleared! No black pieces remaining.")
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

	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			var piece: ChessPiece = get_piece(x, y)
			if piece and tile and piece.get_parent() != tile:
				piece.reparent(tile, true)
				piece.current_tile = tile

	for y in range(8 - rows, 8):
		spawn_random_enemy_row(y, ChessPiece.Team.BLACK)

	update_board_cleared_state()
	is_advancing = false

# --- Input & Selection ---
func handle_tile_clicked(tile: ChessTile) -> void:
	if is_advancing:
		return

	var clicked_pos := tile.board_position

	if is_placing_piece:
		if clicked_pos in valid_placement_tiles:
			spawn_piece_at(clicked_pos.x, clicked_pos.y, placement_type, ChessPiece.Team.WHITE)
		cancel_placement_mode()
		return

	var clicked_piece := get_piece(clicked_pos.x, clicked_pos.y)

	if clicked_piece:
		var current_team := ChessPiece.Team.WHITE if turn == TurnState.WHITE else ChessPiece.Team.BLACK
		if clicked_piece.team == current_team:
			select_piece(clicked_piece)
			return

	if selected_piece and clicked_pos in valid_move_tiles:
		move_piece(selected_piece, clicked_pos)
		end_turn()
		return

	deselect_piece()

func handle_tile_right_clicked(tile: ChessTile) -> void:
	tile_right_clicked.emit(tile)

func select_piece(piece: ChessPiece) -> void:
	deselect_piece()
	selected_piece = piece
	selected_piece.set_selected_visual(true)

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

	for pos in valid_move_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = true

func deselect_piece() -> void:
	if is_placing_piece:
		cancel_placement_mode()

	for pos in valid_move_tiles:
		var tile := get_tile(pos.x, pos.y)
		if tile:
			tile.highlighted = false

	if selected_piece and selected_piece.is_selected:
		selected_piece.set_selected_visual(false)
	selected_piece = null
	valid_move_tiles.clear()

# --- Movement Logic ---
func get_sliding_moves(piece: ChessPiece, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var start_pos: Vector2i = piece.board_position

	for dir in directions:
		var current_pos: Vector2i = start_pos + dir
		while is_valid_position(current_pos):
			var target_piece: ChessPiece = get_piece(current_pos.x, current_pos.y)
			if target_piece == null:
				moves.append(current_pos)
			elif target_piece.team != piece.team:
				moves.append(current_pos)
				break
			else:
				break
			current_pos += dir

	return moves

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

	var offsets: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                   Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	for offset in offsets:
		var target_pos := pos + offset
		if is_in_bounds(target_pos):
			var target_piece := get_piece(target_pos.x, target_pos.y)
			if target_piece == null or target_piece.team != king.team:
				moves.append(target_pos)
	return moves

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func move_piece(piece: ChessPiece, target_pos: Vector2i) -> void:
	var old_pos := piece.board_position
	var target_tile := get_tile(target_pos.x, target_pos.y)
	var enemy_piece := get_piece(target_pos.x, target_pos.y)

	if enemy_piece:
		if piece.team == ChessPiece.Team.WHITE and enemy_piece.team == ChessPiece.Team.BLACK:
			_award_capture_coins(enemy_piece)
		if enemy_piece.team == ChessPiece.Team.WHITE and enemy_piece.piece_type == ChessPiece.PieceType.KING:
			player_king_capture.emit()
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

	update_board_cleared_state()

	var local_top_y := target_tile.size.y / 2.0
	var move_tween := get_tree().create_tween()
	move_tween.tween_property(piece, "position", Vector3(0, local_top_y, 0), 0.25)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

func _award_capture_coins(captured_piece: ChessPiece) -> void:
	var value: int = CAPTURE_COIN_VALUES.get(captured_piece.piece_type, 0)
	if value > 0:
		coins += value
		coins_gained.emit(value)

func get_valid_moves(piece: ChessPiece) -> Array[Vector2i]:
	if piece == null:
		return []

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

	return []

# --- AI Enemy Turn ---
class AIMove:
	var piece: ChessPiece
	var target_pos: Vector2i
	var score: float

	func _init(p_piece: ChessPiece, p_target: Vector2i, p_score: float) -> void:
		piece = p_piece
		target_pos = p_target
		score = p_score

func process_enemy_turn() -> void:
	await get_tree().create_timer(0.5).timeout

	var possible_moves: Array[AIMove] = []

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

	possible_moves.sort_custom(func(a: AIMove, b: AIMove) -> bool: return a.score > b.score)

	var best_move: AIMove = possible_moves[0]
	move_piece(best_move.piece, best_move.target_pos)
	end_turn()

func _evaluate_move(piece: ChessPiece, target_pos: Vector2i) -> float:
	var score: float = 0.0
	var target_piece := get_piece(target_pos.x, target_pos.y)

	if target_piece and target_piece.team == ChessPiece.Team.WHITE:
		match target_piece.piece_type:
			ChessPiece.PieceType.KING: score += 100.0
			ChessPiece.PieceType.QUEEN: score += 9.0
			ChessPiece.PieceType.ROOK: score += 5.0
			ChessPiece.PieceType.BISHOP: score += 3.0
			ChessPiece.PieceType.KNIGHT: score += 3.0
			ChessPiece.PieceType.PAWN: score += 1.0

	score += (7 - target_pos.y) * 0.1
	score += randf() * 0.05
	return score
