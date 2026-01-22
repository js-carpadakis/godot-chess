extends Node2D
class_name Piece

@export var color: String = "white"
@export var piece_type: String = ""
@export var outline_color: Color = Color(0,0,0)
@export var outline_thickness: float = 3.0

func _ready() -> void:
    queue_redraw()

func _draw() -> void:
    var _col = Color(1,1,1) if color == "white" else Color(0,0,0)
    # placeholder no-op
    pass

func draw_at_center(_radius: float) -> void:
    # helper to draw centered at origin
    queue_redraw()

func draw_circle_with_outline(center: Vector2, radius: float, fill_color: Color) -> void:
    draw_circle(center, radius + outline_thickness, outline_color)
    draw_circle(center, radius, fill_color)

func draw_rect_with_outline(rect: Rect2, fill_color: Color) -> void:
    # draw outer rect as outline then inner rect as fill
    draw_rect(rect, outline_color)
    var inner = Rect2(rect.position + Vector2(outline_thickness, outline_thickness), rect.size - Vector2(outline_thickness * 2, outline_thickness * 2))
    draw_rect(inner, fill_color)

func draw_poly_with_outline(points: PackedVector2Array, fill_color: Color) -> void:
    draw_colored_polygon(points, fill_color)
    var pts = PackedVector2Array(points)
    pts.append(points[0])
    draw_polyline(pts, outline_color, outline_thickness)
