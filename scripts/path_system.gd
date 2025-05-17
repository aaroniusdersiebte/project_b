extends Node2D

# Each path is an array of Vector2 points
var paths = []
var spawn_points = []
@export var path_width = 100.0  # Noch breiter für bessere Sichtbarkeit
@export var path_color = Color(0.8, 0.8, 0.8, 0.9)  # Fast weiß mit hoher Deckkraft
@export var path_arrow_color = Color(1.0, 1.0, 1.0, 1.0)  # Rein weißer Pfeil

# Exakt 4 Pfade erzeugen - fix gesetzt
@export var path_count = 4

# Reference to the home position
var home_position = Vector2.ZERO

func _ready():
	# Get home position
	var home = get_tree().get_first_node_in_group("home")
	if home:
		home_position = home.global_position
	
	# Wichtig: Erzwingen dass path_count genau 4 ist
	path_count = 4
	
	# Log für Debugging
	print("PathSystem generating " + str(path_count) + " paths")
	
	# Generate paths
	paths.clear()  # Bestehende Pfade löschen
	spawn_points.clear()  # Bestehende Spawnpunkte löschen
	generate_paths(path_count)
	
	print("PathSystem created " + str(paths.size()) + " paths and " + str(spawn_points.size()) + " spawn points")

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
	
	# 80% der Distanz zum Rand für bessere Verteilung
	var spawn_radius = min(world_width, world_height) * 0.8
	
	# Find the home position as center reference
	var home_position = Vector2.ZERO
	var home = get_tree().get_first_node_in_group("home")
	if home:
		home_position = home.global_position
	
	# Generate paths evenly around the map (exactly 4)
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
	
	# Mehr Punkte für komplexere Pfade
	var midpoint_count = randi_range(5, 8)  # Erhöht von 2-3 auf 5-8 Punkte
	
	# Grundlegende Richtung vom Spawn zum Ziel
	var main_direction = (destination - spawn_point).normalized()
	var main_distance = spawn_point.distance_to(destination)
	
	# Parameter für Schlängelung
	var winding_factor = randf_range(0.2, 0.5)  # Wie stark die Schlängelung ist
	var winding_frequency = randf_range(0.5, 2.0)  # Wie häufig die Schlängelung ist
	
	# Möglicher Looping?
	var make_loop = randf() < 0.5  # 50% Chance auf einen Looping
	var loop_center = Vector2.ZERO
	var loop_radius = 0.0
	var loop_start_index = 0
	
	if make_loop:
		# Loop etwa 1/3 des Wegs vom Spawn zum Ziel platzieren
		var loop_position = randf_range(0.2, 0.6)  # Position des Loops zwischen Spawn und Ziel
		loop_start_index = int(midpoint_count * loop_position)
		loop_center = spawn_point.lerp(destination, loop_position)
		
		# Loop-Radius sollte proportional zur Strecke sein
		loop_radius = main_distance * randf_range(0.15, 0.25)  # 15-25% der Gesamtstrecke
		
		# Verschieben des Loop-Zentrums zur Seite
		var perpendicular = main_direction.rotated(PI/2)
		loop_center += perpendicular * loop_radius * randf_range(0.7, 1.3)
	
	# Pfad erzeugen
	for i in range(midpoint_count):
		var progress = float(i + 1) / (midpoint_count + 1)
		
		# Grundposition entlang der Strecke
		var direct_point = spawn_point.lerp(destination, progress)
		
		# Schlängelung hinzufügen mit Sinus-Welle
		var perpendicular = main_direction.rotated(PI/2)
		var winding = sin(progress * PI * winding_frequency * 2) * winding_factor
		var winding_offset = perpendicular * (winding * main_distance * 0.3)
		
		var midpoint = direct_point + winding_offset
		
		# Wenn wir im Loop-Bereich sind und ein Loop erstellt werden soll
		if make_loop and i >= loop_start_index and i < loop_start_index + 4:
			var loop_angle = PI/2 * (i - loop_start_index) + PI/4
			midpoint = loop_center + Vector2(
				cos(loop_angle) * loop_radius,
				sin(loop_angle) * loop_radius
			)
		
		path.append(midpoint)
	
	# Ziel hinzufügen
	path.append(destination)
	
	# Glättung des Pfads für natürlicheres Aussehen
	path = smooth_path(path)
	
	return path

# Funktion zur Glättung des Pfads
func smooth_path(original_path):
	if original_path.size() <= 3:
		return original_path  # Zu wenige Punkte zum Glätten
	
	var smoothed_path = []
	smoothed_path.append(original_path[0])  # Startpunkt bleibt gleich
	
	# Jeden Punkt (außer Start und Ende) durch den Durchschnitt mit seinen Nachbarn ersetzen
	for i in range(1, original_path.size() - 1):
		var prev = original_path[i - 1]
		var curr = original_path[i]
		var next = original_path[i + 1]
		
		# Gewichtete Glättung (60% aktueller Punkt, je 20% Nachbarpunkte)
		var smoothed = curr * 0.6 + prev * 0.2 + next * 0.2
		smoothed_path.append(smoothed)
	
	smoothed_path.append(original_path[-1])  # Endpunkt bleibt gleich
	return smoothed_path

func draw_path(path):
	if path.size() < 2:
		return
	
	# Draw the path as a line with border for better visibility
	for i in range(path.size() - 1):
		var start = path[i]
		var end = path[i + 1]
		
		# Breite dunkle Umrandung für mehr Kontrast
		draw_line(start, end, Color(0.2, 0.2, 0.2, 0.9), path_width + 16)
		
		# Draw the main path
		draw_line(start, end, path_color, path_width)
		
		# Draw arrows along the path
		var distance = start.distance_to(end)
		var direction = (end - start).normalized()
		var perpendicular = direction.rotated(PI/2)
		
		# Mehr und größere Pfeile
		var arrow_spacing = 120  # Pfeile näher aneinander
		var num_arrows = int(distance / arrow_spacing)
		
		for j in range(num_arrows):
			var arrow_pos = start + direction * (j + 0.5) * arrow_spacing
			var arrow_size = path_width * 0.9  # Größere Pfeile
			
			# Pfeilpunkte
			var arrow_points = [
				arrow_pos + direction * arrow_size,  # Spitze
				arrow_pos - direction * arrow_size * 0.6 + perpendicular * arrow_size * 0.9,  # Linker Flügel
				arrow_pos - direction * arrow_size * 0.6 - perpendicular * arrow_size * 0.9   # Rechter Flügel
			]
			
			# Gefülltes Dreieck für den Pfeil mit optimierter Farbe
			draw_colored_polygon(arrow_points, path_arrow_color)
		
		# Zeichne einen Kreis an jedem Pfadpunkt, etwas größer
		if i < path.size() - 1:
			draw_circle(start, path_width * 0.6, path_color.lightened(0.3))
	
	# Deutliche Markierung für den Spawnpunkt (rot)
	draw_circle(path[0], path_width * 1.2, Color(1, 0, 0, 0.8))
	
	# Deutliche Markierung für das Ende/Ziel (blau)
	draw_circle(path[path.size() - 1], path_width * 1.2, Color(0, 0.4, 1, 0.8))

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
