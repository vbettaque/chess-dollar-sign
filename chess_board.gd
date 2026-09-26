class_name ChessBoard
extends Node3D

const CHESS_TILE = preload("uid://bre0otua4gpui")

var is_advancing: bool = false
var tiles: Array[ChessTile]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tiles.resize(64)
	_init_board()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_tile(x, y, tile: ChessTile) -> void:
	tiles[y * 8 + x] = tile

func get_tile(x, y) -> ChessTile:
	return tiles[y * 8 + x]

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
var black_piece_count = 5

func _ready() -> void:
	_setup_piece_dictionary()
	_init_board()
	_spawn_custom_pawns()
	_spawn_random_black_pawns(black_piece_count)


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

func advance_rows(rows: int):
	is_advancing = true
	var tween = get_tree().create_tween().set_parallel(true)
	var removed_tiles: Array[ChessTile]
	removed_tiles.resize(8 * rows)
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			if y < rows:
				removed_tiles[8 * y + x] = tile
				var subtween = get_tree().create_tween()
				subtween.tween_property(tile, "process_mode", PROCESS_MODE_DISABLED, 0)
				subtween.tween_property(tile, "position:y", -10, 0.1).set_delay(x * 0.1)
				subtween.tween_property(tile, "visible", false, 0)
				subtween.tween_property(tile, "position:y", 10, 0)
				subtween.tween_property(tile, "position:z", tile.position.z - 8 * tile.size.z, 0)
				subtween.tween_property(tile, "visible", true, 0)
				subtween.tween_property(tile, "position:y", 0, 0.5).set_delay(x * 0.01)
				subtween.tween_property(tile, "process_mode", PROCESS_MODE_INHERIT, 0)
				tween.tween_subtween(subtween)
			else:
				set_tile(x, y - rows, tile)
	for x in range(8):
		for y in range(rows):
			set_tile(x, 8 - rows, removed_tiles[8 * y + x])
	await tween.finished
	
	tween = get_tree().create_tween().set_parallel(true)
	for x in range(8):
		for y in range(8):
			var tile: ChessTile = get_tile(x, y)
			tween.tween_property(tile, "position:z", tile.position.z + rows * tile.size.z, 1)
	tween.chain().tween_property(self, "is_advancing", false, 0)
		

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

func _spawn_random_black_pawns(count: int) -> void:
	if not pawn_scene:
		push_error("pawn_scene is null! Please assign pawn.tscn in the Inspector.")
		return

	# Collect all keys for tiles that are currently empty
	var empty_tile_keys: Array[Vector2i] = []
	for key in grid.keys():
		var tile: ChessTile = grid[key]
		if not tile.is_occupied():
			empty_tile_keys.append(key)

	# Shuffle the available positions randomly
	empty_tile_keys.shuffle()

	# Clamp spawn count to available empty tiles
	var spawn_amount = min(count, empty_tile_keys.size())

	for i in range(spawn_amount):
		var target_key: Vector2i = empty_tile_keys[i]
		_spawn_pawn_at(target_key, ChessPiece.Team.BLACK)


func _spawn_pawn_at(tile_key: Vector2i, team: ChessPiece.Team) -> void:
	var target_tile: ChessTile = grid[tile_key]
	var pawn: ChessPiece = pawn_scene.instantiate() as ChessPiece

	if not pawn:
		push_error("Failed to instantiate pawn_scene as ChessPiece.")
		return

	add_child(pawn)
	pawn.piece_type = ChessPiece.PieceType.PAWN
	pawn.apply_team_color(team)

	# Snap piece transform to tile center
	target_tile.occupying_piece = pawn
	pawn.current_tile = target_tile
	pawn.board_position = tile_key
	
	# Position pawn on top of tile surface without movement logic/tweens
	var target_global_pos = target_tile.global_position + Vector3(0, target_tile.size.y / 2.0, 0)
	pawn.global_position = target_global_pos

func get_tile(i: int, j: int) -> ChessTile:
	return grid.get(Vector2i(i, j), null)
