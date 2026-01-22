extends "res://pieces/Piece.gd"
## @brief Queen chess piece.
## @details Draws a circle with crown dots to represent the queen.
class_name Queen

## @brief Initializes the queen piece type and triggers a redraw.
func _ready() -> void:
    piece_type = "queen"
    queue_redraw()

## @brief Draws the queen piece.
## @details Renders a circle with five small dots arranged in a crown pattern.
func _draw() -> void:
    var col = Color(1,1,1) if color == "white" else Color(0,0,0)
    var crown_color = Color(0,0,0) if color == "white" else Color(1,1,1)
    # queen: circle with small crown dots
    # draw outline then fill for the base circle
    draw_circle_with_outline(Vector2.ZERO, 16, col)
    for i in range(5):
        var angle = PI * 2 * i / 5
        var p = Vector2(cos(angle), sin(angle)) * 10
        # draw a small outlined dot: outer (outline) then inner (fill)
        draw_circle(p, 2, crown_color)
