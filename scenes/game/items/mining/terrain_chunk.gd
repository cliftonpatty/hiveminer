# terrain_chunk.gd
class_name TerrainChunk
extends RefCounted

var grid_position: Vector2i
var cells: Array[TerrainCell] = []
var is_selected: bool = false

func _init(pos: Vector2i):
	grid_position = pos
	cells.resize(GameMgmtAuto.CHUNK_SIZE * GameMgmtAuto.CHUNK_SIZE)  # Using GameMgmtAuto's CHUNK_SIZE

func add_cell(cell: TerrainCell, local_x: int, local_y: int):
	cells[local_y * GameMgmtAuto.CHUNK_SIZE + local_x] = cell

func get_cell(local_x: int, local_y: int) -> TerrainCell:
	return cells[local_y * GameMgmtAuto.CHUNK_SIZE + local_x]

func has_visible_cells() -> bool:
	for cell in cells:
		if cell.visible:
			return true
	return false

func get_visible_cells() -> Array[TerrainCell]:
	var visible_cells: Array[TerrainCell] = []
	for cell in cells:
		if cell.visible:
			visible_cells.append(cell)
	return visible_cells

func get_minable_cells() -> Array[TerrainCell]:
	var minable: Array[TerrainCell] = []
	for cell in cells:
		if cell.visible and cell.solid:
			minable.append(cell)
	return minable

# Get world position of chunk's center
func get_center_position() -> Vector2:
	return GameMgmtAuto.grid_to_world(grid_position + Vector2i(1, 1))  # Center of middle cell
