class_name ChessPiece
extends Node3D

# Preload scene resources into a Dictionary for clean lookups
const PIECE_SCENES: Dictionary[PieceType, PackedScene] = {
	PieceType.PAWN: preload("res://pieces/pawn.tscn"),
	PieceType.KNIGHT: preload("res://pieces/knight.tscn"),
	PieceType.BISHOP: preload("res://pieces/bishop.tscn"),
	PieceType.ROOK: preload("res://pieces/rook.tscn"),
	PieceType.QUEEN: preload("res://pieces/queen.tscn"),
	PieceType.KING: preload("res://pieces/king.tscn")
}

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Team { WHITE, BLACK }

@export var piece_type: PieceType = PieceType.PAWN
@export var team: Team = Team.WHITE
@export var mesh_node: MeshInstance3D

const TOON: Shader = preload("uid://o22rcd8gmf35")

var is_highlighted: bool = false
var is_selected: bool = false
var board_position: Vector2i = Vector2i.ZERO
var current_tile: ChessTile = null

func apply_team_color(new_team: Team) -> void:
	team = new_team
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("use_specular", false)
	if team == Team.WHITE:
		mat.set_shader_parameter("albedo", Color(0.9, 0.9, 0.9))
	else:
		mat.set_shader_parameter("albedo", Color(0.30, 0.30, 0.30))
	
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

func change_piece(type: PieceType) -> void:
	piece_type = type
	update_mesh(type)

func update_mesh(type: PieceType) -> void:
	if not is_node_ready(): 
		await ready

	# 1. Remove the old mesh instance if one exists
	if is_instance_valid(mesh_node):
		mesh_node.queue_free()
		mesh_node = null

	# 2. Get the scene for the target piece type
	var scene: PackedScene = PIECE_SCENES.get(type)
	if not scene:
		push_error("No scene found for piece type: ", type)
		return

	# 3. Instantiate and attach the new mesh scene
	var instance := scene.instantiate()
	add_child(instance)

	# 4. Update mesh_node reference
	if instance is MeshInstance3D:
		mesh_node = instance
	else:
		# If the scene root is a Node3D container, grab its first MeshInstance3D child
		mesh_node = instance.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D

	# 5. Re-apply team color shader to the newly added mesh
	apply_team_color(team)
	
