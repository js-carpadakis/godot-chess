extends "res://pieces/Piece3D.gd"
## @brief 3D Rook chess piece.
## @details Tower-shaped piece with a base, body, and crenellated top.

func _ready() -> void:
	piece_type = "rook"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.35, 0.3, 0.15, 0.075)
	# Body (tapered cylinder)
	_add_cylinder(0.25, 0.22, 0.5, 0.4)
	# Top platform
	_add_cylinder(0.28, 0.28, 0.1, 0.7)
	# Crenellations (small boxes on top)
	for i in range(4):
		var angle = PI / 2.0 * i + PI / 4.0
		var offset_x = cos(angle) * 0.18
		var offset_z = sin(angle) * 0.18
		var inst = _add_box(Vector3(0.12, 0.12, 0.12), 0.81)
		inst.position.x = offset_x
		inst.position.z = offset_z
