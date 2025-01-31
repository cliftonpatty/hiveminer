# order_manager.gd
extends Node

signal orders_updated
signal chunk_selection_changed
signal build_mode_changed

var is_ordering: bool = false:
	set(value):
		print("OrderMgmtAuto: is_ordering set to ", value)  # Debug print
		is_ordering = value
		build_mode_changed.emit()

var selected_chunks: Array[TerrainChunk] = []
var reserved_cells: Dictionary = {}  # Vector2i position -> character reference

func toggle_orders(enabled: bool) -> void:
	print("OrderMgmtAuto: toggle_orders called with ", enabled)  # Debug print
	is_ordering = enabled

func clear_orders() -> void:
	for chunk in selected_chunks:
		chunk.is_selected = false
	selected_chunks.clear()
	reserved_cells.clear()  # Clear reservations when orders are cleared
	orders_updated.emit()

func select_chunk(chunk: TerrainChunk) -> void:
	if not is_ordering:
		return
		
	if chunk.is_selected:
		# Deselect if already selected
		chunk.is_selected = false
		selected_chunks.erase(chunk)
		# Remove any reservations in this chunk
		for cell in chunk.get_minable_cells():
			reserved_cells.erase(cell.grid_position)
	else:
		# Add to selection - can select any chunk within grid bounds
		chunk.is_selected = true
		selected_chunks.append(chunk)
	
	orders_updated.emit()

func get_selected_cells() -> Array[TerrainCell]:
	var cells: Array[TerrainCell] = []
	for chunk in selected_chunks:
		cells.append_array(chunk.get_minable_cells())
	return cells

func get_available_cells() -> Array[TerrainCell]:
	var cells: Array[TerrainCell] = []
	var all_cells := get_selected_cells()
	
	for cell in all_cells:
		if not reserved_cells.has(cell.grid_position):
			cells.append(cell)
	
	return cells

func reserve_cell(cell: TerrainCell, character: Node2D) -> bool:
	if not reserved_cells.has(cell.grid_position):
		reserved_cells[cell.grid_position] = character
		return true
	return false

func release_cell(cell: TerrainCell) -> void:
	if reserved_cells.has(cell.grid_position):
		reserved_cells.erase(cell.grid_position)

func is_cell_reserved(cell: TerrainCell) -> bool:
	return reserved_cells.has(cell.grid_position)

func get_cell_reserver(cell: TerrainCell) -> Node2D:
	return reserved_cells.get(cell.grid_position)
