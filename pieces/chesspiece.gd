class_name ChessPiece
extends Node3D

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Team { WHITE, BLACK }

@export var piece_type: PieceType = PieceType.PAWN
@export var team: Team = Team.WHITE
@export var mesh_node: MeshInstance3D

var is_highlighted: bool = false
var is_selected: bool = false
var board_position: Vector2i = Vector2i.ZERO
var current_tile: ChessTile = null

func apply_team_color(new_team: Team) -> void:
	team = new_team
	var mat := StandardMaterial3D.new()
	if team == Team.WHITE:
		mat.albedo_color = Color(0.9, 0.9, 0.9)
	else:
		mat.albedo_color = Color(0.15, 0.15, 0.15)
	
	_apply_material_override_recursive(self, mat)

func _apply_material_override_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_override_recursive(child, material)

func set_selected_visual(selected: bool) -> void:
	is_selected = selected
	var target_y: float = 0.4 if selected else 0.0
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + target_y, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT if selected else Tween.EASE_IN)

func animate_move_to_position(target_world_pos: Vector3) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:x", target_world_pos.x, 0.25)
	tween.tween_property(self, "global_position:z", target_world_pos.z, 0.25)
	
	var peak_y := target_world_pos.y + 0.8
	tween.tween_property(self, "global_position:y", peak_y, 0.125)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "global_position:y", target_world_pos.y, 0.125)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
	is_selected = false
