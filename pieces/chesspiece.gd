class_name ChessPiece
extends Node3D

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Team { WHITE, BLACK }

@export var piece_type: PieceType = PieceType.PAWN
@export var team: Team = Team.WHITE

var board_position: Vector2i = Vector2i.ZERO
var current_tile: ChessTile = null


func apply_team_color(new_team: Team) -> void:
	team = new_team
	
	var mat := StandardMaterial3D.new()
	if team == Team.WHITE:
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = Color(0.15, 0.15, 0.15)
	
	_apply_material_override_recursive(self, mat)


func _apply_material_override_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		
	for child in node.get_children():
		_apply_material_override_recursive(child, material)


func animate_to_tile(target_tile: ChessTile, new_board_pos: Vector2i) -> void:
	current_tile = target_tile
	board_position = new_board_pos
	
	var target_global_pos = target_tile.global_position + Vector3(0, target_tile.size.y / 2.0, 0)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.2).set_trans(Tween.TRANS_QUAD)

func set_selected_visual(selected: bool) -> void:
	if not current_tile:
		return
		
	var target_y := (current_tile.size.y / 2.0) + (0.2 if selected else 0.0)
	var target_pos := current_tile.global_position + Vector3(0, target_y, 0)
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.1).set_trans(Tween.TRANS_QUAD)
