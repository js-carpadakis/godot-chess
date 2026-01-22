extends Node2D
## @brief Base class for all chess pieces.
## @details Provides common properties and drawing utilities for chess pieces.
class_name Piece

@export var color: String = "white"
@export var piece_type: String = ""
@export var outline_color: Color = Color(0,0,0)
@export var outline_thickness: float = 3.0

## @brief Initializes the piece and triggers a redraw.
func _ready() -> void:
    queue_redraw()

## @brief Draws the piece (placeholder in base class).
## @details Override this method in derived classes to draw specific piece shapes.
func _draw() -> void:
    var _col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # placeholder no-op
    pass

## @brief Helper to draw centered at origin.
## @param _radius The radius to use for drawing (unused in base implementation).
func draw_at_center(_radius: float) -> void:
    # helper to draw centered at origin
    queue_redraw()

## @brief Draws a circle with an outline.
## @param center The center position of the circle.
## @param radius The radius of the inner circle.
## @param fill_color The fill color of the circle.
func draw_circle_with_outline(center: Vector2, radius: float, fill_color: Color) -> void:
    draw_circle(center, radius + outline_thickness, outline_color)
    draw_circle(center, radius, fill_color)

## @brief Draws a rectangle with an outline.
## @param rect The rectangle to draw.
## @param fill_color The fill color of the rectangle.
func draw_rect_with_outline(rect: Rect2, fill_color: Color) -> void:
    # draw outer rect as outline then inner rect as fill
    draw_rect(rect, outline_color)
    var inner = Rect2(rect.position + Vector2(outline_thickness, outline_thickness), rect.size - Vector2(outline_thickness * 2, outline_thickness * 2))
    draw_rect(inner, fill_color)

## @brief Draws a polygon with an outline.
## @param points The vertices of the polygon.
## @param fill_color The fill color of the polygon.
func draw_poly_with_outline(points: PackedVector2Array, fill_color: Color) -> void:
    draw_colored_polygon(points, fill_color)
    var pts = PackedVector2Array(points)
    pts.append(points[0])
    draw_polyline(pts, outline_color, outline_thickness)
