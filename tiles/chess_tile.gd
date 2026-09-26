class_name ChessTile
extends Node3D

enum TileType { WHITE, BLACK }

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $Area3D
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
# Grid coordinate on the board (e.g., Vector2i(0, 0))
var board_position: Vector2i = Vector2i.ZERO
# Reference to the piece currently on this tile (null if empty)
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

func _update_tile():
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
