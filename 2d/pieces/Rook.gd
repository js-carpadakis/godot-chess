extends "res://2d/pieces/Piece.gd"
## @brief Rook chess piece.
## @details Draws a square to represent the rook.
class_name Rook

## @brief Initializes the rook piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "rook"
    queue_redraw()

## @brief Draws the rook piece.
## @details Renders a square shape with an outline.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # rook: square
    draw_rect_with_outline(Rect2(Vector2(-12, -12), Vector2(24, 24)), col)
