extends CanvasLayer

# Referenzen zu den Richtungsindikatoren
var spawn_indicators = []
var spawn_references = []
var camera = null

# Voreingestellte Farben für Indikatoren
@export var indicator_color = Color(1, 0, 0, 0.8)
@export var indicator_size = 30
@export var indicator_distance = 40  # Abstand vom Bildschirmrand
@export var screen_margin = 80  # Mindestabstand zum Bildschirmrand

func _ready():
	# Wir warten einen Frame, um sicherzustellen, dass alle anderen Nodes bereit sind
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Kamera finden
	camera = get_tree().get_first_node_in_group("camera")
	
	# Erstelle Indikatoren für alle Spawn-Punkte
	var path_system = get_tree().get_first_node_in_group("path_system")
	if path_system:
		for i in range(path_system.spawn_points.size()):
			var spawn_point = path_system.spawn_points[i]
			
			# Erstelle einen Indikator (Pfeil)
			var indicator = create_direction_indicator()
			add_child(indicator)
			indicator.visible = false
			
			# Speichere Referenzen
			spawn_indicators.append(indicator)
			spawn_references.append(spawn_point)
	else:
		print("FEHLER: Kein path_system gefunden für Spawn-Indikatoren!")

func _process(_delta):
	update_indicators()

func update_indicators():
	if not camera:
		return
		
	var screen_size = get_viewport().get_visible_rect().size
	var half_width = screen_size.x / 2
	var half_height = screen_size.y / 2
	
	# Aktualisiere jeden Indikator
	for i in range(spawn_indicators.size()):
		if i >= spawn_references.size():
			continue
			
		var spawn_point = spawn_references[i]
		var indicator = spawn_indicators[i]
		
		# Berechne Position des Spawns relativ zur Kamera
		var spawn_pos_viewport = camera.global_transform.affine_inverse() * spawn_point
		var spawn_pos_screen = spawn_pos_viewport + Vector2(half_width, half_height)
		
		# Prüfe, ob Spawn im sichtbaren Bereich ist
		var is_visible = (
			spawn_pos_screen.x >= screen_margin and 
			spawn_pos_screen.x <= screen_size.x - screen_margin and
			spawn_pos_screen.y >= screen_margin and 
			spawn_pos_screen.y <= screen_size.y - screen_margin
		)
		
		indicator.visible = not is_visible
		
		if not is_visible:
			# Berechne die Position des Indikators am Bildschirmrand
			var angle = (camera.global_position - spawn_point).angle()
			var indicator_pos = Vector2(
				clamp(spawn_pos_screen.x, indicator_distance, screen_size.x - indicator_distance),
				clamp(spawn_pos_screen.y, indicator_distance, screen_size.y - indicator_distance)
			)
			
			# Stelle sicher, dass der Indikator am Rand ist
			if spawn_pos_screen.x < indicator_distance or spawn_pos_screen.x > screen_size.x - indicator_distance:
				indicator_pos.y = spawn_pos_screen.y
			if spawn_pos_screen.y < indicator_distance or spawn_pos_screen.y > screen_size.y - indicator_distance:
				indicator_pos.x = spawn_pos_screen.x
			
			# Setze Position und Rotation des Indikators
			indicator.position = indicator_pos
			indicator.rotation = angle - PI  # Zeige in Richtung des Spawns

func create_direction_indicator():
	var indicator = Node2D.new()
	indicator.z_index = 100  # Stelle sicher, dass der Indikator über allem anderen liegt
	
	# Zeichnen-Funktion für den Indikator
	indicator.set_script(create_indicator_draw_script())
	
	return indicator

func create_indicator_draw_script():
	# Erstelle ein Script für das Zeichnen des Indikators
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var indicator_color = Color(1, 0, 0, 0.8)
var indicator_size = 30

func _draw():
	# Dreieck zeichnen
	var points = [
		Vector2(0, -indicator_size/2),  # Spitze
		Vector2(-indicator_size/3, indicator_size/2),  # Linke Ecke
		Vector2(indicator_size/3, indicator_size/2)    # Rechte Ecke
	]
	draw_colored_polygon(points, indicator_color)
	
	# Kleiner Kreis als zusätzlicher Hinweis
	draw_circle(Vector2(0, 0), indicator_size/5, indicator_color)
"""
	return script
