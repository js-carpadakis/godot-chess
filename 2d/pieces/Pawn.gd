extends "res://2d/pieces/Piece.gd"
## @brief Pawn chess piece.
## @details Draws a simple circle to represent the pawn.
class_name Pawn

## @brief Initializes the pawn piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "pawn"
    queue_redraw()

## @brief Draws the pawn piece.
## @details Renders a simple circle with an outline.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # simple pawn: circle
    draw_circle_with_outline(Vector2.ZERO, 14, col)
