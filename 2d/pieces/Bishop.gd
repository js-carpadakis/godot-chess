extends "res://2d/pieces/Piece.gd"
## @brief Bishop chess piece.
## @details Draws a diamond shape to represent the bishop.
class_name Bishop

## @brief Initializes the bishop piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "bishop"
    queue_redraw()

## @brief Draws the bishop piece.
## @details Renders a diamond (rotated square) shape with an outline.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # bishop: diamond
    var points = PackedVector2Array([Vector2(0,-14), Vector2(12,0), Vector2(0,14), Vector2(-12,0)])
    draw_poly_with_outline(points, col)
