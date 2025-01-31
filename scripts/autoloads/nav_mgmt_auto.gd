# nav_manager.gd (autoload)
extends Node

var astar := AStar2D.new()
var point_positions := {}  # Dictionary mapping grid positions to point IDs
var dirty := false  # Flag to track if navigation needs updating
var path_cache := {}
const CACHE_SIZE_LIMIT := 1000  # Prevent unlimited growth

func _ready() -> void:
	GameMgmtAuto.block_mined.connect(_on_block_mined)
	GameMgmtAuto.grid_updated.connect(_on_grid_updated)
	_initialize_navigation()

func _initialize_navigation() -> void:
	astar.clear()
	point_positions.clear()
	path_cache.clear()
	
	# Add points for each empty cell
	var point_id := 0
	for y in GameMgmtAuto.GRID_HEIGHT:
		for x in GameMgmtAuto.GRID_WIDTH:
			var cell = GameMgmtAuto.grid[y][x]
			if not cell.solid:
				var pos = Vector2i(x, y)
				astar.add_point(point_id, Vector2(x, y))
				point_positions[pos] = point_id
				point_id += 1
	
	# Connect neighboring points
	for pos in point_positions:
		var current_id = point_positions[pos]
		var neighbors = [
			pos + Vector2i(1, 0),
			pos + Vector2i(-1, 0),
			pos + Vector2i(0, 1),
			pos + Vector2i(0, -1)
		]
		
		for neighbor_pos in neighbors:
			var neighbor_id = point_positions.get(neighbor_pos)
			if neighbor_id != null and not astar.are_points_connected(current_id, neighbor_id):
				astar.connect_points(current_id, neighbor_id)

func _on_block_mined(grid_pos: Vector2i) -> void:
	# Clear cache since paths may have changed
	path_cache.clear()
	
	# Add new point for the mined block
	var point_id = astar.get_available_point_id()
	astar.add_point(point_id, Vector2(grid_pos.x, grid_pos.y))
	point_positions[grid_pos] = point_id
	
	# Connect to neighboring walkable cells
	var neighbors = [
		grid_pos + Vector2i(1, 0),
		grid_pos + Vector2i(-1, 0),
		grid_pos + Vector2i(0, 1),
		grid_pos + Vector2i(0, -1)
	]
	
	for neighbor_pos in neighbors:
		var neighbor_id = point_positions.get(neighbor_pos)
		if neighbor_id != null:
			astar.connect_points(point_id, neighbor_id)

func _on_grid_updated() -> void:
	if not dirty:
		return
	_initialize_navigation()
	dirty = false

func get_navigation_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	# Round positions to reduce cache variants
	var from_rounded := Vector2(round(from_pos.x), round(from_pos.y))
	var to_rounded := Vector2(round(to_pos.x), round(to_pos.y))
	
	# Create cache key
	var cache_key = str(from_rounded) + "|" + str(to_rounded)
	
	# Check cache
	if path_cache.has(cache_key):
		return path_cache[cache_key]
	
	# Convert world positions to grid positions
	var from_grid = GameMgmtAuto.world_to_grid(from_pos)
	var to_grid = GameMgmtAuto.world_to_grid(to_pos)
	
	# Get the closest walkable points
	var from_id = _get_closest_point(from_grid)
	var to_id = _get_closest_point(to_grid)
	
	if from_id == -1 or to_id == -1:
		return []
	
	# Get path as grid positions
	var path_points = astar.get_point_path(from_id, to_id)
	
	# Convert to world positions
	var world_path: Array[Vector2] = []
	for point in path_points:
		world_path.append(GameMgmtAuto.grid_to_world(Vector2i(point.x, point.y)))
	
	# Cache the result
	_add_to_cache(cache_key, world_path)
	
	return world_path

func _get_closest_point(grid_pos: Vector2i) -> int:
	# First check if the position itself is walkable
	var point_id = point_positions.get(grid_pos)
	if point_id != null:
		return point_id
	
	# If not, look for the closest walkable position
	var closest_point := -1
	var closest_distance := INF
	
	for pos in point_positions:
		var distance = grid_pos.distance_squared_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point_positions[pos]
	
	return closest_point

func _add_to_cache(key: String, path: Array[Vector2]) -> void:
	# Clear some old entries if cache is too big
	if path_cache.size() >= CACHE_SIZE_LIMIT:
		var keys_to_remove = path_cache.keys().slice(0, path_cache.size() / 2)
		for k in keys_to_remove:
			path_cache.erase(k)
	
	path_cache[key] = path

func is_position_walkable(grid_pos: Vector2i) -> bool:
	return point_positions.has(grid_pos)
