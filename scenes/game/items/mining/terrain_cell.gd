# terrain_cell.gd
class_name TerrainCell
extends RefCounted

enum CellType { DIRT, STONE, IRON_ORE, GOLD_ORE, DIAMOND }

var type: CellType
var solid: bool = true
var visible: bool = false  # For rendering/fog of war
var minable: bool = false  # For gameplay mechanics
var health: float = 100.0
var grid_position: Vector2i

func initialize_cell(cell_type: CellType = CellType.DIRT, pos: Vector2i = Vector2i.ZERO):
	type = cell_type
	grid_position = pos
	
	# Set health based on type
	match type:
		CellType.DIRT:
			health = 50.0
		CellType.STONE:
			health = 100.0
		CellType.IRON_ORE:
			health = 150.0
		CellType.GOLD_ORE:
			health = 200.0
		CellType.DIAMOND:
			health = 300.0
