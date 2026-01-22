extends Node3D
## @brief 3D Chessboard controller.
## @details Manages game logic, 3D board rendering, raycasting input, and piece animations.
## Coordinates: Vector2(x, y) where x = 0..7 (files a-h), y = 0..7 (ranks 1-8).

class_name Chessboard3D

signal piece_set(piece, pos)
signal piece_removed(piece, pos)
signal piece_moved(piece, from_pos, to_pos)
signal king_in_check(color)
signal checkmate(color)
signal stalemate(color)
signal turn_changed(new_turn)

@export var cols: int = 8
@export var rows: int = 8
@export var cell_size: float = 1.0
@export var demo: bool = true
@export var animation_speed: float = 3.0

var spaces: Array = []
var _selected: Vector2 = Vector2(-1, -1)
var current_turn: String = "white"
var last_move: Dictionary = {}
var has_moved: Dictionary = {
	"white_king": false, "white_rook_a": false, "white_rook_h": false,
	"black_king": false, "black_rook_a": false, "black_rook_h": false
}

# 3D-specific state
var _board_meshes: Array = []
var _highlight_mesh: MeshInstance3D = null
var _valid_move_indicators: Array = []
var _animating: bool = false

# Materials
var _light_square_mat: StandardMaterial3D
var _dark_square_mat: StandardMaterial3D
var _highlight_mat: StandardMaterial3D
var _valid_move_mat: StandardMaterial3D

# Node references
@onready var board_mesh_node: Node3D = $BoardMesh
@onready var pieces_node: Node3D = $Pieces

func _ready() -> void:
	_setup_materials()
	_build_board()
	init_grid()

	if demo:
		setup_standard()

	set_process_input(true)
	print("Board3D: starting turn ", current_turn)

# ─────────────────────────────────────────────────────────
# 3D Board Construction
# ─────────────────────────────────────────────────────────

func _setup_materials() -> void:
	_light_square_mat = StandardMaterial3D.new()
	_light_square_mat.albedo_color = Color(0.87, 0.82, 0.7)
	_light_square_mat.roughness = 0.6

	_dark_square_mat = StandardMaterial3D.new()
	_dark_square_mat.albedo_color = Color(0.45, 0.3, 0.18)
	_dark_square_mat.roughness = 0.6

	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(0.2, 0.9, 0.2, 0.5)
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.roughness = 0.8

	_valid_move_mat = StandardMaterial3D.new()
	_valid_move_mat.albedo_color = Color(0.2, 0.5, 0.9, 0.4)
	_valid_move_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_valid_move_mat.roughness = 0.8

func _build_board() -> void:
	# Create 64 square meshes on the X-Z plane
	for y in range(rows):
		var row_meshes: Array = []
		for x in range(cols):
			var mesh = BoxMesh.new()
			mesh.size = Vector3(cell_size * 0.98, 0.1, cell_size * 0.98)
			var inst = MeshInstance3D.new()
			inst.mesh = mesh
			inst.position = _board_pos(x, y)
			inst.position.y = -0.05

			var is_light = (x + y) % 2 == 0
			inst.material_override = _light_square_mat if is_light else _dark_square_mat

			# Add a static body for raycasting
			var static_body = StaticBody3D.new()
			var collision = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = Vector3(cell_size, 0.1, cell_size)
			collision.shape = shape
			static_body.add_child(collision)
			static_body.set_meta("board_x", x)
			static_body.set_meta("board_y", y)
			inst.add_child(static_body)

			board_mesh_node.add_child(inst)
			row_meshes.append(inst)
		_board_meshes.append(row_meshes)

	# Create selection highlight mesh (hidden initially)
	_highlight_mesh = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(cell_size, 0.12, cell_size)
	_highlight_mesh.mesh = h_mesh
	_highlight_mesh.material_override = _highlight_mat
	_highlight_mesh.visible = false
	board_mesh_node.add_child(_highlight_mesh)

## @brief Converts board coordinates to 3D world position.
func _board_pos(x: int, y: int) -> Vector3:
	return Vector3(x * cell_size, 0.0, y * cell_size)

## @brief Converts board coordinates to piece standing position (slightly above board).
func _piece_pos(x: int, y: int) -> Vector3:
	return Vector3(x * cell_size, 0.05, y * cell_size)

# ─────────────────────────────────────────────────────────
# Input Handling (3D Raycasting)
# ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell = _raycast_to_board(event.position)
		if cell == Vector2(-1, -1):
			return
		_handle_cell_click(cell)

func _raycast_to_board(screen_pos: Vector2) -> Vector2:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(-1, -1)
	var from = camera.project_ray_origin(screen_pos)
	var direction = camera.project_ray_normal(screen_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + direction * 100.0)
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return Vector2(-1, -1)

	var collider = result.get("collider")
	if collider and collider.has_meta("board_x") and collider.has_meta("board_y"):
		return Vector2(collider.get_meta("board_x"), collider.get_meta("board_y"))

	return Vector2(-1, -1)

func _handle_cell_click(cell: Vector2) -> void:
	if not _valid_coords(cell):
		return

	if not _valid_coords(_selected):
		# Nothing selected - try to select a piece
		var p = get_piece_at(cell)
		if p != null and _get_piece_color(p) == current_turn:
			_selected = cell
			_show_selection(cell)
			_show_valid_moves(cell, p)
			print("Board3D: selected ", coords_to_algebraic(cell))
		return

	# Attempt move from _selected to cell
	var from_alg = coords_to_algebraic(_selected)
	var to_alg = coords_to_algebraic(cell)
	var piece = get_piece_at(_selected)
	var moved = false

	if piece != null and _get_piece_color(piece) == current_turn:
		if is_legal_move(piece, _selected, cell):
			moved = move_piece(from_alg, to_alg)
		else:
			print("Board3D: illegal move ", from_alg, "->", to_alg)

	_clear_selection()

	if moved:
		current_turn = "black" if current_turn == "white" else "white"
		emit_signal("turn_changed", current_turn)
		print("Board3D: turn now ", current_turn)
		if is_in_check(current_turn):
			emit_signal("king_in_check", current_turn)
			print("Board3D: ", current_turn, " is in check")
			if is_checkmate(current_turn):
				emit_signal("checkmate", current_turn)
				print("Board3D: CHECKMATE - ", current_turn, " loses!")
		elif is_stalemate(current_turn):
			emit_signal("stalemate", current_turn)
			print("Board3D: STALEMATE!")

func _show_selection(cell: Vector2) -> void:
	_highlight_mesh.visible = true
	_highlight_mesh.position = _board_pos(int(cell.x), int(cell.y))
	_highlight_mesh.position.y = 0.01

func _show_valid_moves(from: Vector2, piece) -> void:
	_clear_valid_moves()
	for y in range(rows):
		for x in range(cols):
			var to = Vector2(x, y)
			if is_legal_move(piece, from, to):
				# Check it doesn't leave king in check
				var state = apply_temp_move(from, to)
				var leaves_check = is_in_check(_get_piece_color(piece))
				revert_temp_move(state)
				if not leaves_check:
					var indicator = MeshInstance3D.new()
					var m = CylinderMesh.new()
					m.top_radius = 0.15
					m.bottom_radius = 0.15
					m.height = 0.05
					indicator.mesh = m
					indicator.material_override = _valid_move_mat
					indicator.position = _board_pos(x, y)
					indicator.position.y = 0.06
					board_mesh_node.add_child(indicator)
					_valid_move_indicators.append(indicator)

func _clear_selection() -> void:
	_selected = Vector2(-1, -1)
	_highlight_mesh.visible = false
	_clear_valid_moves()

func _clear_valid_moves() -> void:
	for indicator in _valid_move_indicators:
		indicator.queue_free()
	_valid_move_indicators.clear()

# ─────────────────────────────────────────────────────────
# Animation
# ─────────────────────────────────────────────────────────

func _animate_piece_move(piece: Node3D, from_pos: Vector3, to_pos: Vector3, callback: Callable = Callable()) -> void:
	_animating = true
	var lift_pos = Vector3(from_pos.x, from_pos.y + 0.5, from_pos.z)
	var drop_pos = Vector3(to_pos.x, to_pos.y + 0.5, to_pos.z)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	# Lift
	tween.tween_property(piece, "position", lift_pos, 0.15 / animation_speed)
	# Move across
	tween.tween_property(piece, "position", drop_pos, 0.3 / animation_speed)
	# Drop
	tween.tween_property(piece, "position", to_pos, 0.15 / animation_speed)
	tween.tween_callback(func():
		_animating = false
		if callback.is_valid():
			callback.call()
	)

# ─────────────────────────────────────────────────────────
# Board State Management (ported from Board.gd)
# ─────────────────────────────────────────────────────────

func init_grid() -> void:
	spaces.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(null)
		spaces.append(row)

func clear_board() -> void:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p and p is Node:
				p.queue_free()
			spaces[y][x] = null

func setup_standard() -> void:
	clear_board()
	last_move = {}
	has_moved = {
		"white_king": false, "white_rook_a": false, "white_rook_h": false,
		"black_king": false, "black_rook_a": false, "black_rook_h": false
	}
	current_turn = "white"
	var order = ["rook","knight","bishop","queen","king","bishop","knight","rook"]
	for x in range(8):
		set_piece_at(coords_to_algebraic(Vector2(x, 0)), spawn_piece(order[x], "white"))
		set_piece_at(coords_to_algebraic(Vector2(x, 1)), spawn_piece("pawn", "white"))
	for x in range(8):
		set_piece_at(coords_to_algebraic(Vector2(x, 7)), spawn_piece(order[x], "black"))
		set_piece_at(coords_to_algebraic(Vector2(x, 6)), spawn_piece("pawn", "black"))

func _valid_coords(c: Vector2) -> bool:
	return int(c.x) >= 0 and int(c.x) < cols and int(c.y) >= 0 and int(c.y) < rows

func _pos_to_coords(pos) -> Vector2:
	if pos is Vector2:
		return Vector2(int(pos.x), int(pos.y))
	elif typeof(pos) == TYPE_STRING:
		return algebraic_to_coords(pos)
	return Vector2(-1, -1)

func get_piece_at(pos):
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return null
	return spaces[int(c.y)][int(c.x)]

func set_piece_at(pos, piece) -> void:
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return
	var x = int(c.x)
	var y = int(c.y)
	var existing = spaces[y][x]
	if existing:
		if existing is Node:
			existing.queue_free()
		spaces[y][x] = null

	if typeof(piece) == TYPE_DICTIONARY:
		var t = piece.get("type", "pawn")
		var col = piece.get("color", "white")
		piece = spawn_piece(t, col)
	elif typeof(piece) == TYPE_STRING:
		piece = spawn_piece(piece, "white")

	if piece is Node:
		pieces_node.add_child(piece)
		piece.position = _piece_pos(x, y)
		spaces[y][x] = piece
	else:
		spaces[y][x] = piece

	emit_signal("piece_set", piece, coords_to_algebraic(c))

func remove_piece_at(pos):
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return null
	var p = spaces[int(c.y)][int(c.x)]
	spaces[int(c.y)][int(c.x)] = null
	emit_signal("piece_removed", p, coords_to_algebraic(c))
	return p

func move_piece(from_pos, to_pos) -> bool:
	return move_piece_enforced(from_pos, to_pos, true)

func move_piece_enforced(from_pos, to_pos, enforce_check := true) -> bool:
	var f = _pos_to_coords(from_pos)
	var t = _pos_to_coords(to_pos)
	if not _valid_coords(f) or not _valid_coords(t):
		return false
	var fx = int(f.x)
	var fy = int(f.y)
	var tx = int(t.x)
	var ty = int(t.y)
	var piece = spaces[fy][fx]
	if piece == null:
		return false

	var p_type = piece.piece_type if piece is Node else piece.get("type", "")
	var p_color = _get_piece_color(piece)

	_update_has_moved(piece, f)

	# Detect en passant capture
	var en_passant_captured = null
	var en_passant_pos = Vector2(-1, -1)
	if p_type == "pawn":
		var dx = tx - fx
		if abs(dx) == 1 and spaces[ty][tx] == null:
			en_passant_pos = Vector2(tx, fy)
			en_passant_captured = spaces[fy][tx]

	var dest = spaces[ty][tx]

	# Perform move on board state
	spaces[ty][tx] = piece
	spaces[fy][fx] = null

	# Check enforcement
	if enforce_check:
		if is_in_check(p_color):
			spaces[fy][fx] = piece
			spaces[ty][tx] = dest
			if piece is Node:
				piece.position = _piece_pos(fx, fy)
			return false

	# Animate the piece movement
	if piece is Node:
		_animate_piece_move(piece, _piece_pos(fx, fy), _piece_pos(tx, ty))

	# Handle capture
	if dest != null:
		emit_signal("piece_removed", dest, coords_to_algebraic(t))
		if dest is Node:
			_animate_capture(dest)

	# Handle en passant capture
	if en_passant_captured != null:
		var epx = int(en_passant_pos.x)
		var epy = int(en_passant_pos.y)
		spaces[epy][epx] = null
		emit_signal("piece_removed", en_passant_captured, coords_to_algebraic(en_passant_pos))
		if en_passant_captured is Node:
			_animate_capture(en_passant_captured)
		print("Board3D: en passant capture at ", coords_to_algebraic(en_passant_pos))

	# Handle castling - move the rook
	if p_type == "king" and abs(tx - fx) == 2:
		var is_kingside = tx > fx
		var rook_from_x = 7 if is_kingside else 0
		var rook_to_x = 5 if is_kingside else 3
		var rook = spaces[fy][rook_from_x]
		spaces[fy][rook_to_x] = rook
		spaces[fy][rook_from_x] = null
		if rook is Node:
			_animate_piece_move(rook, _piece_pos(rook_from_x, fy), _piece_pos(rook_to_x, fy))
		emit_signal("piece_moved", rook, coords_to_algebraic(Vector2(rook_from_x, fy)), coords_to_algebraic(Vector2(rook_to_x, fy)))

	# Handle pawn promotion (auto-queen)
	if p_type == "pawn":
		var promotion_rank = 7 if p_color == "white" else 0
		if ty == promotion_rank:
			if piece is Node:
				piece.queue_free()
			var queen = spawn_piece("queen", p_color)
			pieces_node.add_child(queen)
			queen.position = _piece_pos(tx, ty)
			spaces[ty][tx] = queen
			piece = queen
			print("Board3D: pawn promoted to queen at ", coords_to_algebraic(t))

	# Record last move for en passant
	last_move = {
		"piece": piece,
		"from": Vector2(fx, fy),
		"to": Vector2(tx, ty),
		"was_double_pawn_push": p_type == "pawn" and abs(ty - fy) == 2
	}

	emit_signal("piece_moved", piece, coords_to_algebraic(f), coords_to_algebraic(t))
	print("Board3D: moved ", coords_to_algebraic(f), "->", coords_to_algebraic(t))
	return true

func _animate_capture(piece: Node3D) -> void:
	var tween = create_tween()
	tween.tween_property(piece, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(piece.queue_free)

# ─────────────────────────────────────────────────────────
# Piece Spawning
# ─────────────────────────────────────────────────────────

func spawn_piece(piece_type: String, color: String = "white") -> Node:
	var script_path := "res://pieces/" + piece_type.capitalize() + "3D.gd"
	var script = load(script_path)
	if script == null:
		push_error("Unknown piece script: %s" % script_path)
		return null
	var inst = script.new()
	if inst:
		inst.color = color
		return inst
	return null

# ─────────────────────────────────────────────────────────
# Coordinate Conversion
# ─────────────────────────────────────────────────────────

func algebraic_to_coords(s: String) -> Vector2:
	if s.length() < 2:
		return Vector2(-1, -1)
	var file = s.substr(0, 1).to_lower()
	var rank_str = s.substr(1, s.length() - 1)
	var rank = int(rank_str)
	var files = {"a":0, "b":1, "c":2, "d":3, "e":4, "f":5, "g":6, "h":7}
	var x = files.get(file, -1)
	var y = rank - 1
	return Vector2(x, y)

func coords_to_algebraic(c: Vector2) -> String:
	if not _valid_coords(c):
		return ""
	var files = ["a","b","c","d","e","f","g","h"]
	return files[int(c.x)] + str(int(c.y) + 1)

# ─────────────────────────────────────────────────────────
# Piece Color / Moved Tracking
# ─────────────────────────────────────────────────────────

func _get_piece_color(p) -> String:
	if p == null:
		return ""
	if p is Node:
		return p.color
	if typeof(p) == TYPE_DICTIONARY:
		return p.get("color", "")
	return ""

func _update_has_moved(piece, from_vec: Vector2) -> void:
	var p_type = piece.piece_type if piece is Node else piece.get("type", "")
	var p_color = _get_piece_color(piece)
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	if p_type == "king":
		has_moved[p_color + "_king"] = true
	elif p_type == "rook":
		if p_color == "white" and fy == 0:
			if fx == 0: has_moved["white_rook_a"] = true
			elif fx == 7: has_moved["white_rook_h"] = true
		elif p_color == "black" and fy == 7:
			if fx == 0: has_moved["black_rook_a"] = true
			elif fx == 7: has_moved["black_rook_h"] = true

# ─────────────────────────────────────────────────────────
# Move Validation (ported directly from Board.gd)
# ─────────────────────────────────────────────────────────

func path_clear(from_vec: Vector2, to_vec: Vector2) -> bool:
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)
	var ty = int(to_vec.y)
	var dx = tx - fx
	var dy = ty - fy
	var step_x = 0 if dx == 0 else (dx / abs(dx))
	var step_y = 0 if dy == 0 else (dy / abs(dy))
	var x = fx + int(step_x)
	var y = fy + int(step_y)
	while x != tx or y != ty:
		if spaces[y][x] != null:
			return false
		x += int(step_x)
		y += int(step_y)
	return true

func is_legal_move(piece, from_vec: Vector2, to_vec: Vector2) -> bool:
	if piece == null:
		return false
	if from_vec == to_vec:
		return false
	if not _valid_coords(from_vec) or not _valid_coords(to_vec):
		return false
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)
	var ty = int(to_vec.y)
	var dx = tx - fx
	var dy = ty - fy
	var adx = abs(dx)
	var ady = abs(dy)

	var p_type = ""
	var p_color = _get_piece_color(piece)
	if piece is Node:
		p_type = piece.piece_type
	elif typeof(piece) == TYPE_DICTIONARY:
		p_type = piece.get("type", "")

	var dest = get_piece_at(to_vec)
	var dest_color = _get_piece_color(dest)
	if dest_color != "" and dest_color == p_color:
		return false

	match p_type:
		"pawn":
			var direction = 1 if p_color == "white" else -1
			var start_rank = 1 if p_color == "white" else 6
			var en_passant_rank = 4 if p_color == "white" else 3
			if dx == 0:
				if dy == direction and dest == null:
					return true
				if dy == 2 * direction and fy == start_rank:
					var mid = Vector2(fx, fy + direction)
					if get_piece_at(mid) == null and dest == null:
						return true
				return false
			if abs(dx) == 1 and dy == direction:
				if dest != null and dest_color != p_color:
					return true
				if dest == null and fy == en_passant_rank:
					if is_en_passant_valid(from_vec, to_vec, p_color):
						return true
			return false
		"rook":
			if dx == 0 or dy == 0:
				return path_clear(from_vec, to_vec)
			return false
		"bishop":
			if adx == ady:
				return path_clear(from_vec, to_vec)
			return false
		"queen":
			if dx == 0 or dy == 0 or adx == ady:
				return path_clear(from_vec, to_vec)
			return false
		"knight":
			if (adx == 1 and ady == 2) or (adx == 2 and ady == 1):
				return true
			return false
		"king":
			if max(adx, ady) == 1:
				return true
			if ady == 0 and adx == 2:
				return is_castling_valid(from_vec, to_vec, p_color)
			return false
		_:
			return true

func is_en_passant_valid(from_vec: Vector2, to_vec: Vector2, p_color: String) -> bool:
	if last_move.is_empty() or not last_move.get("was_double_pawn_push", false):
		return false
	var captured_pos = Vector2(to_vec.x, from_vec.y)
	if last_move.get("to") != captured_pos:
		return false
	var enemy_pawn = get_piece_at(captured_pos)
	if enemy_pawn == null or _get_piece_color(enemy_pawn) == p_color:
		return false
	var pawn_type = enemy_pawn.piece_type if enemy_pawn is Node else ""
	return pawn_type == "pawn"

func is_castling_valid(from_vec: Vector2, to_vec: Vector2, p_color: String) -> bool:
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)
	var king_start_rank = 0 if p_color == "white" else 7
	if fy != king_start_rank or fx != 4:
		return false
	if has_moved.get(p_color + "_king", true):
		return false
	var is_kingside = tx == 6
	var rook_x = 7 if is_kingside else 0
	var rook_key = p_color + "_rook_" + ("h" if is_kingside else "a")
	if has_moved.get(rook_key, true):
		return false
	var rook = get_piece_at(Vector2(rook_x, fy))
	if rook == null:
		return false
	var rook_type = rook.piece_type if rook is Node else rook.get("type", "")
	if rook_type != "rook" or _get_piece_color(rook) != p_color:
		return false
	var start_x = min(fx, rook_x) + 1
	var end_x = max(fx, rook_x)
	for x in range(start_x, end_x):
		if get_piece_at(Vector2(x, fy)) != null:
			return false
	var enemy = "black" if p_color == "white" else "white"
	if is_square_attacked(from_vec, enemy):
		return false
	var direction = 1 if is_kingside else -1
	for i in range(1, 3):
		if is_square_attacked(Vector2(fx + direction * i, fy), enemy):
			return false
	return true

# ─────────────────────────────────────────────────────────
# Check / Checkmate / Stalemate
# ─────────────────────────────────────────────────────────

func find_king(color: String) -> Vector2:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p:
				var p_color = _get_piece_color(p)
				var p_type = p.piece_type if p is Node else (p.get("type", "") if typeof(p) == TYPE_DICTIONARY else "")
				if p_type == "king" and p_color == color:
					return Vector2(x, y)
	return Vector2(-1, -1)

func is_square_attacked(square: Vector2, by_color: String) -> bool:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p and _get_piece_color(p) == by_color:
				if is_legal_move(p, Vector2(x, y), square):
					return true
	return false

func is_in_check(color: String) -> bool:
	var king_pos = find_king(color)
	if not _valid_coords(king_pos):
		return false
	var enemy = "black" if color == "white" else "white"
	return is_square_attacked(king_pos, enemy)

func apply_temp_move(from_vec: Vector2, to_vec: Vector2) -> Dictionary:
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)
	var ty = int(to_vec.y)
	var piece = spaces[fy][fx]
	var dest = spaces[ty][tx]

	var en_passant_captured = null
	var en_passant_pos = Vector2(-1, -1)
	var p_type = piece.piece_type if piece is Node else piece.get("type", "")
	if p_type == "pawn" and dest == null and fx != tx:
		en_passant_pos = Vector2(tx, fy)
		en_passant_captured = spaces[fy][tx]
		if en_passant_captured != null:
			spaces[fy][tx] = null

	spaces[ty][tx] = piece
	spaces[fy][fx] = null
	return {
		"piece": piece, "dest": dest, "from": Vector2(fx, fy), "to": Vector2(tx, ty),
		"en_passant_captured": en_passant_captured, "en_passant_pos": en_passant_pos
	}

func revert_temp_move(state: Dictionary) -> void:
	var piece = state.get("piece")
	var dest = state.get("dest")
	var fromv = state.get("from")
	var tov = state.get("to")
	var en_passant_captured = state.get("en_passant_captured")
	var en_passant_pos = state.get("en_passant_pos", Vector2(-1, -1))
	spaces[int(fromv.y)][int(fromv.x)] = piece
	spaces[int(tov.y)][int(tov.x)] = dest
	if en_passant_captured != null and _valid_coords(en_passant_pos):
		spaces[int(en_passant_pos.y)][int(en_passant_pos.x)] = en_passant_captured

func has_any_legal_moves(color: String) -> bool:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p and _get_piece_color(p) == color:
				var from_vec = Vector2(x, y)
				for ty in range(rows):
					for tx in range(cols):
						var to_vec = Vector2(tx, ty)
						if is_legal_move(p, from_vec, to_vec):
							var state = apply_temp_move(from_vec, to_vec)
							var leaves_in_check = is_in_check(color)
							revert_temp_move(state)
							if not leaves_in_check:
								return true
	return false

func is_checkmate(color: String) -> bool:
	return is_in_check(color) and not has_any_legal_moves(color)

func is_stalemate(color: String) -> bool:
	return not is_in_check(color) and not has_any_legal_moves(color)
