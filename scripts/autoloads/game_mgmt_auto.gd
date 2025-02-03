extends Node

signal grid_updated
signal chunks_updated
signal block_mined(position: Vector2i)
signal selection_changed

const CELL_SIZE = 32
const GRID_WIDTH = 144
const GRID_HEIGHT = 144
const STARTING_AREA_SIZE = 8
const CHUNK_SIZE = 5  # Fixed at 5x5 grid
const VISIBILITY_RANGE = 2

var grid: Array = []
var chunks: Array = []
var selected_chunks: Array[TerrainChunk] = []
var chunk_visibility_levels: Dictionary = {}

#optimize I guess....
var mining_update_timer := 0.0
const MINING_UPDATE_INTERVAL := 0.1  # Update every 100ms instead of every frame

func _ready():
	print("Game Manager initialized")
	generate_terrain()

func _process(delta: float) -> void:
	if mining_update_timer > 0:
		mining_update_timer -= delta

func generate_terrain():
	print("Generating terrain grid...")
	
	# Initialize grid
	grid.clear()
	for y in GRID_HEIGHT:
		var row = []
		for x in GRID_WIDTH:
			var cell = TerrainCell.new()
			
			# Calculate distance from center
			var center_x = GRID_WIDTH / 2
			var center_y = GRID_HEIGHT / 2
			var distance = Vector2(x - center_x, y - center_y).length()
			
			# Determine cell type based on RNG
			var cell_type = TerrainCell.CellType.GROUND  # Default is now GROUND instead of DIRT
			if distance >= STARTING_AREA_SIZE:
				var rng = randf()
				if rng < 0.03:
					cell_type = TerrainCell.CellType.WATERSTONE  # Rarest
				elif rng < 0.08:
					cell_type = TerrainCell.CellType.DIAMOND
				elif rng < 0.15:
					cell_type = TerrainCell.CellType.BLOOD_ORE
				elif rng < 0.25:
					cell_type = TerrainCell.CellType.IRON_ORE
				elif rng < 0.6:
					cell_type = TerrainCell.CellType.STONE
			
			cell.initialize_cell(cell_type, Vector2i(x, y))
			
			if distance < STARTING_AREA_SIZE:
				cell.solid = false
				cell.visible = true
			else:
				cell.solid = true
				cell.visible = false
			
			row.append(cell)
		grid.append(row)
	
	# Initialize chunks
	chunks.clear()
	for chunk_y in (GRID_HEIGHT / CHUNK_SIZE):
		var chunk_row = []
		for chunk_x in (GRID_WIDTH / CHUNK_SIZE):
			var chunk = TerrainChunk.new(Vector2i(chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE))
			
			# Add cells to chunk
			for local_y in CHUNK_SIZE:
				for local_x in CHUNK_SIZE:
					var grid_x = chunk_x * CHUNK_SIZE + local_x
					var grid_y = chunk_y * CHUNK_SIZE + local_y
					if grid_x < GRID_WIDTH and grid_y < GRID_HEIGHT:
						chunk.add_cell(grid[grid_y][grid_x], local_x, local_y)
			
			chunk_row.append(chunk)
		chunks.append(chunk_row)
	
	update_visibility()
	update_minable_states()
	grid_updated.emit()

func update_visibility():
	print('im running globally!')
	# First pass: Reset visibility
	chunk_visibility_levels.clear()
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if grid[y][x].solid:
				grid[y][x].visible = false
	
	# Second pass: Check for visibility from empty cells
	var checked = {}
	var to_check = []
	
	# Add all empty cells to the initial check queue
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if !grid[y][x].solid:
				to_check.append(Vector2i(x, y))
				checked[Vector2i(x, y)] = true
	
	while to_check.size() > 0:
		var pos = to_check.pop_front()
		var current_chunk = get_chunk_at_grid_pos(pos)
		if current_chunk:
			mark_chunk_and_neighbors_visible(current_chunk)
		
		var neighbors = _get_neighbor_positions(pos)
		for neighbor in neighbors:
			if checked.has(neighbor):
				continue
				
			checked[neighbor] = true
			var cell = get_cell(neighbor)
			if cell:
				if cell.solid:
					cell.visible = true
				else:
					to_check.append(neighbor)
	
	update_minable_states()
	grid_updated.emit()

func update_visibility_local(pos: Vector2i, radius: int = 2):
	var affected_chunks := {}
	var checked := {}
	var to_check := [pos]
	checked[pos] = true
	
	# Flood fill within radius
	while not to_check.is_empty():
		var check_pos = to_check.pop_front()
		var chunk = get_chunk_at_grid_pos(check_pos)
		if chunk:
			affected_chunks[chunk] = true
		
		# Get neighbors
		var neighbors = _get_neighbor_positions(check_pos)
		for neighbor in neighbors:
			if checked.has(neighbor):
				continue
				
			checked[neighbor] = true
			var cell = get_cell(neighbor)
			if cell:
				# Make sure we preserve the cell type when marking visible
				if cell.solid:
					cell.visible = true
					# No need to modify cell.type as it should remain unchanged
				else:
					to_check.append(neighbor)
	
	# Update affected chunks and their neighbors
	var chunks_to_update := {}
	for chunk in affected_chunks:
		chunks_to_update[chunk] = true
		# Get neighboring chunks
		var chunk_pos = Vector2i(
			chunk.grid_position.x / CHUNK_SIZE,
			chunk.grid_position.y / CHUNK_SIZE
		)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var check_x = chunk_pos.x + dx
				var check_y = chunk_pos.y + dy
				
				if check_x < 0 or check_x >= len(chunks[0]) or check_y < 0 or check_y >= len(chunks):
					continue
					
				chunks_to_update[chunks[check_y][check_x]] = true
	
	# Update visibility for affected chunks - preserve types
	for chunk in chunks_to_update:
		var level = get_chunk_visibility_level(chunk)
		if level > 0:
			for cell in chunk.cells:
				if cell.solid:
					cell.visible = true
					# Again, no need to modify cell.type
	
	grid_updated.emit()

func update_minable_states():
	# Update minable state for all cells
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var cell = grid[y][x]
			if cell.solid and cell.visible:
				# Check if adjacent to an empty space
				var neighbors = _get_neighbor_positions(Vector2i(x, y))
				cell.minable = false
				for neighbor in neighbors:
					var neighbor_cell = get_cell(neighbor)
					if neighbor_cell and not neighbor_cell.solid:
						cell.minable = true
						break
			else:
				cell.minable = false

func update_minable_states_local(pos: Vector2i):
	var radius := 1
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_pos = pos + Vector2i(dx, dy)
			var cell = get_cell(check_pos)
			if cell and cell.solid and cell.visible:
				# Check if adjacent to an empty space
				var neighbors = _get_neighbor_positions(check_pos)
				cell.minable = false
				for neighbor in neighbors:
					var neighbor_cell = get_cell(neighbor)
					if neighbor_cell and not neighbor_cell.solid:
						cell.minable = true
						break

func _get_neighbor_positions(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for dir in directions:
		var neighbor = pos + dir
		if neighbor.x >= 0 and neighbor.x < GRID_WIDTH and neighbor.y >= 0 and neighbor.y < GRID_HEIGHT:
			neighbors.append(neighbor)
	
	return neighbors

func mark_chunk_and_neighbors_visible(center_chunk: TerrainChunk):
	var center_pos = Vector2i(
		center_chunk.grid_position.x / CHUNK_SIZE,
		center_chunk.grid_position.y / CHUNK_SIZE
	)
	
	# Mark chunks within visibility range
	for dy in range(-VISIBILITY_RANGE, VISIBILITY_RANGE + 1):
		for dx in range(-VISIBILITY_RANGE, VISIBILITY_RANGE + 1):
			var check_x = center_pos.x + dx
			var check_y = center_pos.y + dy
			
			if check_x < 0 or check_x >= len(chunks[0]) or check_y < 0 or check_y >= len(chunks):
				continue
				
			var chunk = chunks[check_y][check_x]
			var distance = max(abs(dx), abs(dy))
			
			# Set visibility level (2 for inner, 1 for outer)
			var visibility_level = 2 if distance <= VISIBILITY_RANGE - 1 else 1
			chunk_visibility_levels[chunk] = max(visibility_level, chunk_visibility_levels.get(chunk, 0))
			
			# Make cells in chunk visible
			for cell in chunk.cells:
				cell.visible = true

func get_chunk_visibility_level(chunk: TerrainChunk) -> int:
	return chunk_visibility_levels.get(chunk, 0)

func mine_cell(pos: Vector2i, damage: float) -> bool:
	var cell = get_cell(pos)
	if cell and cell.minable:
		cell.health -= damage
		if cell.health <= 0:
			cell.solid = false
			# Batch these updates
			if mining_update_timer <= 0:
				update_visibility_local(pos)
				update_minable_states_local(pos)
				mining_update_timer = MINING_UPDATE_INTERVAL
			block_mined.emit(pos)
			return true
	return false

func get_cell(pos: Vector2i) -> TerrainCell:
	if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
		return grid[pos.y][pos.x]
	return null

func get_chunk_at_grid_pos(grid_pos: Vector2i) -> TerrainChunk:
	var chunk_x = grid_pos.x / CHUNK_SIZE
	var chunk_y = grid_pos.y / CHUNK_SIZE
	if chunk_x >= 0 and chunk_x < len(chunks[0]) and chunk_y >= 0 and chunk_y < len(chunks):
		return chunks[chunk_y][chunk_x]
	return null

func select_chunk(chunk: TerrainChunk):
	if !chunk.has_visible_cells():
		return
		
	if chunk.is_selected:
		# Deselect if already selected
		chunk.is_selected = false
		selected_chunks.erase(chunk)
	else:
		# Add to selection
		chunk.is_selected = true
		selected_chunks.append(chunk)
	
	selection_changed.emit()

func clear_selection():
	for chunk in selected_chunks:
		chunk.is_selected = false
	selected_chunks.clear()
	selection_changed.emit()

func get_selected_minable_cells() -> Array[TerrainCell]:
	var cells: Array[TerrainCell] = []
	for chunk in selected_chunks:
		cells.append_array(chunk.get_minable_cells())
	return cells

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CELL_SIZE + GRID_WIDTH/2),
		int(world_pos.y / CELL_SIZE + GRID_HEIGHT/2)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(grid_pos.x - GRID_WIDTH/2) * CELL_SIZE + CELL_SIZE / 2,
		(grid_pos.y - GRID_HEIGHT/2) * CELL_SIZE + CELL_SIZE / 2
	)
