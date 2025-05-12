extends Node2D

# Vorgeladene Gegner-Szene
var enemy_scene = preload("res://scenes/enemy.tscn")

# Spawn-Parameter
@export var spawn_radius = 800.0  # Abstand vom Spieler für das Spawnen
@export var min_spawn_time = 1.0  # Minimale Zeit zwischen Spawns
@export var max_spawn_time = 3.0  # Maximale Zeit zwischen Spawns
@export var max_enemies = 20      # Maximale Anzahl von Gegnern gleichzeitig

# Spielerreferenz
var player = null
# Spawn-Timer
var spawn_timer = 0.0
# Zeit bis zum nächsten Spawn
var time_to_next_spawn = 0.0

func _ready():
	# Spielerreferenz finden
	player = get_tree().get_first_node_in_group("player")
	
	# Erste Spawn-Zeit festlegen
	time_to_next_spawn = randf_range(min_spawn_time, max_spawn_time)

func _process(delta):
	if player == null:
		return
	
	# Timer aktualisieren
	spawn_timer += delta
	
	# Prüfen, ob es Zeit ist, einen neuen Gegner zu spawnen
	if spawn_timer >= time_to_next_spawn:
		spawn_timer = 0.0
		time_to_next_spawn = randf_range(min_spawn_time, max_spawn_time)
		
		# Anzahl aktueller Gegner überprüfen
		var current_enemies = get_tree().get_nodes_in_group("enemies").size()
		
		if current_enemies < max_enemies:
			spawn_enemy()

func spawn_enemy():
	# Zufälligen Winkel für Spawn-Position wählen
	var spawn_angle = randf() * 2.0 * PI
	
	# Position am Rand des Spawn-Radius berechnen
	var spawn_position = player.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_radius
	
	# Neuen Gegner instanziieren
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position
	
	# Gegner zur Szene hinzufügen
	get_parent().add_child(enemy)
