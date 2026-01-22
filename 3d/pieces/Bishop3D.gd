extends "res://3d/pieces/Piece3D.gd"
## @brief 3D Bishop chess piece.
## @details Tall piece with a tapered body and pointed mitre top.

func _ready() -> void:
	piece_type = "bishop"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.35, 0.28, 0.15, 0.075)
	# Body (tapered)
	_add_cylinder(0.2, 0.12, 0.55, 0.425)
	# Mitre (pointed top - very tapered cylinder)
	_add_cylinder(0.12, 0.02, 0.25, 0.825)
	# Small sphere on very top
	_add_sphere(0.05, 0.975)
