extends Node2D

# Each path is an array of Vector2 points
var paths = []
var spawn_points = []
@export var path_width = 100.0
@export var path_color = Color(0.3, 0.3, 0.3, 1.0)  # Gray paths

# How many paths to create
@export var path_count = 4

# Reference to the home position
var home_position = Vector2.ZERO

func _ready():
	# Get home position
	var home = get_tree().get_first_node_in_group("home")
	if home:
		home_position = home.global_position
	
	# Generate paths
	generate_paths(path_count)

func _draw():
	# Draw all paths
	for path in paths:
		draw_path(path)

func generate_paths(count):
	# Clear existing paths
	paths.clear()
	spawn_points.clear()
	
	# Define world bounds (get from world_generator if exists)
	var world_width = 2000
	var world_height = 2000
	var world_generator = get_tree().get_first_node_in_group("world_generator")
	if world_generator:
		world_width = world_generator.world_width
		world_height = world_generator.world_height
	
	# Calculate radius for spawn points (75% of distance to map edge)
	var spawn_radius = min(world_width, world_height) * 0.4
	
	# Generate paths evenly around the map
	for i in range(count):
		var angle = (2 * PI / count) * i
		
		# Create spawn point at map edge
		var spawn_point = home_position + Vector2(
			cos(angle) * spawn_radius,
			sin(angle) * spawn_radius
		)
		spawn_points.append(spawn_point)
		
		# Create path with multiple points
		var path = create_path_from_spawn(spawn_point, home_position)
		paths.append(path)
	
	# Redraw the paths
	queue_redraw()

func create_path_from_spawn(spawn_point, destination):
	var path = []
	path.append(spawn_point)
	
	# Add some midpoints to make the path more interesting
	# We'll add 1-2 midpoints between spawn and home
	var midpoint_count = randi() % 2 + 1
	
	for i in range(midpoint_count):
		# Calculate a midpoint with some randomness
		var progress = float(i + 1) / (midpoint_count + 1)
		var direct_point = spawn_point.lerp(destination, progress)
		
		# Add some randomness to the midpoint
		var perpendicular = (destination - spawn_point).normalized().rotated(PI/2)
		var random_offset = perpendicular * (randf_range(-1, 1) * 200)
		var midpoint = direct_point + random_offset
		
		path.append(midpoint)
	
	# Add the destination (home)
	path.append(destination)
	
	return path

func draw_path(path):
	if path.size() < 2:
		return
	
	# Draw the path as a line
	for i in range(path.size() - 1):
		var start = path[i]
		var end = path[i + 1]
		
		# Draw the main path
		draw_line(start, end, path_color, path_width)
		
		# Draw arrows along the path
		var distance = start.distance_to(end)
		var direction = (end - start).normalized()
		var perpendicular = direction.rotated(PI/2)
		
		# Draw an arrow every 100 pixels
		var arrow_spacing = 100
		var num_arrows = int(distance / arrow_spacing)
		
		for j in range(num_arrows):
			var arrow_pos = start + direction * (j + 0.5) * arrow_spacing
			var arrow_size = path_width * 0.8
			
			# Arrow points
			var arrow_points = [
				arrow_pos + direction * arrow_size,  # Tip
				arrow_pos - direction * arrow_size + perpendicular * arrow_size * 0.6,  # Left wing
				arrow_pos - direction * arrow_size - perpendicular * arrow_size * 0.6   # Right wing
			]
			
			# Draw filled triangle for arrow
			draw_colored_polygon(arrow_points, path_color.lightened(0.2))
		
		# Draw a circle at each point
		if i < path.size() - 1:
			draw_circle(start, path_width / 2, path_color.lightened(0.2))
	
	# Draw a circle at spawn point
	draw_circle(path[0], path_width * 0.8, Color(1, 0, 0, 0.7))
	
	# Draw a circle at the end (home)
	draw_circle(path[path.size() - 1], path_width * 0.8, Color(0, 0.4, 1, 0.7))

func get_enemy_path(index):
	if index >= 0 and index < paths.size():
		return paths[index]
	return null

func get_spawn_point(index):
	if index >= 0 and index < spawn_points.size():
		return spawn_points[index]
	return null

func get_random_path_index():
	if paths.size() > 0:
		return randi() % paths.size()
	return -1
