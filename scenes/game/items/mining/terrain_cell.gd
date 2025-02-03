# terrain_cell.gd
class_name TerrainCell
extends RefCounted

enum CellType { IRON_ORE, DIAMOND, BLOOD_ORE, WATERSTONE, STONE, GROUND }

var type: CellType
var solid: bool = true
var visible: bool = false
var minable: bool = false
var health: float = 100.0
var grid_position: Vector2i

func initialize_cell(cell_type: CellType = CellType.STONE, pos: Vector2i = Vector2i.ZERO):
	type = cell_type
	grid_position = pos
	
	# Set health based on type
	match type:
		CellType.IRON_ORE:
			health = 150.0
		CellType.DIAMOND:
			health = 300.0
		CellType.BLOOD_ORE:
			health = 200.0
		CellType.WATERSTONE:
			health = 400.0
		CellType.STONE:
			health = 100.0
		CellType.GROUND:
			health = 50.0
