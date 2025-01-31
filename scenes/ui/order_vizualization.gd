# order_visualization.gd
extends Control

var order_color := Color(0.2, 0.7, 0.9, 0.3)
var order_outline_color := Color(0.2, 0.7, 0.9, 0.8)
var available_chunk_color := Color(0.5, 0.5, 0.5, 0.15)
var available_chunk_outline := Color(0.5, 0.5, 0.5, 0.4)
var outer_visibility_overlay := Color(0, 0, 0, 0.3)  # Darker overlay for outer visible chunks
var update_queued := false
var affected_chunks := {}  # Dictionary to track chunks that need updating

func _ready() -> void:
	OrderMgmtAuto.orders_updated.connect(on_orders_updated)
	OrderMgmtAuto.build_mode_changed.connect(queue_redraw)
	GameMgmtAuto.block_mined.connect(on_block_mined)
	GameMgmtAuto.grid_updated.connect(queue_redraw)

func on_orders_updated() -> void:
	# Full redraw needed when orders change
	affected_chunks.clear()
	queue_redraw()

func on_block_mined(position: Vector2i) -> void:
	# Get the chunk containing this position
	var chunk = GameMgmtAuto.get_chunk_at_grid_pos(position)
	if chunk and chunk.is_selected:
		# Mark this chunk for update
		affected_chunks[chunk] = true
		
		if not update_queued:
			update_queued = true
			# Schedule an update for the next frame
			call_deferred("update_visualization")

func update_visualization() -> void:
	if affected_chunks.is_empty():
		update_queued = false
		return
		
	# Only redraw if we have affected chunks
	queue_redraw()
	affected_chunks.clear()
	update_queued = false

func _draw() -> void:
	if !OrderMgmtAuto.is_ordering:
		return
	# Draw all visible chunks with appropriate shading
	for y in GameMgmtAuto.chunks.size():
		for x in GameMgmtAuto.chunks[y].size():
			var chunk = GameMgmtAuto.chunks[y][x]
			var visibility_level = GameMgmtAuto.get_chunk_visibility_level(chunk)
			
			if visibility_level > 0:
				# Draw base chunk
				if OrderMgmtAuto.is_ordering and chunk.has_visible_cells():
					draw_chunk_outline(chunk, available_chunk_color, available_chunk_outline)
				
				# Add darker overlay for outer visible chunks
				if visibility_level == 1:  # Outer visible chunk
					draw_chunk_overlay(chunk, outer_visibility_overlay)
	
	# Draw selected chunks on top
	for chunk in OrderMgmtAuto.selected_chunks:
		draw_chunk_selection(chunk)

func draw_chunk_outline(chunk: TerrainChunk, fill_color: Color, outline_color: Color) -> void:
	var chunk_size = GameMgmtAuto.CHUNK_SIZE * GameMgmtAuto.CELL_SIZE
	var start_pos = Vector2(
		(chunk.grid_position.x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
		(chunk.grid_position.y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
	)
	
	# Draw fill
	draw_rect(Rect2(start_pos, Vector2(chunk_size, chunk_size)), fill_color)
	# Draw outline
	draw_rect(Rect2(start_pos, Vector2(chunk_size, chunk_size)), outline_color, false)

func draw_chunk_overlay(chunk: TerrainChunk, overlay_color: Color) -> void:
	var chunk_size = GameMgmtAuto.CHUNK_SIZE * GameMgmtAuto.CELL_SIZE
	var start_pos = Vector2(
		(chunk.grid_position.x - GameMgmtAuto.GRID_WIDTH/2) * GameMgmtAuto.CELL_SIZE,
		(chunk.grid_position.y - GameMgmtAuto.GRID_HEIGHT/2) * GameMgmtAuto.CELL_SIZE
	)
	
	draw_rect(Rect2(start_pos, Vector2(chunk_size, chunk_size)), overlay_color)

func draw_chunk_selection(chunk: TerrainChunk) -> void:
	draw_chunk_outline(chunk, order_color, order_outline_color)
