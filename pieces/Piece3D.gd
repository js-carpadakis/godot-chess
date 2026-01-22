extends Node3D
## @brief Base class for all 3D chess pieces.
## @details Provides common properties and mesh/material setup for 3D pieces.

class_name Piece3D

@export var color: String = "white"
@export var piece_type: String = ""

var mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

func _ready() -> void:
	_setup_material()
	_build_mesh()

## @brief Creates the material for the piece based on its color.
func _setup_material() -> void:
	_material = StandardMaterial3D.new()
	if color == "white":
		_material.albedo_color = Color(0.92, 0.9, 0.85)
		_material.metallic = 0.1
		_material.roughness = 0.3
	else:
		_material.albedo_color = Color(0.15, 0.12, 0.1)
		_material.metallic = 0.15
		_material.roughness = 0.25

## @brief Override in subclasses to build the piece mesh.
func _build_mesh() -> void:
	pass

## @brief Helper to create a cylinder mesh section (base, body, etc).
func _add_cylinder(bottom_radius: float, top_radius: float, height: float, y_offset: float, segments: int = 16) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _material
	inst.position.y = y_offset
	add_child(inst)
	return inst

## @brief Helper to create a sphere mesh.
func _add_sphere(radius: float, y_offset: float, segments: int = 16) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments * 0.5
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _material
	inst.position.y = y_offset
	add_child(inst)
	return inst

## @brief Helper to create a box mesh.
func _add_box(size: Vector3, y_offset: float) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _material
	inst.position.y = y_offset
	add_child(inst)
	return inst
