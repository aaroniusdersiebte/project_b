extends CanvasLayer

# Referenzen zu den Richtungsindikatoren
var spawn_indicators = []
var spawn_references = []
var active_spawns = []  # Speichert, welche Spawner aktiv sind
var camera = null

# Voreingestellte Farben für Indikatoren
@export var indicator_color = Color(1, 0, 0, 0.9)  # Fast volles Rot
@export var active_indicator_color = Color(1, 0.3, 0, 1.0)  # Helles Orange wenn aktiv
@export var indicator_size = 40  # Größer für bessere Sichtbarkeit
@export var indicator_distance = 60  # Abstand vom Bildschirmrand
@export var screen_margin = 100  # Mindestabstand zum Bildschirmrand

func _ready():
	# Warten auf Initialisierung
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Kamera finden
	camera = get_tree().get_first_node_in_group("camera")
	if not camera:
		print("FEHLER: Keine Kamera in Gruppe 'camera' gefunden!")
	
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
			active_spawns.append(false)
	else:
		print("FEHLER: Kein path_system gefunden für Spawn-Indikatoren!")
	
	# Verbinde mit dem WaveSpawner, um aktive Spawns zu erkennen
	var wave_spawner = get_tree().get_first_node_in_group("wave_spawner")
	if wave_spawner:
		if wave_spawner.has_signal("enemy_spawned_at"):
			wave_spawner.connect("enemy_spawned_at", _on_enemy_spawned)
		else:
			print("WARNUNG: wave_spawner hat kein Signal 'enemy_spawned_at'")

func _process(_delta):
	update_indicators()
	
	# Aktiv-Status nach einiger Zeit zurücksetzen
	for i in range(active_spawns.size()):
		if active_spawns[i]:
			active_spawns[i] = false  # Zurücksetzen (oder alternativ mit Timer)

# Wird aufgerufen, wenn ein Gegner an einem bestimmten Spawner erscheint
func _on_enemy_spawned(spawn_index):
	if spawn_index >= 0 and spawn_index < active_spawns.size():
		active_spawns[spawn_index] = true

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
			
			# Hier ist die Korrektur: Statt direkter Zuweisung ein Script-Property setzen
			if indicator.get_script():
				# Aktive Spawner hervorheben - auf die Script-Variablen zugreifen
				if active_spawns[i]:
					indicator.set("indicator_color", active_indicator_color)
					indicator.set("indicator_size", indicator_size * 1.3)
				else:
					indicator.set("indicator_color", indicator_color)
					indicator.set("indicator_size", indicator_size)
				indicator.queue_redraw()

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

var indicator_color = Color(1, 0, 0, 0.9)
var indicator_size = 40

func _draw():
	# Dreieck zeichnen
	var points = [
		Vector2(0, -indicator_size/2),  # Spitze
		Vector2(-indicator_size/3, indicator_size/2),  # Linke Ecke
		Vector2(indicator_size/3, indicator_size/2)    # Rechte Ecke
	]
	draw_colored_polygon(points, indicator_color)
	
	# Kreis zeichnen für bessere Sichtbarkeit
	draw_circle(Vector2(0, 0), indicator_size/4, indicator_color)
	
	# Ausrufezeichen für noch mehr Aufmerksamkeit
	draw_line(Vector2(0, -indicator_size/4), Vector2(0, indicator_size/6), Color(1,1,1,1), 3)
	draw_circle(Vector2(0, indicator_size/3), 3, Color(1,1,1,1))
"""
	return script
