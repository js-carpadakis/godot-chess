extends "res://3d/pieces/Piece3D.gd"
## @brief 3D King chess piece.
## @details Tallest piece with a cross on top.

func _ready() -> void:
	piece_type = "king"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.35, 0.3, 0.15, 0.075)
	# Body (tapered)
	_add_cylinder(0.22, 0.15, 0.6, 0.45)
	# Neck
	_add_cylinder(0.1, 0.13, 0.12, 0.81)
	# Crown band
	_add_cylinder(0.17, 0.17, 0.08, 0.91)
	# Cross vertical
	_add_box(Vector3(0.05, 0.25, 0.05), 1.08)
	# Cross horizontal
	_add_box(Vector3(0.18, 0.05, 0.05), 1.13)
