extends "res://pieces/Piece.gd"
class_name King

func _ready() -> void:
    piece_type = "king"
    queue_redraw()
    
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    var cross_color = Color(0,0,0) if color == "white" else Color(1,1,1)
    # king: circle with a cross
    draw_circle_with_outline(Vector2.ZERO, 16, col)
    draw_line(Vector2(-6,0), Vector2(6,0), cross_color, 2)
    draw_line(Vector2(0,-6), Vector2(0,6), cross_color, 2)