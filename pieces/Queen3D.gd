extends "res://pieces/Piece3D.gd"
## @brief 3D Queen chess piece.
## @details Tall elegant piece with a crown of small spheres on top.

func _ready() -> void:
	piece_type = "queen"
	super._ready()

func _build_mesh() -> void:
	# Base
	_add_cylinder(0.35, 0.3, 0.15, 0.075)
	# Body (elegantly tapered)
	_add_cylinder(0.22, 0.14, 0.6, 0.45)
	# Neck
	_add_cylinder(0.1, 0.12, 0.12, 0.81)
	# Crown ring
	_add_cylinder(0.16, 0.16, 0.06, 0.9)
	# Crown points (small spheres in a ring)
	for i in range(6):
		var angle = PI * 2.0 * i / 6.0
		var px = cos(angle) * 0.14
		var pz = sin(angle) * 0.14
		var point = _add_sphere(0.04, 0.97)
		point.position.x = px
		point.position.z = pz
	# Top sphere
	_add_sphere(0.06, 1.0)
