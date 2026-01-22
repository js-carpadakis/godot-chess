extends "res://2d/pieces/Piece.gd"
## @brief Knight chess piece.
## @details Draws a triangle to represent the knight.
class_name Knight

## @brief Initializes the knight piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "knight"
    queue_redraw()

## @brief Draws the knight piece.
## @details Renders a triangle shape with an outline.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # knight: triangle
    var points = PackedVector2Array([Vector2(-12,10), Vector2(0,-14), Vector2(12,10)])
    draw_poly_with_outline(points, col)
