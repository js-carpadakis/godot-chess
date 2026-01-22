extends "res://pieces/Piece.gd"
class_name Knight

func _ready() -> void:
    piece_type = "knight"
    queue_redraw()

func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # knight: triangle
    var points = PackedVector2Array([Vector2(-12,10), Vector2(0,-14), Vector2(12,10)])
    draw_poly_with_outline(points, col)
