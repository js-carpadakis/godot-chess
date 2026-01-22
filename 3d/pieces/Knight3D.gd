extends "res://3d/pieces/Piece3D.gd"
## @brief 3D Knight chess piece.
## @details Horse-head shaped piece using a tilted cylinder for the neck and sphere for the head.

func _ready() -> void:
	piece_type = "knight"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.35, 0.3, 0.15, 0.075)
	# Body/neck (tilted forward)
	var neck = _add_cylinder(0.15, 0.12, 0.5, 0.4)
	neck.rotation.z = -0.3
	neck.position.x = 0.05
	# Head (elongated sphere for horse snout)
	var head = _add_sphere(0.18, 0.72)
	head.position.x = 0.1
	# Ears (two small cylinders)
	var ear1 = _add_cylinder(0.04, 0.02, 0.12, 0.88)
	ear1.position.x = 0.05
	ear1.position.z = 0.06
	var ear2 = _add_cylinder(0.04, 0.02, 0.12, 0.88)
	ear2.position.x = 0.05
	ear2.position.z = -0.06
