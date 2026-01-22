extends "res://3d/pieces/Piece3D.gd"
## @brief 3D Pawn chess piece.
## @details Small rounded piece with a base, stem, and spherical top.

func _ready() -> void:
	piece_type = "pawn"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.3, 0.25, 0.15, 0.075)
	# Stem
	_add_cylinder(0.12, 0.1, 0.35, 0.325)
	# Head (sphere)
	_add_sphere(0.15, 0.575)
