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
			
			
			
			
