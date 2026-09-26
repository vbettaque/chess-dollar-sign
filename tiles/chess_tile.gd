class_name ChessTile
extends Node3D

enum TileType { WHITE, BLACK }

@onready var mesh: CSGBox3D = $Mesh

@export var size: Vector3 = Vector3(1, 0.1, 1):
	set(new_size):
		size = new_size
		_update_tile()

@export var type: TileType = TileType.WHITE:
	set(new_type):
		type = new_type
		_update_tile()
	

func _update_tile():
	if not is_node_ready():
		await ready
	mesh.size = size
	
	match type:
		TileType.BLACK:
			print("setting black")
			(mesh.material as StandardMaterial3D).albedo_color = Color.BLACK
		TileType.WHITE:
			print("setting white")
			(mesh.material as StandardMaterial3D).albedo_color = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
