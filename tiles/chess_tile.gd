class_name ChessTile
extends Node3D

signal tile_clicked(tile: ChessTile)
signal tile_right_clicked(tile: ChessTile)

enum TileType { WHITE, BLACK }

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $Area3D
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D

var board_position: Vector2i = Vector2i.ZERO
var occupying_piece: ChessPiece = null

@export var size: Vector3 = Vector3(1, 0.1, 1):
	set(new_size):
		size = new_size
		_update_tile()

@export var type: TileType = TileType.WHITE:
	set(new_type):
		type = new_type
		_update_tile()

@export var tile_materials: Dictionary[TileType, Material] = {}:
	set(new_materials):
		tile_materials = new_materials
		_update_tile()

@export var highlight_material: Material

var highlighted: bool:
	set(new_highlighted):
		highlighted = new_highlighted
		_update_highlighting()

func _ready() -> void:
	# Connect Area3D input event to emit custom signal
	area.input_event.connect(_on_area_input_event)

func _on_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tile_clicked.emit(self)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			tile_right_clicked.emit(self)

func _update_tile() -> void:
	if not is_node_ready():
		await ready
	mesh_instance.mesh.size = size
	collision_shape.shape.size = size

	match type:
		TileType.BLACK:
			mesh_instance.set_surface_override_material(0, tile_materials.get(TileType.BLACK))
		TileType.WHITE:
			mesh_instance.set_surface_override_material(0, tile_materials.get(TileType.WHITE))

func is_occupied() -> bool:
	return occupying_piece != null

func _update_highlighting() -> void:
	if highlighted:
		mesh_instance.get_active_material(0).next_pass = highlight_material
	else:
		mesh_instance.get_active_material(0).next_pass = null
