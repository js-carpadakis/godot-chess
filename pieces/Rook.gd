extends "res://pieces/Piece.gd"
class_name Rook

func _ready() -> void:
    piece_type = "rook"
    queue_redraw()

func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # rook: square
    draw_rect_with_outline(Rect2(Vector2(-12, -12), Vector2(24, 24)), col)
