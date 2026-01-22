extends "res://pieces/Piece.gd"
class_name Pawn

func _ready() -> void:
    piece_type = "pawn"
    queue_redraw()

func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # simple pawn: circle
    draw_circle_with_outline(Vector2.ZERO, 14, col)
