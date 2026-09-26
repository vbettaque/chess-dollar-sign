extends Node3D

const CHESS_TILE = preload("uid://bre0otua4gpui")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_board()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _init_board() -> void:
	for i in range(8):
		for j in range(8):
			var tile: ChessTile = CHESS_TILE.instantiate()
			var x := (i - 3.5) * tile.size.x
			var z := (3.5 - j) * tile.size.z
			add_child(tile)
			
			if (i + j) % 2 == 0:
				print(i, " ", j, ": white")
				tile.type = ChessTile.TileType.WHITE
			else:
				print(i, " ", j, ": black")
				tile.type = ChessTile.TileType.BLACK
				
			tile.position = Vector3(x, 0, z)
