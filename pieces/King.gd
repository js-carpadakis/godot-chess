extends "res://pieces/Piece.gd"
## @brief King chess piece.
## @details Draws a circle with a cross symbol to represent the king.
class_name King

## @brief Initializes the king piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "king"
    queue_redraw()

## @brief Draws the king piece.
## @details Renders a circle with a cross pattern in the center.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    var cross_color = Color(0,0,0) if color == "white" else Color(1,1,1)
    # king: circle with a cross
    draw_circle_with_outline(Vector2.ZERO, 16, col)
    draw_line(Vector2(-6,0), Vector2(6,0), cross_color, 2)
    draw_line(Vector2(0,-6), Vector2(0,6), cross_color, 2)
