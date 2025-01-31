extends Node2D

const MOVE_SPEED: float = 100.0
const MINING_DISTANCE: float = 40.0
const MINING_DAMAGE: float = 50.0
const PATH_RECALC_TIME: float = 0.5
const ARRIVAL_THRESHOLD: float = 5.0
const MAX_PATH_LENGTH: float = 2000.0

enum State { IDLE, MOVING_TO_TARGET, MINING }
var current_state: State = State.IDLE

var target_cell: TerrainCell = null
var target_position: Vector2 = Vector2.ZERO
var current_path: Array[Vector2] = []
var current_path_index: int = 0
var path_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	OrderMgmtAuto.orders_updated.connect(_on_orders_updated)
	if sprite and sprite.sprite_frames:
		sprite.play("idle")  # Assuming you have an "idle" animation

func _process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_find_and_set_target()
		State.MOVING_TO_TARGET:
			_handle_moving_state(delta)
		State.MINING:
			_handle_mining_state(delta)

func _on_orders_updated() -> void:
	_release_current_target()
	current_state = State.IDLE

func _find_and_set_target() -> void:
	var best_target = _find_best_target()
	if best_target and OrderMgmtAuto.reserve_cell(best_target, self):
		target_cell = best_target
		target_position = GameMgmtAuto.grid_to_world(target_cell.grid_position)
		_update_path()
		if not current_path.is_empty():
			current_state = State.MOVING_TO_TARGET
			if sprite:
				sprite.play("running")

func _handle_moving_state(delta: float) -> void:
	if not target_cell or not target_cell.minable:
		_release_current_target()
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")
		return
	
	if OrderMgmtAuto.get_cell_reserver(target_cell) != self:
		_release_current_target()
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")
		return
	
	path_timer -= delta
	if path_timer <= 0:
		path_timer = PATH_RECALC_TIME
		_update_path()
	
	if current_path.is_empty():
		_release_current_target()
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")
		return
		
	var next_point = current_path[current_path_index]
	var direction = (next_point - position).normalized()
	
	if position.distance_to(target_position) >= MINING_DISTANCE:
		# Update sprite flip based on movement direction
		if sprite:
			sprite.flip_h = direction.x < 0
		
		# Simple movement without physics
		position += direction * MOVE_SPEED * delta
		
		if position.distance_to(next_point) < ARRIVAL_THRESHOLD:
			current_path_index += 1
			if current_path_index >= current_path.size():
				current_path = []
				current_path_index = 0
	else:
		current_state = State.MINING
		if sprite:
			sprite.play("mining")

func _handle_mining_state(delta: float) -> void:
	if not target_cell or not target_cell.minable:
		_release_current_target()
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")
		return
	
	var ordered_cells := OrderMgmtAuto.get_selected_cells()
	if not ordered_cells.has(target_cell) or OrderMgmtAuto.get_cell_reserver(target_cell) != self:
		_release_current_target()
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")
		return
	
	# Apply mining damage
	if GameMgmtAuto.mine_cell(target_cell.grid_position, MINING_DAMAGE * delta):
		call_deferred("_release_current_target")  # Defer to avoid state changes mid-frame
		current_state = State.IDLE
		if sprite:
			sprite.play("idle")

func _find_best_target() -> TerrainCell:
	var available_cells := OrderMgmtAuto.get_available_cells()
	var best_cell: TerrainCell = null
	var shortest_path_length := INF
	
	for cell in available_cells:
		if cell.minable:
			var path = NavMgmtAuto.get_navigation_path(position, GameMgmtAuto.grid_to_world(cell.grid_position))
			if not path.is_empty():
				var path_length = _calculate_path_length(path)
				if path_length < shortest_path_length and path_length < MAX_PATH_LENGTH:
					shortest_path_length = path_length
					best_cell = cell
	
	return best_cell

func _update_path() -> void:
	current_path = NavMgmtAuto.get_navigation_path(position, target_position)
	current_path_index = 0
	if not current_path.is_empty() and position.distance_to(current_path[0]) < ARRIVAL_THRESHOLD:
		current_path.remove_at(0)

func _calculate_path_length(path: Array[Vector2]) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i-1].distance_to(path[i])
	return length

func _release_current_target() -> void:
	if target_cell:
		OrderMgmtAuto.release_cell(target_cell)
		target_cell = null
	current_path = []
	current_path_index = 0
