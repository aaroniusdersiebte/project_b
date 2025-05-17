extends CanvasLayer

# Konfiguration
@export var minimap_size = Vector2(200, 200)  # Größe der Minimap
@export var minimap_position = Vector2(10, 10)  # Position (links oben)
@export var border_color = Color(0.2, 0.2, 0.2, 0.8)  # Rahmenfarbe
@export var background_color = Color(0.1, 0.1, 0.1, 0.7)  # Hintergrundfarbe
@export var path_color = Color(0.5, 0.5, 0.5, 0.9)  # Farbe der Wege
@export var player_color = Color(0.0, 0.7, 1.0, 1.0)  # Spielerfarbe (blau)
@export var enemy_color = Color(1.0, 0.3, 0.3, 1.0)  # Gegnerfarbe (rot)
@export var home_color = Color(0.0, 0.7, 0.0, 1.0)  # Heimatfarbe (grün)
@export var tower_color = Color(0.7, 0.0, 0.7, 1.0)  # Turmfarbe (lila)
@export var path_thickness = 2.0  # Dicke der Wege
@export var dot_size = 4.0  # Größe der Punkte

# Referenzen
var player = null
var path_system = null
var world_rect = Rect2(Vector2(-2000, -2000), Vector2(4000, 4000))  # Standardwerte

# Drawing Canvas
var minimap_canvas = null

func _ready():
	# Gruppe hinzufügen
	add_to_group("minimap")
	
	# Auf Initialisierung warten
	await get_tree().process_frame
	
	# Referenzen suchen
	player = get_tree().get_first_node_in_group("player")
	path_system = get_tree().get_first_node_in_group("path_system")
	
	# Weltgröße ermitteln
	var world_generator = get_tree().get_first_node_in_group("world_generator")
	if world_generator:
		if "world_width" in world_generator and "world_height" in world_generator:
			var width = world_generator.world_width
			var height = world_generator.world_height
			world_rect = Rect2(Vector2(-width/2, -height/2), Vector2(width, height))
	
	# Minimap erstellen
	create_minimap()
	
	print("Minimap initialisiert")

func create_minimap():
	# Panel erstellen
	var panel = Panel.new()
	panel.name = "MinimapPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = minimap_position
	panel.custom_minimum_size = minimap_size
	panel.size = minimap_size
	
	# Eigenes Zeichencontrol
	minimap_canvas = Control.new()
	minimap_canvas.name = "MinimapCanvas"
	minimap_canvas.position = Vector2(0, 0)
	minimap_canvas.size = minimap_size
	minimap_canvas.set_script(create_canvas_script())
	panel.add_child(minimap_canvas)
	
	add_child(panel)

func create_canvas_script():
	# Skript für das Canvas erstellen
	var script = GDScript.new()
	script.source_code = """
extends Control

func _draw():
	# Zugriff auf die Minimap durch übergeordneten Knoten
	var minimap = get_parent().get_parent()
	if not minimap:
		return
		
	# Hintergrund
	draw_rect(Rect2(Vector2(0, 0), size), minimap.background_color, true)
	
	# Rahmen
	draw_rect(Rect2(Vector2(0, 0), size), minimap.border_color, false, 2.0)
	
	# Koordinatenumrechnung
	var scale_factor = min(size.x / minimap.world_rect.size.x, 
						  size.y / minimap.world_rect.size.y)
	
	# Wege zeichnen, wenn verfügbar
	if minimap.path_system and "paths" in minimap.path_system:
		for path in minimap.path_system.paths:
			if path.size() < 2:
				continue
				
			for i in range(path.size() - 1):
				var start_point = world_to_minimap(path[i], scale_factor, minimap)
				var end_point = world_to_minimap(path[i+1], scale_factor, minimap)
				draw_line(start_point, end_point, minimap.path_color, minimap.path_thickness)
				
				# An jedem Punkt einen kleinen Kreis zeichnen
				if i < path.size() - 1:
					draw_circle(start_point, minimap.dot_size / 2, minimap.path_color)
			
			# Spawn-Punkt (Beginn des Pfades) markieren
			if path.size() > 0:
				var spawn_point = world_to_minimap(path[0], scale_factor, minimap)
				draw_circle(spawn_point, minimap.dot_size, minimap.enemy_color)
	
	# Heim zeichnen
	var home = minimap.get_tree().get_first_node_in_group("home")
	if home:
		var home_pos = world_to_minimap(home.global_position, scale_factor, minimap)
		draw_circle(home_pos, minimap.dot_size * 1.5, minimap.home_color)
	
	# Spieler zeichnen
	if minimap.player:
		var player_pos = world_to_minimap(minimap.player.global_position, scale_factor, minimap)
		draw_circle(player_pos, minimap.dot_size, minimap.player_color)
	
	# Alle Feinde zeichnen
	for enemy in minimap.get_tree().get_nodes_in_group("enemies"):
		var enemy_pos = world_to_minimap(enemy.global_position, scale_factor, minimap)
		draw_circle(enemy_pos, minimap.dot_size * 0.8, minimap.enemy_color)
	
	# Alle Türme zeichnen
	for tower in minimap.get_tree().get_nodes_in_group("towers"):
		var tower_pos = world_to_minimap(tower.global_position, scale_factor, minimap)
		draw_circle(tower_pos, minimap.dot_size * 0.8, minimap.tower_color)

# Weltkoordinaten in Minimap-Koordinaten umrechnen
func world_to_minimap(world_pos, scale_factor, minimap):
	var centered_pos = world_pos - minimap.world_rect.position - minimap.world_rect.size / 2
	var scaled_pos = centered_pos * scale_factor
	return size / 2 + scaled_pos
"""
	
	return script

func _process(delta):
	# Minimap regelmäßig aktualisieren
	if minimap_canvas:
		minimap_canvas.queue_redraw()
