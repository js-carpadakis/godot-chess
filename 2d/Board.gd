extends Node2D
## @brief Simple chessboard node keeping track of spaces and pieces.
## @details Coordinates: Vector2(x, y) where x = 0..7 corresponds to files a..h,
## and y = 0..7 corresponds to ranks 1..8 (y=0 is rank 1 / bottom of board).

class_name Chessboard

# Signals: emitted when pieces are set, removed or moved.
signal piece_set(piece, pos)
signal piece_removed(piece, pos)
signal piece_moved(piece, from_pos, to_pos)
signal king_in_check(color)
signal checkmate(color)
signal stalemate(color)

@export var cols: int = 8
@export var rows: int = 8
@export var cell_size: int = 64
@export var demo: bool = true

var spaces: Array = []
var _selected: Vector2 = Vector2(-1, -1)

@export var selection_color: Color = Color(0, 1, 0, 0.25)
var current_turn: String = "white"

# En passant tracking - stores info about the last move for en passant validation
var last_move: Dictionary = {}

# Castling tracking - tracks if king/rooks have moved from starting positions
var has_moved: Dictionary = {
	"white_king": false, "white_rook_a": false, "white_rook_h": false,
	"black_king": false, "black_rook_a": false, "black_rook_h": false
}

signal turn_changed(new_turn)

## @brief Initializes the chessboard when the node enters the scene tree.
## @details Sets up the grid, connects signals, and optionally sets up standard chess position.
func _ready() -> void:
	init_grid()
	# connect internal update to signals so display refreshes
	connect("piece_set", Callable(self, "_on_piece_changed"))
	connect("piece_removed", Callable(self, "_on_piece_changed"))
	connect("piece_moved", Callable(self, "_on_piece_changed"))

	if demo:
		setup_standard()

	set_process_input(true)
	print("Board: starting turn", current_turn)

## @brief Removes all pieces from the board.
## @details Frees any Node children used as pieces and clears the spaces array.
func clear_board() -> void:
	# remove any node children used as pieces and clear spaces
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p and p is Node:
				p.queue_free()
			spaces[y][x] = null

## @brief Sets up the standard chess starting position.
## @details Clears the board, resets special move state, and places all pieces in starting positions.
func setup_standard() -> void:
	clear_board()
	# Reset special move state
	last_move = {}
	has_moved = {
		"white_king": false, "white_rook_a": false, "white_rook_h": false,
		"black_king": false, "black_rook_a": false, "black_rook_h": false
	}
	current_turn = "white"
	# White pieces (rank 1 and 2)
	var order = ["rook","knight","bishop","queen","king","bishop","knight","rook"]
	for x in range(8):
		set_piece_at(coords_to_algebraic(Vector2(x, 0)), spawn_piece(order[x], "white"))
		set_piece_at(coords_to_algebraic(Vector2(x, 1)), spawn_piece("pawn", "white"))

	# Black pieces (rank 8 and 7)
	for x in range(8):
		set_piece_at(coords_to_algebraic(Vector2(x, 7)), spawn_piece(order[x], "black"))
		set_piece_at(coords_to_algebraic(Vector2(x, 6)), spawn_piece("pawn", "black"))

	queue_redraw()

## @brief Initializes the grid array with null values.
## @details Creates an 8x8 array of null values representing empty squares.
func init_grid() -> void:
	spaces.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(null)
		spaces.append(row)

## @brief Checks if coordinates are within board bounds.
## @param c The coordinates to validate as Vector2.
## @return True if coordinates are valid (0-7 for both x and y), false otherwise.
func _valid_coords(c: Vector2) -> bool:
	var x = int(c.x)
	var y = int(c.y)
	return x >= 0 and x < cols and y >= 0 and y < rows

## @brief Converts a position (Vector2 or algebraic string) to Vector2 coordinates.
## @param pos The position as either Vector2 or algebraic notation string (e.g., "e4").
## @return Vector2 coordinates, or Vector2(-1, -1) if invalid.
func _pos_to_coords(pos) -> Vector2:
	if pos is Vector2:
		return Vector2(int(pos.x), int(pos.y))
	elif typeof(pos) == TYPE_STRING:
		return algebraic_to_coords(pos)
	return Vector2(-1, -1)

## @brief Gets the piece at a given position.
## @param pos The position as Vector2 or algebraic notation string.
## @return The piece at the position, or null if empty or invalid.
func get_piece_at(pos):
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return null
	return spaces[int(c.y)][int(c.x)]

## @brief Places a piece at a given position.
## @param pos The position as Vector2 or algebraic notation string.
## @param piece The piece to place (Node, Dictionary, or String).
## @details Removes any existing piece, supports dictionary or string shorthand for pieces.
func set_piece_at(pos, piece) -> void:
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return
	var x = int(c.x)
	var y = int(c.y)
	# remove existing piece (if node)
	var existing = spaces[y][x]
	if existing:
		if existing is Node:
			existing.queue_free()
		spaces[y][x] = null

	# support dictionary or string shorthand for pieces
	if typeof(piece) == TYPE_DICTIONARY:
		var t = piece.get("type", "pawn")
		var col = piece.get("color", "white")
		piece = spawn_piece(t, col)
	elif typeof(piece) == TYPE_STRING:
		piece = spawn_piece(piece, "white")

	if piece is Node:
		add_child(piece)
		piece.position = Vector2(x * cell_size + cell_size * 0.5, y * cell_size + cell_size * 0.5)
		spaces[y][x] = piece
	else:
		spaces[y][x] = piece

	emit_signal("piece_set", piece, coords_to_algebraic(c))
	queue_redraw()

## @brief Removes a piece from a given position.
## @param pos The position as Vector2 or algebraic notation string.
## @return The removed piece, or null if position was empty or invalid.
func remove_piece_at(pos):
	var c = _pos_to_coords(pos)
	if not _valid_coords(c):
		return null
	var p = spaces[int(c.y)][int(c.x)]
	spaces[int(c.y)][int(c.x)] = null
	emit_signal("piece_removed", p, coords_to_algebraic(c))
	queue_redraw()
	return p

## @brief Moves a piece from one position to another with check enforcement.
## @param from_pos The starting position as Vector2 or algebraic notation.
## @param to_pos The destination position as Vector2 or algebraic notation.
## @return True if the move was successful, false otherwise.
func move_piece(from_pos, to_pos) -> bool:
	return move_piece_enforced(from_pos, to_pos, true)

## @brief Moves a piece with optional check enforcement.
## @param from_pos The starting position as Vector2 or algebraic notation.
## @param to_pos The destination position as Vector2 or algebraic notation.
## @param enforce_check If true, reverts moves that leave own king in check.
## @return True if the move was successful, false otherwise.
## @details Handles en passant, castling, and pawn promotion automatically.
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

	# Track if king/rook moves (for castling)
	_update_has_moved(piece, f)

	# Detect en passant capture
	var en_passant_captured = null
	var en_passant_pos = Vector2(-1, -1)
	if p_type == "pawn":
		var dx = tx - fx
		if abs(dx) == 1 and spaces[ty][tx] == null:
			# Diagonal pawn move to empty square = en passant
			en_passant_pos = Vector2(tx, fy)
			en_passant_captured = spaces[fy][tx]

	# prepare capture handling
	var dest = spaces[ty][tx]

	# perform move on board
	spaces[ty][tx] = piece
	spaces[fy][fx] = null
	if piece is Node:
		piece.position = Vector2(tx * cell_size + cell_size * 0.5, ty * cell_size + cell_size * 0.5)

	# if enforcing checks, ensure move doesn't leave own king in check
	if enforce_check:
		if is_in_check(p_color):
			# revert move
			spaces[fy][fx] = piece
			spaces[ty][tx] = dest
			if piece is Node:
				piece.position = Vector2(fx * cell_size + cell_size * 0.5, fy * cell_size + cell_size * 0.5)
			# if dest was a node, restore it (it's still referenced in dest)
			print("Board: move would leave king in check — reverted")
			return false

	# handle capture removal now (after check enforcement)
	if dest != null:
		emit_signal("piece_removed", dest, coords_to_algebraic(t))
		if dest is Node:
			dest.queue_free()

	# Handle en passant capture removal
	if en_passant_captured != null:
		var epx = int(en_passant_pos.x)
		var epy = int(en_passant_pos.y)
		spaces[epy][epx] = null
		emit_signal("piece_removed", en_passant_captured, coords_to_algebraic(en_passant_pos))
		if en_passant_captured is Node:
			en_passant_captured.queue_free()
		print("Board: en passant capture at ", coords_to_algebraic(en_passant_pos))

	# Handle castling - move the rook
	if p_type == "king" and abs(tx - fx) == 2:
		var is_kingside = tx > fx
		var rook_from_x = 7 if is_kingside else 0
		var rook_to_x = 5 if is_kingside else 3
		var rook_from = Vector2(rook_from_x, fy)
		var rook_to = Vector2(rook_to_x, fy)

		var rook = spaces[fy][rook_from_x]
		spaces[fy][rook_to_x] = rook
		spaces[fy][rook_from_x] = null
		if rook is Node:
			rook.position = Vector2(rook_to_x * cell_size + cell_size * 0.5, fy * cell_size + cell_size * 0.5)
		emit_signal("piece_moved", rook, coords_to_algebraic(rook_from), coords_to_algebraic(rook_to))
		print("Board: castling - rook moved ", coords_to_algebraic(rook_from), "->", coords_to_algebraic(rook_to))

	# Handle pawn promotion (auto-queen)
	if p_type == "pawn":
		var promotion_rank = 7 if p_color == "white" else 0
		if ty == promotion_rank:
			# Remove the pawn and spawn a queen
			if piece is Node:
				piece.queue_free()
			var queen = spawn_piece("queen", p_color)
			add_child(queen)
			queen.position = Vector2(tx * cell_size + cell_size * 0.5, ty * cell_size + cell_size * 0.5)
			spaces[ty][tx] = queen
			piece = queen  # Update reference for the move signal
			print("Board: pawn promoted to queen at ", coords_to_algebraic(t))

	# Record last move for en passant detection
	var was_double_push = p_type == "pawn" and abs(ty - fy) == 2
	last_move = {
		"piece": piece,
		"from": Vector2(fx, fy),
		"to": Vector2(tx, ty),
		"was_double_pawn_push": was_double_push
	}

	emit_signal("piece_moved", piece, coords_to_algebraic(f), coords_to_algebraic(t))
	queue_redraw()
	print("Board: moved", coords_to_algebraic(f), "->", coords_to_algebraic(t))
	_print_board_state()
	return true

## @brief Callback for piece change signals to trigger redraw.
func _on_piece_changed(_piece = null, _pos = null, _to_pos = null) -> void:
	queue_redraw()

## @brief Draws the chessboard and selection highlight.
## @details Renders alternating light/dark squares and highlights the selected square.
func _draw() -> void:
	print("Board: _draw called")
	for y in range(rows):
		for x in range(cols):
			var pos = Vector2(x, y) * cell_size
			var rect = Rect2(pos, Vector2(cell_size, cell_size))
			var light = (x + y) % 2 == 0
			draw_rect(rect, Color(0.95, 0.95, 0.95) if light else Color(0.2, 0.2, 0.2))
			# pieces are nodes and draw themselves

	if _valid_coords(_selected):
		var srect = Rect2(_selected * cell_size, Vector2(cell_size, cell_size))
		draw_rect(srect, selection_color)

## @brief Prints the current board state to the console for debugging.
## @details Lists all pieces and their positions in algebraic notation.
func _print_board_state() -> void:
	var items := []
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p:
				items.append(coords_to_algebraic(Vector2(x, y)) + ":" + str(p))
	print("Board state:", items)

## @brief Creates a new piece instance of the specified type and color.
## @param piece_type The type of piece (e.g., "king", "queen", "pawn").
## @param color The color of the piece ("white" or "black").
## @return A new piece Node, or null if the piece script could not be loaded.
func spawn_piece(piece_type: String, color: String = "white") -> Node:
	var script_path := "res://2d/pieces/" + piece_type.capitalize() + ".gd"
	var script = load(script_path)
	if script == null:
		push_error("Unknown piece script: %s" % script_path)
		return null
	var inst = script.new()
	if inst:
		inst.color = color
		return inst
	return null

## @brief Handles mouse input for piece selection and movement.
## @param event The input event to process.
## @details Processes left mouse clicks for selecting pieces and making moves.
func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Board: received click at", event.position)
		var local = to_local(event.position)
		var cell = Vector2(floor(local.x / cell_size), floor(local.y / cell_size))
		print("Board: local ", local, " cell", cell)
		if not _valid_coords(cell):
			print("Board: click outside board")
			return
		# If nothing selected, pick a piece
		if not _valid_coords(_selected):
			var p = get_piece_at(cell)
			print("Board: piece at cell ", p)
			if p != null:
				var p_color = p.color
				# allow selection only for current turn
				if p_color == current_turn:
					_selected = cell
					print("Board: selected ", coords_to_algebraic(cell))
					queue_redraw()
				else:
					print("Board: cannot select piece of color ", p_color, "- current turn is ", current_turn)
		else:
			# attempt move
			var from_alg = coords_to_algebraic(_selected)
			var to_alg = coords_to_algebraic(cell)
			print("Board: attempting move ", from_alg, "->", to_alg)
			var moved = false
			var piece = get_piece_at(_selected)
			# check turn and legality
			var piece_color = piece.color if piece is Node else (piece.get("color", null) if typeof(piece) == TYPE_DICTIONARY else null)
			if piece_color != current_turn:
				print("Board: cannot move piece of color ", piece_color, "on", current_turn, "turn")
			else:
				if is_legal_move(piece, _selected, cell):
					moved = move_piece(from_alg, to_alg)
				else:
					print("Board: illegal move attempted ", from_alg, "->", to_alg)
			print("Board: move result", moved)
			_selected = Vector2(-1, -1)
			if moved:
				# switch turn
				current_turn = "black" if current_turn == "white" else "white"
				emit_signal("turn_changed", current_turn)
				print("Board: turn now ", current_turn)
				# detect check / checkmate / stalemate for the side to move
				if is_in_check(current_turn):
					emit_signal("king_in_check", current_turn)
					print("Board: ", current_turn, " is in check")
					if is_checkmate(current_turn):
						emit_signal("checkmate", current_turn)
						print("Board: ", current_turn, " is checkmated")
				else:
					if is_stalemate(current_turn):
						emit_signal("stalemate", current_turn)
						print("Board: ", current_turn, " is stalemated")
			queue_redraw()

## @brief Converts algebraic notation to board coordinates.
## @param s The algebraic notation string (e.g., "e4", "a1").
## @return Vector2 coordinates where x=file (0-7) and y=rank (0-7), or Vector2(-1, -1) if invalid.
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

## @brief Converts board coordinates to algebraic notation.
## @param c The board coordinates as Vector2.
## @return Algebraic notation string (e.g., "e4"), or empty string if invalid.
func coords_to_algebraic(c: Vector2) -> String:
	if not _valid_coords(c):
		return ""
	var files = ["a","b","c","d","e","f","g","h"]
	var file = files[int(c.x)]
	var rank = str(int(c.y) + 1)
	return file + rank

## @brief Gets the color of a piece.
## @param p The piece to check (Node or Dictionary).
## @return The color string ("white" or "black"), or error string if invalid.
func _get_piece_color(p) -> String:
	if p == null:
		return "no piece here"
	if p is Node:
		return p.color
	if typeof(p) == TYPE_DICTIONARY:
		return p.get("color", null)
	return "undefined"

## @brief Updates the has_moved tracking for castling rights.
## @param piece The piece that moved.
## @param from_vec The starting position of the piece.
## @details Marks kings and rooks as having moved from their starting positions.
func _update_has_moved(piece, from_vec: Vector2) -> void:
	var p_type = piece.piece_type if piece is Node else piece.get("type", "")
	var p_color = _get_piece_color(piece)
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)

	if p_type == "king":
		has_moved[p_color + "_king"] = true
	elif p_type == "rook":
		if p_color == "white" and fy == 0:
			if fx == 0:
				has_moved["white_rook_a"] = true
			elif fx == 7:
				has_moved["white_rook_h"] = true
		elif p_color == "black" and fy == 7:
			if fx == 0:
				has_moved["black_rook_a"] = true
			elif fx == 7:
				has_moved["black_rook_h"] = true

## @brief Checks if the path between two squares is clear.
## @param from_vec The starting position.
## @param to_vec The ending position.
## @return True if no pieces block the straight or diagonal path (excludes endpoints).
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

## @brief Checks if a move is legal according to chess rules.
## @param piece The piece to move.
## @param from_vec The starting position.
## @param to_vec The destination position.
## @return True if the move is legal for the piece type, false otherwise.
## @details Validates moves for all piece types including special moves (castling, en passant).
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
	# cannot capture own piece
	if dest_color != null and dest_color == p_color:
		return false

	match p_type:
		"pawn":
			var direction = 1 if p_color == "white" else -1
			var start_rank = 1 if p_color == "white" else 6
			var en_passant_rank = 4 if p_color == "white" else 3
			# forward move
			if dx == 0:
				if dy == direction and dest == null:
					return true
				if dy == 2 * direction and fy == start_rank:
					# ensure path and destination empty
					var mid = Vector2(fx, fy + direction)
					if get_piece_at(mid) == null and dest == null:
						return true
				return false
			# diagonal captures (normal or en passant)
			if abs(dx) == 1 and dy == direction:
				# normal capture
				if dest != null and dest_color != p_color:
					return true
				# en passant capture
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
			# Normal king move (one square any direction)
			if max(adx, ady) == 1:
				return true
			# Castling: king moves 2 squares horizontally
			if ady == 0 and adx == 2:
				return is_castling_valid(from_vec, to_vec, p_color)
			return false
		_:
			# unknown piece type: allow move
			return true

## @brief Validates an en passant capture.
## @param from_vec The pawn's starting position.
## @param to_vec The pawn's destination position.
## @param p_color The color of the capturing pawn.
## @return True if the en passant capture is valid, false otherwise.
func is_en_passant_valid(from_vec: Vector2, to_vec: Vector2, p_color: String) -> bool:
	if last_move.is_empty() or not last_move.get("was_double_pawn_push", false):
		return false
	# The captured pawn is on the same rank as our pawn, same file as destination
	var captured_pos = Vector2(to_vec.x, from_vec.y)
	if last_move.get("to") != captured_pos:
		return false
	var enemy_pawn = get_piece_at(captured_pos)
	if enemy_pawn == null or _get_piece_color(enemy_pawn) == p_color:
		return false
	var pawn_type = enemy_pawn.piece_type if enemy_pawn is Node else ""
	return pawn_type == "pawn"

## @brief Validates a castling move.
## @param from_vec The king's starting position.
## @param to_vec The king's destination position.
## @param p_color The color of the king.
## @return True if castling is valid, false otherwise.
## @details Checks that king and rook haven't moved, path is clear, and king doesn't castle through check.
func is_castling_valid(from_vec: Vector2, to_vec: Vector2, p_color: String) -> bool:
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)

	# King must be on starting square (e1 for white, e8 for black)
	var king_start_rank = 0 if p_color == "white" else 7
	if fy != king_start_rank or fx != 4:
		return false

	# Check if king has moved
	var king_key = p_color + "_king"
	if has_moved.get(king_key, true):
		return false

	# Determine if kingside (tx=6) or queenside (tx=2) castling
	var is_kingside = tx == 6
	var rook_x = 7 if is_kingside else 0
	var rook_key = p_color + "_rook_" + ("h" if is_kingside else "a")

	# Check if rook has moved
	if has_moved.get(rook_key, true):
		return false

	# Check rook exists at starting position
	var rook = get_piece_at(Vector2(rook_x, fy))
	if rook == null:
		return false
	var rook_type = rook.piece_type if rook is Node else rook.get("type", "")
	if rook_type != "rook" or _get_piece_color(rook) != p_color:
		return false

	# Check path is clear between king and rook
	var start_x = min(fx, rook_x) + 1
	var end_x = max(fx, rook_x)
	for x in range(start_x, end_x):
		if get_piece_at(Vector2(x, fy)) != null:
			return false

	# King cannot castle out of check, through check, or into check
	var enemy = "black" if p_color == "white" else "white"

	# Check current position (cannot castle out of check)
	if is_square_attacked(from_vec, enemy):
		return false

	# Check squares king passes through and lands on
	var direction = 1 if is_kingside else -1
	for i in range(1, 3):
		var check_square = Vector2(fx + direction * i, fy)
		if is_square_attacked(check_square, enemy):
			return false

	return true

## @brief Finds the position of a king on the board.
## @param color The color of the king to find ("white" or "black").
## @return Vector2 position of the king, or Vector2(-1, -1) if not found.
func find_king(color: String) -> Vector2:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p:
				var p_color = _get_piece_color(p)
				var p_type = p.piece_type if p is Node else (p.get("type", null) if typeof(p) == TYPE_DICTIONARY else null)
				if p_type == "king" and p_color == color:
					return Vector2(x, y)
	return Vector2(-1, -1)

## @brief Checks if a square is attacked by any piece of a given color.
## @param square The square to check.
## @param by_color The color of the attacking pieces.
## @return True if the square is attacked, false otherwise.
func is_square_attacked(square: Vector2, by_color: String) -> bool:
	for y in range(rows):
		for x in range(cols):
			var p = spaces[y][x]
			if p and _get_piece_color(p) == by_color:
				var from_vec = Vector2(x, y)
				if is_legal_move(p, from_vec, square):
					return true
	return false

## @brief Checks if a king is in check.
## @param color The color of the king to check.
## @return True if the king is in check, false otherwise.
func is_in_check(color: String) -> bool:
	var king_pos = find_king(color)
	if not _valid_coords(king_pos):
		return false
	var enemy = "black" if color == "white" else "white"
	return is_square_attacked(king_pos, enemy)

## @brief Temporarily applies a move on the board for validation.
## @param from_vec The starting position.
## @param to_vec The destination position.
## @return A Dictionary containing the state needed to revert the move.
## @details Used for checking if a move would leave the king in check.
func apply_temp_move(from_vec: Vector2, to_vec: Vector2) -> Dictionary:
	var fx = int(from_vec.x)
	var fy = int(from_vec.y)
	var tx = int(to_vec.x)
	var ty = int(to_vec.y)
	var piece = spaces[fy][fx]
	var dest = spaces[ty][tx]

	# Detect en passant for temp move
	var en_passant_captured = null
	var en_passant_pos = Vector2(-1, -1)
	var p_type = piece.piece_type if piece is Node else piece.get("type", "")
	if p_type == "pawn" and dest == null and fx != tx:
		# Diagonal pawn move to empty square = en passant
		en_passant_pos = Vector2(tx, fy)
		en_passant_captured = spaces[fy][tx]
		if en_passant_captured != null:
			spaces[fy][tx] = null  # Remove captured pawn temporarily

	# perform the temporary move
	spaces[ty][tx] = piece
	spaces[fy][fx] = null
	var old_pos = null
	if piece is Node:
		old_pos = piece.position
		piece.position = Vector2(tx * cell_size + cell_size * 0.5, ty * cell_size + cell_size * 0.5)
	return {
		"piece": piece, "dest": dest, "from": Vector2(fx, fy), "to": Vector2(tx, ty), "old_pos": old_pos,
		"en_passant_captured": en_passant_captured, "en_passant_pos": en_passant_pos
	}

## @brief Reverts a temporary move applied by apply_temp_move.
## @param state The state Dictionary returned by apply_temp_move.
func revert_temp_move(state: Dictionary) -> void:
	var piece = state.get("piece")
	var dest = state.get("dest")
	var fromv = state.get("from")
	var tov = state.get("to")
	var old_pos = state.get("old_pos")
	var en_passant_captured = state.get("en_passant_captured")
	var en_passant_pos = state.get("en_passant_pos", Vector2(-1, -1))
	var fx = int(fromv.x)
	var fy = int(fromv.y)
	var tx = int(tov.x)
	var ty = int(tov.y)
	spaces[fy][fx] = piece
	spaces[ty][tx] = dest
	if piece is Node and old_pos != null:
		piece.position = old_pos
	# Restore en passant captured piece
	if en_passant_captured != null and _valid_coords(en_passant_pos):
		spaces[int(en_passant_pos.y)][int(en_passant_pos.x)] = en_passant_captured

## @brief Checks if a player has any legal moves available.
## @param color The color to check for legal moves.
## @return True if at least one legal move exists, false otherwise.
## @details Tests all possible moves and filters out those that would leave the king in check.
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

## @brief Checks if a player is in checkmate.
## @param color The color to check for checkmate.
## @return True if the player is checkmated (in check with no legal moves).
func is_checkmate(color: String) -> bool:
	return is_in_check(color) and not has_any_legal_moves(color)

## @brief Checks if a player is in stalemate.
## @param color The color to check for stalemate.
## @return True if the player is stalemated (not in check but no legal moves).
func is_stalemate(color: String) -> bool:
	return not is_in_check(color) and not has_any_legal_moves(color)
