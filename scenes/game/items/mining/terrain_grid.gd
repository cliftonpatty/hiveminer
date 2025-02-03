# terrain_grid.gd
@tool
extends Node2D

const ZOOM_THRESHOLD = 1.2

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		queue_redraw()
		
@export var regenerate: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate_editor_preview()

@onready var tilemap: TileMap = $TileMap
@onready var cells_node: Node2D = $Cells
@onready var selection_node: Node2D = $Selection

var using_detailed_view: bool = true

func _ready():
	if not Engine.is_editor_hint():
		if not cells_node:
			cells_node = Node2D.new()
			add_child(cells_node)
		
		if not selection_node:
			selection_node = Node2D.new()
			selection_node.z_index = 1  # Draw on top of cells
			add_child(selection_node)
		
		GameMgmtAuto.grid_updated.connect(draw_terrain)
		GameMgmtAuto.selection_changed.connect(draw_selection)
		get_tree().get_root().get_viewport().get_camera_2d().zoom_changed.connect(_on_camera_zoom_changed)
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

func _on_camera_zoom_changed():
	var camera = get_viewport().get_camera_2d()
	if camera:
		var new_detailed = camera.zoom.x > ZOOM_THRESHOLD
		if new_detailed != using_detailed_view:
			using_detailed_view = new_detailed
			draw_terrain()

func draw_terrain():
	if Engine.is_editor_hint():
		return
	
	if using_detailed_view:
		cells_node.hide()
		tilemap.clear()
		
		# First pass: Draw all normal tiles
		for y in GameMgmtAuto.GRID_HEIGHT:
			for x in GameMgmtAuto.GRID_WIDTH:
				var cell = GameMgmtAuto.grid[y][x]
				if !cell.visible:
					continue
					
				var pos = Vector2i(
					x - GameMgmtAuto.GRID_WIDTH/2,
					y - GameMgmtAuto.GRID_HEIGHT/2
				)
				
				if cell.solid:
					# source_id is usually 0 if you only have one tile source
					tilemap.set_cell(0, pos, 0, _get_tile_coords_for_type(cell.type), 0)
				else:
					tilemap.set_cell(0, pos, 0, _get_tile_coords_for_type(TerrainCell.CellType.GROUND), 0)
					
					# Check for walls above this empty space
					if y > 0:
						var above_cell = GameMgmtAuto.grid[y-1][x]
						if above_cell.solid and above_cell.visible:
							# Add wall overlay using the wall tile (0,1)
							tilemap.set_cell(1, pos, 0, Vector2i(0, 1), 0)
		
		tilemap.show()
	else:
		tilemap.hide()
		for child in cells_node.get_children():
			child.queue_free()
		
		for y in GameMgmtAuto.GRID_HEIGHT:
			for x in GameMgmtAuto.GRID_WIDTH:
				var cell = GameMgmtAuto.grid[y][x]
				if !cell.visible:
					continue
				
				var rect = ColorRect.new()
				rect.size = Vector2(GameMgmtAuto.CELL_SIZE, GameMgmtAuto.CELL_SIZE)
				rect.position = Vector2(
					(x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
					(y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
				)
				
				rect.color = get_cell_color(cell)
				cells_node.add_child(rect)
		cells_node.show()

func _get_tile_coords_for_type(type: TerrainCell.CellType) -> Vector2i:
	match type:
		TerrainCell.CellType.IRON_ORE:
			return Vector2i(0, 0)
		TerrainCell.CellType.DIAMOND:
			return Vector2i(1, 0)
		TerrainCell.CellType.BLOOD_ORE:
			return Vector2i(2, 0)
		TerrainCell.CellType.WATERSTONE:
			return Vector2i(3, 0)
		TerrainCell.CellType.STONE:
			return Vector2i(4, 0)
		TerrainCell.CellType.GROUND:
			return Vector2i(5, 1)
	return Vector2i(4, 0)  # Default to stone

func get_cell_color(cell: TerrainCell) -> Color:
	if !cell.solid:
		return Color(0.1, 0.1, 0.1)
	match cell.type:
		TerrainCell.CellType.IRON_ORE:
			return Color(0.7, 0.4, 0.3)  # Reddish brown
		TerrainCell.CellType.DIAMOND:
			return Color(0.0, 0.8, 1.0)  # Light blue
		TerrainCell.CellType.BLOOD_ORE:
			return Color(0.8, 0.0, 0.0)  # Deep red
		TerrainCell.CellType.WATERSTONE:
			return Color(0.0, 0.4, 0.8)  # Deep blue
		TerrainCell.CellType.STONE:
			return Color(0.5, 0.5, 0.5)  # Gray
		TerrainCell.CellType.GROUND:
			return Color(0.3, 0.3, 0.3)  # Darker gray
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
		return Color(0.8, 0.0, 0.0, 0.5)  # Blood Ore
	elif value < 0.2:
		return Color(0.7, 0.4, 0.3, 0.5)  # Iron
	elif value < 0.25:
		return Color(0.0, 0.4, 0.8, 0.5)  # Waterstone
	elif value < 0.6:
		return Color(0.5, 0.5, 0.5, 0.5)  # Stone
	return Color(0.3, 0.3, 0.3, 0.5)  # Ground

func generate_editor_preview():
	queue_redraw()
