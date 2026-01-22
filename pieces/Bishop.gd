extends "res://pieces/Piece.gd"
class_name Bishop

func _ready() -> void:
    piece_type = "bishop"
    queue_redraw()

func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # bishop: diamond
    var points = PackedVector2Array([Vector2(0,-14), Vector2(12,0), Vector2(0,14), Vector2(-12,0)])
    draw_poly_with_outline(points, col)
