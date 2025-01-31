extends Camera2D

# Zoom settings
var min_zoom := 0.5
var max_zoom := 2.0
var zoom_speed := 0.1
var zoom_factor := 1.0

# Pan settings
var pan_speed := 10.0
var inertia := Vector2.ZERO
var inertia_dampening := 0.9

# Touch handling
var touch_points := {}
var last_drag_distance := 0.0
var drag_sensitivity := 1.0

func _ready():
	# Enable processing for smooth inertia
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0

func _input(event):
	if event is InputEventScreenDrag:
		# Handle drag (pan) with inertia
		inertia = -event.relative * drag_sensitivity
		position += -event.relative * zoom.x
		
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			
			# Reset zoom tracking when all fingers are lifted
			if touch_points.is_empty():
				last_drag_distance = 0.0
				
	elif event is InputEventMouseButton:
		# Mouse wheel zoom for development
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = clamp(zoom_factor - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = clamp(zoom_factor + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor

func _process(delta):
	# Apply inertia
	if inertia.length() > 0.1:
		position += inertia * delta
		inertia *= inertia_dampening
	else:
		inertia = Vector2.ZERO
	
	# Handle pinch to zoom
	if touch_points.size() == 2:
		var touch_points_array = touch_points.values()
		var current_drag_distance = touch_points_array[0].distance_to(touch_points_array[1])
		
		if last_drag_distance != 0:
			var drag_difference = last_drag_distance - current_drag_distance
			zoom_factor = clamp(zoom_factor + drag_difference * 0.001, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor
			
		last_drag_distance = current_drag_distance

# Optional: Add limits to prevent camera from going too far
func set_camera_limits(map_size: Vector2):
	limit_left = 0
	limit_top = 0
	limit_right = map_size.x
	limit_bottom = map_size.y
