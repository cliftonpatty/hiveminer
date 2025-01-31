# terrain_grid.gd
@tool
extends Node2D

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		queue_redraw()
		
@export var regenerate: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate_editor_preview()

var cells_node: Node2D
var selection_node: Node2D
var cell_nodes := {}  # Store cells by position

func _ready():
	if not Engine.is_editor_hint():
		cells_node = Node2D.new()
		add_child(cells_node)
		
		selection_node = Node2D.new()
		selection_node.z_index = 1  # Draw on top of cells
		add_child(selection_node)
		
		GameMgmtAuto.grid_updated.connect(draw_terrain)
		GameMgmtAuto.selection_changed.connect(draw_selection)
		set_process_input(true)
		draw_terrain()

func _input(event):
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check for UI clicks first
		var ui_elements = get_tree().get_nodes_in_group("UI")
		for ui in ui_elements:
			if ui is Control and ui.get_global_rect().has_point(event.global_position):
				return
		
		if OrderMgmtAuto.is_ordering:
			var grid_pos = GameMgmtAuto.world_to_grid(get_local_mouse_position())
			var chunk = GameMgmtAuto.get_chunk_at_grid_pos(grid_pos)
			if chunk:
				OrderMgmtAuto.select_chunk(chunk)
				get_viewport().set_input_as_handled()

func _draw():
	if Engine.is_editor_hint() and preview_in_editor:
		draw_editor_preview()

func draw_editor_preview():
	for y in GameMgmtAuto.GRID_HEIGHT:
		for x in GameMgmtAuto.GRID_WIDTH:
			var rect_pos = Vector2(
				(x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
				(y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
			)
			var rect_size = Vector2(GameMgmtAuto.CELL_SIZE, GameMgmtAuto.CELL_SIZE)
			
			var center = Vector2(GameMgmtAuto.GRID_WIDTH / 2, GameMgmtAuto.GRID_HEIGHT / 2)
			var distance = Vector2(x - center.x, y - center.y).length()
			
			var color = get_preview_cell_color(x, y, distance)
			draw_rect(Rect2(rect_pos, rect_size), color)

func get_preview_cell_color(x: int, y: int, distance: float) -> Color:
	if distance < GameMgmtAuto.STARTING_AREA_SIZE:
		return Color(0.1, 0.1, 0.1, 0.5)
		
	var rng = RandomNumberGenerator.new()
	rng.seed = x * 1000 + y
	var value = rng.randf()
	
	if value < 0.05:
		return Color(0.0, 0.8, 1.0, 0.5)  # Diamond
	elif value < 0.1:
		return Color(1.0, 0.8, 0.0, 0.5)  # Gold
	elif value < 0.2:
		return Color(0.7, 0.4, 0.3, 0.5)  # Iron
	elif value < 0.6:
		return Color(0.5, 0.5, 0.5, 0.5)  # Stone
	return Color(0.6, 0.4, 0.2, 0.5)  # Dirt

func generate_editor_preview():
	queue_redraw()

func draw_terrain():
	if Engine.is_editor_hint():
		return
		
	# First, mark all existing nodes for potential removal
	var nodes_to_check = cell_nodes.duplicate()
	
	# Update or create cells
	for y in GameMgmtAuto.GRID_HEIGHT:
		for x in GameMgmtAuto.GRID_WIDTH:
			var grid_pos = Vector2i(x, y)
			var cell = GameMgmtAuto.grid[y][x]
			
			if cell.visible:
				if cell_nodes.has(grid_pos):
					# Update existing cell
					cell_nodes[grid_pos].color = get_cell_color(cell)
				else:
					# Create new cell
					var rect = ColorRect.new()
					rect.size = Vector2(GameMgmtAuto.CELL_SIZE, GameMgmtAuto.CELL_SIZE)
					rect.position = Vector2(
						(x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
						(y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
					)
					rect.color = get_cell_color(cell)
					cells_node.add_child(rect)
					cell_nodes[grid_pos] = rect
				
				# Remove from check list since we updated it
				nodes_to_check.erase(grid_pos)
	
	# Remove any nodes that weren't updated
	for pos in nodes_to_check:
		if cell_nodes.has(pos):
			cell_nodes[pos].queue_free()
			cell_nodes.erase(pos)

func get_cell_color(cell: TerrainCell) -> Color:
	if !cell.solid:
		return Color(0.1, 0.1, 0.1)  # Dark color for empty space
		
	match cell.type:
		TerrainCell.CellType.DIRT:
			return Color(0.6, 0.4, 0.2)
		TerrainCell.CellType.STONE:
			return Color(0.5, 0.5, 0.5)  # This is the gray we're seeing
		TerrainCell.CellType.IRON_ORE:
			return Color(0.7, 0.4, 0.3)
		TerrainCell.CellType.GOLD_ORE:
			return Color(1.0, 0.8, 0.0)
		TerrainCell.CellType.DIAMOND:
			return Color(0.0, 0.8, 1.0)
	return Color(0.1, 0.1, 0.1)  # Fallback color

func draw_selection():
	for child in selection_node.get_children():
		child.queue_free()
		
	for chunk in GameMgmtAuto.selected_chunks:
		var outline = ColorRect.new()
		outline.size = Vector2(GameMgmtAuto.CELL_SIZE * GameMgmtAuto.CHUNK_SIZE,
							 GameMgmtAuto.CELL_SIZE * GameMgmtAuto.CHUNK_SIZE)
		outline.position = Vector2(
			(chunk.grid_position.x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
			(chunk.grid_position.y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
		)
		outline.color = Color(1, 1, 1, 0.3)
		selection_node.add_child(outline)
