extends Control

const KNIGHT_IDX: int = 1
const BISHOP_IDX: int = 2
const ROOK_IDX: int = 3
const QUEEN_IDX: int = 4

const PAWN_PRICE: int = 5
const KNIGHT_PRICE: int = 7
const BISHOP_PRICE: int = 10
const ROOK_PRICE: int = 15
const QUEEN_PRICE: int = 25

@onready var world: World = $SubViewportContainer/SubViewport/World
@onready var upgrade_menu: PopupMenu = $UpgradeMenu

@onready var turn_counter: Label = $InfoContainer/VBoxContainer/TurnCounter

@onready var coin_container: HBoxContainer = $InfoContainer/VBoxContainer/CoinContainer
@onready var coin_texture: TextureRect = $InfoContainer/VBoxContainer/CoinContainer/CoinTexture
@onready var coin_counter: Label = $InfoContainer/VBoxContainer/CoinContainer/CoinCounter
@onready var pawn_button: Button = $MarginContainer/PawnButton

@export var coins: int = 10:
	set(new_coins):
		coins = new_coins
		if not is_node_ready():
			await ready
		_update_coin_counter()
		

@export var turn: int = 1:
	set(new_turn):
		turn = new_turn
		if not is_node_ready():
			await ready
		turn_counter.text = str("Turn: ", turn)

var right_clicked_tile: ChessTile

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	upgrade_menu.title = "Upgrade"
	_populate_upgrade_window()
	upgrade_menu.index_pressed.connect(_on_index_pressed)
	world.tile_right_clicked.connect(_on_tile_right_clicked)
	world.chess_board.turn_changed.connect(_on_turn_changed)
	world.chess_board.coins_gained.connect(_on_coins_gained)
	pawn_button.pressed.connect(_on_pawn_button_pressed)
	coins = coins
	turn = turn
	

func _on_tile_right_clicked(tile: ChessTile) -> void:
	if not tile.occupying_piece:
		return
	var piece: ChessPiece = tile.occupying_piece
	if piece.team == ChessPiece.Team.WHITE and piece.piece_type == ChessPiece.PieceType.PAWN:
		_open_upgrade_window()
		right_clicked_tile = tile
	
	
		
func _populate_upgrade_window() -> void:
	upgrade_menu.set_item_text(KNIGHT_IDX, str("Knight (", KNIGHT_PRICE, ")"))
	upgrade_menu.set_item_text(BISHOP_IDX, str("Bishop (", BISHOP_PRICE, ")"))
	upgrade_menu.set_item_text(ROOK_IDX, str("Rook (", ROOK_PRICE, ")"))
	upgrade_menu.set_item_text(QUEEN_IDX, str("Queen (", QUEEN_PRICE, ")"))


func _open_upgrade_window() -> void:
	upgrade_menu.position = get_global_mouse_position()
	upgrade_menu.set_item_disabled(KNIGHT_IDX, KNIGHT_PRICE > coins)
	upgrade_menu.set_item_disabled(BISHOP_IDX, BISHOP_PRICE > coins)
	upgrade_menu.set_item_disabled(ROOK_IDX, ROOK_PRICE > coins)
	upgrade_menu.set_item_disabled(QUEEN_IDX, QUEEN_PRICE > coins)
	upgrade_menu.popup()
	

func _on_index_pressed(idx: int) -> void:
	match idx:
		KNIGHT_IDX:
			coins -= KNIGHT_PRICE
			_upgrade_piece(right_clicked_tile.occupying_piece, ChessPiece.PieceType.KNIGHT)
		BISHOP_IDX:
			coins -= BISHOP_PRICE
			_upgrade_piece(right_clicked_tile.occupying_piece, ChessPiece.PieceType.BISHOP)
		ROOK_IDX:
			coins -= ROOK_PRICE
			_upgrade_piece(right_clicked_tile.occupying_piece, ChessPiece.PieceType.ROOK)
		QUEEN_IDX:
			coins -= QUEEN_PRICE
			_upgrade_piece(right_clicked_tile.occupying_piece, ChessPiece.PieceType.QUEEN)

func _update_coin_counter() -> void:
	coin_counter.text = str(coins)
	pawn_button.disabled = (coins < PAWN_PRICE)
	var tween = coin_texture.create_tween()
	tween.tween_property(coin_texture, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(coin_texture, "scale", Vector2(1, 1), 0.2)
	

func _upgrade_piece(piece: ChessPiece, type: ChessPiece.PieceType) -> void:
	piece.change_piece(type)
	world.chess_board.end_turn()

func _on_turn_changed(turn_state: ChessBoard.TurnState) -> void:
	if turn_state == ChessBoard.TurnState.WHITE:
		turn += 1
	
func _on_coins_gained(new_coins: int) -> void:
	coins += new_coins
	
func _on_pawn_button_pressed() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
